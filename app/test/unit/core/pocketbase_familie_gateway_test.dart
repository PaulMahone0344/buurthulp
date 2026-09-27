import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/familie_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/familie/model/hh_koppeling.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

class _NepServer {
  final List<({String methode, String pad, String query, String body})>
  verzoeken = [];
  final Map<String, http.Response> antwoorden = {};

  void zet(String methode, String pad, int status, Object body) {
    antwoorden['$methode $pad'] = http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  PocketBaseFamilieGateway gateway() {
    final client = PocketBase(
      'https://nep.test',
      httpClientFactory: () => MockClient((verzoek) async {
        verzoeken.add((
          methode: verzoek.method,
          pad: verzoek.url.path,
          query: Uri.decodeQueryComponent(verzoek.url.query),
          body: verzoek.body,
        ));
        return antwoorden['${verzoek.method} ${verzoek.url.path}'] ??
            http.Response('{"status":404,"message":"x","data":{}}', 404);
      }),
    );
    return PocketBaseFamilieGateway(PocketBaseClientGateway(client: client));
  }
}

const _vast =
    'Als dit adres bij ons bekend is, krijgt uw familielid een vraag om toestemming.';
const _koppelingen = '/api/collections/hh_koppelingen/records';

void main() {
  group('aanvragen', () {
    test('stuurt alleen het adres en geeft het vaste bericht door', () async {
      final server = _NepServer()
        ..zet('POST', aanvraagRoute, 200, {'melding': _vast});
      final uit = await server.gateway().aanvragen('  oma@voorbeeld.nl ');
      expect((uit as AanvraagVerstuurd).melding, _vast);
      expect(jsonDecode(server.verzoeken.single.body), {
        'email_oudere': 'oma@voorbeeld.nl',
      });
    });

    test('429 wordt "limiet", 400 wordt "email"', () async {
      final server = _NepServer()
        ..zet('POST', aanvraagRoute, 429, {
          'melding': 'Morgen weer.',
          'reden': 'limiet',
        });
      final uit = await server.gateway().aanvragen('oma@voorbeeld.nl');
      expect(
        uit,
        isA<AanvraagGeweigerd>()
            .having((g) => g.reden, 'reden', AanvraagReden.limiet)
            .having((g) => g.melding, 'melding', 'Morgen weer.'),
      );
      final server2 = _NepServer()
        ..zet('POST', aanvraagRoute, 400, {'reden': 'email'});
      expect(
        (await server2.gateway().aanvragen('x') as AanvraagGeweigerd).reden,
        AanvraagReden.email,
      );
    });
  });

  group('koppelingen', () {
    test('van het familielid: filter met parameter, expand oudere', () async {
      final server = _NepServer()
        ..zet('GET', _koppelingen, 200, {
          'page': 1,
          'perPage': 500,
          'totalItems': 1,
          'totalPages': 1,
          'items': [
            {
              'id': 'k1',
              'collectionName': 'hh_koppelingen',
              'oudere': 'o1',
              'familielid': 'f1',
              'status': 'actief',
              'rechten': ['meekijken', 'plaatsen'],
              'expand': {
                'oudere': {
                  'id': 'o1',
                  'collectionName': 'hh_users',
                  'naam': 'Mevrouw A. de Vries',
                },
              },
            },
          ],
        });
      final r = await server.gateway().vanFamilielid('f1');
      final k = (r as Ok<List<HhKoppeling>>).waarde.single;
      expect(k.isActief, isTrue);
      expect(k.rechten, {FamilieRecht.meekijken, FamilieRecht.plaatsen});
      expect(k.oudereNaam, 'Mevrouw A. de Vries');
      final query = server.verzoeken.single.query;
      expect(query, contains('familielid = "f1"'));
      expect(query, contains('expand=oudere'));
    });

    test('toestemming geven: status actief met beide rechten', () async {
      final server = _NepServer()
        ..zet('PATCH', '$_koppelingen/k1', 200, {
          'id': 'k1',
          'collectionName': 'hh_koppelingen',
          'oudere': 'o1',
          'familielid': 'f1',
          'status': 'actief',
          'rechten': ['meekijken', 'plaatsen'],
        });
      final r = await server.gateway().geefToestemming('k1');
      expect((r as Ok<HhKoppeling>).waarde.isActief, isTrue);
      expect(jsonDecode(server.verzoeken.single.body), {
        'status': 'actief',
        'rechten': ['meekijken', 'plaatsen'],
      });
    });

    test('Nee en ontkoppelen: delete', () async {
      final server = _NepServer()
        ..antwoorden['DELETE $_koppelingen/k1'] = http.Response('', 204);
      final r = await server.gateway().verwijder('k1');
      expect(r, isA<Ok<void>>());
      expect(server.verzoeken.single.methode, 'DELETE');
    });
  });
}

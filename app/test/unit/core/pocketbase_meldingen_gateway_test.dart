import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/incident_gateway.dart';
import 'package:heitjehulp_app/core/pb/meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/pb/push_registratie.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Nep-server zoals in de andere gateway-tests: antwoord per (methode, pad).
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

  PocketBaseGateway gateway() {
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
    return PocketBaseClientGateway(client: client);
  }
}

const _meldingen = '/api/collections/hh_meldingen/records';
const _incidenten = '/api/collections/hh_incidenten/records';
const _tokens = '/api/collections/hh_push_tokens/records';

Map<String, dynamic> _melding({String gelezen = ''}) => {
  'id': 'm1',
  'collectionName': 'hh_meldingen',
  'ontvanger': 'u1',
  'soort': 'onderweg',
  'klus': 'k1',
  'incident': '',
  'titel': 'Onderweg naar u',
  'tekst': 'Sanne is onderweg naar u.',
  'created': '2026-09-15 08:00:00.000Z',
  'gelezen_op': gelezen,
};

Map<String, dynamic> _pagina(List<Map<String, dynamic>> items) => {
  'page': 1,
  'perPage': 50,
  'totalItems': -1,
  'totalPages': -1,
  'items': items,
};

void main() {
  group('meldingen', () {
    test(
      'alleen van de ontvanger, nieuwste eerst, met een parameter',
      () async {
        final server = _NepServer()
          ..zet('GET', _meldingen, 200, _pagina([_melding()]));
        final r = await PocketBaseMeldingenGateway(
          server.gateway(),
        ).meldingen('u1');
        final m = (r as Ok<List<HhMelding>>).waarde.single;
        expect(m.soort, HhMeldingSoort.onderweg);
        expect(m.isGelezen, isFalse);
        expect(m.gemaakt, DateTime.utc(2026, 9, 15, 8));
        final query = server.verzoeken.single.query;
        expect(query, contains('ontvanger = "u1"'));
        expect(query, contains('sort=-created'));
      },
    );

    test('gelezen zetten stuurt ALLEEN gelezen_op', () async {
      final server = _NepServer()
        ..zet(
          'PATCH',
          '$_meldingen/m1',
          200,
          _melding(gelezen: '2026-09-15 09:00:00.000Z'),
        );
      final r = await PocketBaseMeldingenGateway(
        server.gateway(),
      ).markeerGelezen('m1', DateTime.utc(2026, 9, 15, 9));
      expect((r as Ok<HhMelding>).waarde.isGelezen, isTrue);
      final body = jsonDecode(server.verzoeken.single.body) as Map;
      expect(body.keys, ['gelezen_op']);
      expect(body['gelezen_op'], startsWith('2026-09-15T09:00'));
    });
  });

  group('incident', () {
    test('nood zonder klus: geen leeg klus-veld in de body', () async {
      final server = _NepServer()
        ..zet('POST', _incidenten, 200, {
          'id': 'i1',
          'collectionName': 'hh_incidenten',
        });
      final r = await PocketBaseIncidentGateway(
        server.gateway(),
      ).meld(melderId: 'o1', soort: IncidentSoort.nood);
      expect((r as Ok<String>).waarde, 'i1');
      final body = jsonDecode(server.verzoeken.single.body) as Map;
      expect(body, {'melder': 'o1', 'soort': 'nood'});
    });

    test('probleem met klus en omschrijving', () async {
      final server = _NepServer()
        ..zet('POST', _incidenten, 200, {
          'id': 'i2',
          'collectionName': 'hh_incidenten',
        });
      await PocketBaseIncidentGateway(server.gateway()).meld(
        melderId: 'o1',
        soort: IncidentSoort.probleem,
        klusId: 'k1',
        omschrijving: ' Er kwam niemand ',
      );
      final body = jsonDecode(server.verzoeken.single.body) as Map;
      expect(body, {
        'melder': 'o1',
        'soort': 'probleem',
        'klus': 'k1',
        'omschrijving': 'Er kwam niemand',
      });
    });

    test('een weigering blijft een nette fout', () async {
      final r = await PocketBaseIncidentGateway(
        _NepServer().gateway(),
      ).meld(melderId: 'o1', soort: IncidentSoort.nood);
      expect(r, isA<Err<String>>());
    });
  });

  group('push-voorbereiding (laag 2 niet gebouwd)', () {
    test('de lege registratie doet niets en gooit niets', () async {
      const leeg = LegePushRegistratie();
      await leeg.registreerToken('u1');
      await leeg.verwijderToken();
    });

    test('bewaren: nieuw token -> aanmaken', () async {
      final server = _NepServer()
        ..zet('GET', _tokens, 200, _pagina([]))
        ..zet('POST', _tokens, 200, {
          'id': 't1',
          'collectionName': 'hh_push_tokens',
        });
      final r = await PocketBasePushTokenOpslag(
        server.gateway(),
      ).bewaar(gebruikerId: 'u1', token: 'abc', platform: PushPlatform.ios);
      expect(r, isA<Ok<void>>());
      expect(server.verzoeken.map((v) => v.methode), ['GET', 'POST']);
      expect(jsonDecode(server.verzoeken.last.body), {
        'gebruiker': 'u1',
        'token': 'abc',
        'platform': 'ios',
      });
    });

    test('bewaren: bestaand token -> bijwerken, niet dubbel', () async {
      final server = _NepServer()
        ..zet(
          'GET',
          _tokens,
          200,
          _pagina([
            {'id': 't1', 'collectionName': 'hh_push_tokens', 'token': 'abc'},
          ]),
        )
        ..zet('PATCH', '$_tokens/t1', 200, {
          'id': 't1',
          'collectionName': 'hh_push_tokens',
        });
      await PocketBasePushTokenOpslag(
        server.gateway(),
      ).bewaar(gebruikerId: 'u1', token: 'abc', platform: PushPlatform.android);
      expect(server.verzoeken.map((v) => v.methode), ['GET', 'PATCH']);
    });
  });
}

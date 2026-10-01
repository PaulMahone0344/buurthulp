import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/model/hh_beoordeling.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Een nep-server zoals in pocketbase_klussen_gateway_test: antwoord per
/// (methode, pad), alles anders 404.
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

  PocketBaseBeoordelingGateway gateway() {
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
    return PocketBaseBeoordelingGateway(
      PocketBaseClientGateway(client: client),
    );
  }
}

const _pad = '/api/collections/hh_beoordelingen/records';

Map<String, dynamic> _record({
  String id = 'b1',
  int sterren = 4,
  String tekst = 'Fijn geholpen.',
}) => {
  'id': id,
  'collectionName': 'hh_beoordelingen',
  'klus': 'klus1',
  'van_gebruiker': 'oudere1',
  'naar_gebruiker': 'jongere1',
  'sterren': sterren,
  'tekst': tekst,
  'created': '2026-09-15 08:00:00.000Z',
};

void main() {
  group('geef', () {
    test(
      'stuurt klus, van, naar, sterren en tekst; leest het record',
      () async {
        final server = _NepServer()..zet('POST', _pad, 200, _record());
        final uitkomst = await server.gateway().geef(
          klusId: 'klus1',
          vanId: 'oudere1',
          naarId: 'jongere1',
          sterren: 4,
          tekst: '  Fijn geholpen.  ',
        );
        final b = (uitkomst as BeoordelingOpgeslagen).beoordeling;
        expect(b.id, 'b1');
        expect(b.sterren, 4);
        expect(b.gemaakt, DateTime.utc(2026, 9, 15, 8));
        final body = jsonDecode(server.verzoeken.single.body) as Map;
        expect(body, {
          'klus': 'klus1',
          'van_gebruiker': 'oudere1',
          'naar_gebruiker': 'jongere1',
          'sterren': 4,
          'tekst': 'Fijn geholpen.',
        });
      },
    );

    test('de unieke index (klus + van) wordt "al gegeven"', () async {
      final server = _NepServer()
        ..zet('POST', _pad, 400, {
          'status': 400,
          'message': 'Failed to create record.',
          'data': {
            'klus': {
              'code': 'validation_not_unique',
              'message': 'Value must be unique.',
            },
            'van_gebruiker': {
              'code': 'validation_not_unique',
              'message': 'Value must be unique.',
            },
          },
        });
      final uitkomst = await server.gateway().geef(
        klusId: 'klus1',
        vanId: 'oudere1',
        naarId: 'jongere1',
        sterren: 4,
      );
      expect(
        uitkomst,
        isA<BeoordelingGeweigerd>().having(
          (g) => g.reden,
          'reden',
          BeoordelingReden.alGegeven,
        ),
      );
    });

    test('een createRule die weigert (400 zonder velden) mag niet', () async {
      final server = _NepServer()
        ..zet('POST', _pad, 400, {
          'status': 400,
          'message': 'Failed to create record.',
          'data': {},
        });
      final uitkomst = await server.gateway().geef(
        klusId: 'klus1',
        vanId: 'oudere1',
        naarId: 'jongere1',
        sterren: 4,
      );
      expect(
        uitkomst,
        isA<BeoordelingGeweigerd>().having(
          (g) => g.reden,
          'reden',
          BeoordelingReden.nietToegestaan,
        ),
      );
    });

    test('geen verbinding blijft een HhFout', () async {
      final client = PocketBase(
        'https://nep.test',
        httpClientFactory: () =>
            MockClient((_) async => throw http.ClientException('weg')),
      );
      final gateway = PocketBaseBeoordelingGateway(
        PocketBaseClientGateway(client: client),
      );
      final uitkomst = await gateway.geef(
        klusId: 'klus1',
        vanId: 'oudere1',
        naarId: 'jongere1',
        sterren: 4,
      );
      expect(
        (uitkomst as BeoordelingFout).fout.soort,
        HhFoutSoort.geenVerbinding,
      );
    });
  });

  group('wijzig', () {
    test('stuurt alleen sterren en tekst, nooit klus/van/naar', () async {
      final server = _NepServer()
        ..zet('PATCH', '$_pad/b1', 200, _record(sterren: 2, tekst: ''));
      final uitkomst = await server.gateway().wijzig(
        'b1',
        sterren: 2,
        tekst: '',
      );
      expect((uitkomst as BeoordelingOpgeslagen).beoordeling.sterren, 2);
      final body = jsonDecode(server.verzoeken.single.body) as Map;
      expect(body.keys.toSet(), {'sterren', 'tekst'});
    });

    test('een beoordeling van een ander (404) is niet gevonden', () async {
      final uitkomst = await _NepServer().gateway().wijzig(
        'b9',
        sterren: 2,
        tekst: '',
      );
      expect(
        uitkomst,
        isA<BeoordelingGeweigerd>().having(
          (g) => g.reden,
          'reden',
          BeoordelingReden.nietGevonden,
        ),
      );
    });
  });

  group('lezen', () {
    test('reputatie komt van hh_users, berekend door de server', () async {
      final server = _NepServer()
        ..zet('GET', '/api/collections/hh_users/records/jongere1', 200, {
          'id': 'jongere1',
          'collectionName': 'hh_users',
          'sterren_gemiddeld': 4.3,
          'klussen_aantal': 12,
        });
      final r = await server.gateway().reputatie('jongere1');
      final rep = (r as Ok<HhReputatie>).waarde;
      expect(rep.sterrenGemiddeld, 4.3);
      expect(rep.klussenAantal, 12);
      expect(server.verzoeken.single.query, contains('sterren_gemiddeld'));
    });

    test('ontvangen: naar mij, met tekst, laatste eerst, gefilterd met een '
        'parameter', () async {
      final server = _NepServer()
        ..zet('GET', _pad, 200, {
          'page': 1,
          'perPage': 5,
          'totalItems': 1,
          'totalPages': 1,
          'items': [_record()],
        });
      final r = await server.gateway().ontvangen('jongere1');
      expect(
        (r as Ok<List<HhBeoordeling>>).waarde.single.tekst,
        'Fijn geholpen.',
      );
      final query = server.verzoeken.single.query;
      expect(query, contains('naar_gebruiker = "jongere1"'));
      expect(query, contains('tekst != '));
      expect(query, contains('sort=-created'));
    });
  });
}

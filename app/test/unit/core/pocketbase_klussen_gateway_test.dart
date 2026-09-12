import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Een nep-server zoals in pocketbase_auth_gateway_test: antwoord per
/// (methode, pad), alles anders 404.
class _NepServer {
  final List<({String methode, String pad, String query})> verzoeken = [];
  final Map<String, http.Response> antwoorden = {};

  void zet(String methode, String pad, int status, Object body) {
    antwoorden['$methode $pad'] = http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  PocketBaseKlussenGateway gateway() {
    final client = PocketBase(
      'https://nep.test',
      httpClientFactory: () => MockClient((verzoek) async {
        verzoeken.add((
          methode: verzoek.method,
          pad: verzoek.url.path,
          query: verzoek.url.query,
        ));
        return antwoorden['${verzoek.method} ${verzoek.url.path}'] ??
            http.Response('{"status":404,"message":"x","data":{}}', 404);
      }),
    );
    return PocketBaseKlussenGateway(PocketBaseClientGateway(client: client));
  }
}

Map<String, dynamic> _klusRecord({
  bool metOudere = false,
  double lat = 51.8865,
  double lon = 5.4126,
}) => {
  'id': 'klus1',
  'collectionName': 'hh_klussen',
  'hulpvrager': 'oudere1',
  'klustype': 'type1',
  'omschrijving': '[seed k02] Heg knippen',
  'adres': 'Prins Bernhardlaan 12, 4003 AB Tiel',
  'lat': lat,
  'lon': lon,
  'wanneer_van': '2026-09-16 12:00:00.000Z',
  'wanneer_tot': '2026-09-16 13:30:00.000Z',
  'status': 'open',
  'vergoeding_jongere': 1500,
  'toegewezen_jongere': '',
  'expand': {
    'klustype': {
      'id': 'type1',
      'collectionName': 'hh_klustypes',
      'naam': 'tuin',
      'icoon': 'yard',
      'richtduur': 90,
    },
    if (metOudere)
      'hulpvrager': {
        'id': 'oudere1',
        'collectionName': 'hh_users',
        'naam': 'Mevrouw A. de Vries',
        'foto': 'foto_abc.jpg',
        'wijk': 'wijk1',
      },
  },
};

void main() {
  group('HhKlus.vanRecord', () {
    test('leest velden, klustype-expand en de datums (UTC)', () {
      final klus = HhKlus.vanRecord(RecordModel.fromJson(_klusRecord()));
      expect(klus.id, 'klus1');
      expect(klus.status, HhKlusStatus.open);
      expect(klus.klustypeNaam, 'tuin');
      expect(klus.klustypeIcoon, 'yard');
      expect(klus.richtduurMinuten, 90);
      expect(klus.vergoedingJongereCenten, 1500);
      expect(klus.heeftCoordinaten, isTrue);
      expect(klus.wanneerVan, DateTime.utc(2026, 9, 16, 12));
      expect(klus.wanneerTot, DateTime.utc(2026, 9, 16, 13, 30));
      expect(klus.isOpen, isTrue);
      expect(klus.isOudereZichtbaar, isFalse);
      expect(klus.oudereFotoUrl, '');
    });

    test('0/0 op de server betekent geen coördinaten', () {
      final klus = HhKlus.vanRecord(
        RecordModel.fromJson(_klusRecord(lat: 0, lon: 0)),
      );
      expect(klus.heeftCoordinaten, isFalse);
      expect(klus.lat, isNull);
    });

    test('met hulpvrager-expand: naam, wijk en foto-url via de aanroeper', () {
      final klus = HhKlus.vanRecord(
        RecordModel.fromJson(_klusRecord(metOudere: true)),
        fotoUrl: (oudere, bestand) => 'https://nep.test/${oudere.id}/$bestand',
      );
      expect(klus.oudereNaam, 'Mevrouw A. de Vries');
      expect(klus.oudereWijkId, 'wijk1');
      expect(klus.oudereFotoUrl, 'https://nep.test/oudere1/foto_abc.jpg');
      expect(klus.isOudereZichtbaar, isTrue);
    });

    test('onbekende status telt als open', () {
      expect(HhKlus.statusVanCode('iets_nieuws'), HhKlusStatus.open);
      expect(HhKlus.statusVanCode('geaccepteerd'), HhKlusStatus.geaccepteerd);
    });
  });

  group('PocketBaseKlussenGateway', () {
    test('openKlussen vraagt open klussen zonder jongere met expand', () async {
      final server = _NepServer();
      server.zet('GET', '/api/collections/hh_klussen/records', 200, {
        'page': 1,
        'perPage': 500,
        'totalItems': 1,
        'totalPages': 1,
        'items': [_klusRecord()],
      });
      final result = await server.gateway().openKlussen();
      expect(result, isA<Ok<List<HhKlus>>>());
      expect((result as Ok<List<HhKlus>>).waarde.single.klustypeNaam, 'tuin');
      final query = Uri.decodeQueryComponent(server.verzoeken.single.query);
      expect(query, contains('status = "open" && toegewezen_jongere = ""'));
      expect(query, contains('expand=klustype,hulpvrager'));
      expect(query, contains('sort=wanneer_van'));
    });

    test('mijnKlussen filtert op de jongere, laatste eerst', () async {
      final server = _NepServer();
      server.zet('GET', '/api/collections/hh_klussen/records', 200, {
        'page': 1,
        'perPage': 500,
        'totalItems': 0,
        'totalPages': 1,
        'items': <Map<String, dynamic>>[],
      });
      await server.gateway().mijnKlussen('j1');
      final query = Uri.decodeQueryComponent(server.verzoeken.single.query);
      expect(query, contains('toegewezen_jongere = "j1"'));
      expect(query, contains('sort=-wanneer_van'));
    });

    test('klus bouwt de foto-url met miniatuur', () async {
      final server = _NepServer();
      server.zet(
        'GET',
        '/api/collections/hh_klussen/records/klus1',
        200,
        _klusRecord(metOudere: true),
      );
      final result = await server.gateway().klus('klus1');
      final klus = (result as Ok<HhKlus>).waarde;
      expect(
        klus.oudereFotoUrl,
        contains('/api/files/hh_users/oudere1/foto_abc.jpg'),
      );
      expect(klus.oudereFotoUrl, contains('thumb=200x200'));
    });

    group('accepteren', () {
      test('200 -> Geaccepteerd via POST op de hook-route', () async {
        final server = _NepServer();
        server.zet('POST', '/api/hh/klussen/klus1/accepteren', 200, {
          'klus': 'klus1',
          'status': 'geaccepteerd',
        });
        final uitkomst = await server.gateway().accepteren('klus1');
        expect(uitkomst, isA<Geaccepteerd>());
        expect(server.verzoeken.single.methode, 'POST');
        expect(server.verzoeken.single.pad, accepteerRoute('klus1'));
      });

      test('409 -> Geweigerd(bezet) met de melding van de server', () async {
        final server = _NepServer();
        server.zet('POST', '/api/hh/klussen/klus1/accepteren', 409, {
          'melding': 'Deze klus is net door iemand anders aangenomen.',
          'reden': 'bezet',
        });
        final uitkomst = await server.gateway().accepteren('klus1');
        expect(uitkomst, isA<Geweigerd>());
        final geweigerd = uitkomst as Geweigerd;
        expect(geweigerd.reden, AccepteerReden.bezet);
        expect(
          geweigerd.melding,
          'Deze klus is net door iemand anders aangenomen.',
        );
      });

      test(
        '403 -> geenToegang, 404 -> nietGevonden, zonder melding null',
        () async {
          final server = _NepServer();
          server.zet('POST', '/api/hh/klussen/klus1/accepteren', 403, {
            'melding': 'Alleen een jongere kan een klus aannemen.',
          });
          server.zet('POST', '/api/hh/klussen/weg/accepteren', 404, {
            'status': 404,
            'message': 'Not found',
          });
          final g = server.gateway();
          final drie = await g.accepteren('klus1') as Geweigerd;
          expect(drie.reden, AccepteerReden.geenToegang);
          expect(drie.melding, 'Alleen een jongere kan een klus aannemen.');
          final vier = await g.accepteren('weg') as Geweigerd;
          expect(vier.reden, AccepteerReden.nietGevonden);
          expect(vier.melding, isNull);
        },
      );

      test(
        '401 -> AccepteerFout(nietIngelogd), 500 -> AccepteerFout(server)',
        () async {
          final server = _NepServer();
          server.zet('POST', '/api/hh/klussen/a/accepteren', 401, {
            'status': 401,
            'message': 'x',
          });
          server.zet('POST', '/api/hh/klussen/b/accepteren', 500, {
            'status': 500,
            'message': 'x',
          });
          final g = server.gateway();
          expect(
            ((await g.accepteren('a')) as AccepteerFout).fout.soort,
            HhFoutSoort.nietIngelogd,
          );
          expect(
            ((await g.accepteren('b')) as AccepteerFout).fout.soort,
            HhFoutSoort.server,
          );
        },
      );
    });
  });
}

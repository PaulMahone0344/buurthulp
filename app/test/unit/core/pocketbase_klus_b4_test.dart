import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/klus_gateway.dart';
import 'package:heitjehulp_app/core/pb/klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/bedragen.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_klustype.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/nieuwe_klus.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../support/hh_hulpvrager_wikkel.dart';

/// B4: wat de app met de server uitwisselt bij klus plaatsen (categorieën,
/// foto als bestand) en wat de helper/bewoner terugleest (keuring, foto).
class _NepServer {
  final List<http.Request> verzoeken = [];
  final Map<String, http.Response> antwoorden = {};

  void zet(String methode, String pad, Object body) {
    antwoorden['$methode $pad'] = http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  PocketBaseClientGateway client() {
    final pb = PocketBase(
      'https://nep.test',
      httpClientFactory: () => MockClient((verzoek) async {
        verzoeken.add(verzoek);
        return antwoorden['${verzoek.method} ${verzoek.url.path}'] ??
            http.Response('{"status":404,"message":"x","data":{}}', 404);
      }),
    );
    return PocketBaseClientGateway(client: pb);
  }
}

T _ok<T>(Result<T> r) => switch (r) {
  Ok<T>(:final waarde) => waarde,
  Err<T>(:final fout) => throw StateError('$fout'),
};

void main() {
  test(
    'klustypes: alleen actief, op volgorde, met leeftijd en volgorde',
    () async {
      final server = _NepServer()
        ..zet('GET', '/api/collections/hh_klustypes/records', {
          'page': 1,
          'perPage': 500,
          'totalItems': 1,
          'totalPages': 1,
          'items': [
            {
              'id': 'kt1',
              'collectionName': 'hh_klustypes',
              'naam': 'Tuin',
              'icoon': 'yard',
              'min_leeftijd': 13,
              'volgorde': 1,
              'actief': true,
            },
          ],
        });
      final types = _ok(
        await PocketBaseKlusGateway(server.client()).klustypes(),
      );

      final query = server.verzoeken.single.url.queryParameters;
      expect(query['filter'], 'actief = true');
      expect(query['sort'], 'volgorde,naam');
      expect(
        types.single,
        const HhKlustype(
          id: 'kt1',
          naam: 'Tuin',
          icoon: 'yard',
          minLeeftijd: 13,
          volgorde: 1,
        ),
      );
    },
  );

  test('klus aanmaken stuurt de foto als bestand (multipart) mee', () async {
    final server = _NepServer()
      ..zet('POST', '/api/collections/hh_klussen/records', {
        'id': 'nieuw1',
        'collectionName': 'hh_klussen',
      });
    final klus = NieuweKlus(
      hulpvragerId: 'oudere1',
      klustypeId: 'kt1',
      omschrijving: 'Heg knippen',
      adres: 'Kerkstraat 1, 4001 AA Tiel',
      wanneerVan: DateTime(2026, 9, 16, 14),
      bedragen: const HhBedragen(
        bedragBruto: 0,
        vergoedingJongere: 0,
        commissie: 0,
      ),
      foto: testKlusFoto,
    );

    final id = _ok(
      await PocketBaseKlusGateway(server.client()).klusAanmaken(klus),
    );

    expect(id, 'nieuw1');
    final verzoek = server.verzoeken.single;
    expect(verzoek.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(verzoek.bodyBytes);
    expect(body, contains('name="foto"; filename="klus.png"'));
    // De velden gaan als JSON in @jsonPayload (pocketbase-dart).
    expect(body, contains('"nee_lijst_akkoord":true'));
    expect(body, isNot(contains('"wanneer_tot"')));
    expect(body, isNot(contains('klus_goedgekeurd_op')));
  });

  group('HhKlus.vanRecord (B4)', () {
    Map<String, dynamic> record({
      String status = 'open',
      String goedgekeurd = '',
      String afgekeurd = '',
      String reden = '',
      List<String> foto = const [],
    }) => {
      'id': 'k1',
      'collectionId': 'col_klussen',
      'collectionName': 'hh_klussen',
      'hulpvrager': 'o1',
      'status': status,
      'klus_goedgekeurd_op': goedgekeurd,
      'klus_afgekeurd_op': afgekeurd,
      'klus_afkeur_reden': reden,
      'foto': foto,
    };

    test('ADRES: vaag vóór de match leest afstand_m en locatie_vaag', () {
      final vaag = HhKlus.vanRecord(
        RecordModel.fromJson({
          ...record(),
          'lat': 51.889,
          'lon': 5.437,
          'locatie_vaag': true,
          'afstand_m': 9200,
        }),
      );
      expect(vaag.afstandMeter, 9200);
      expect(vaag.isLocatieVaag, isTrue);
      final exact = HhKlus.vanRecord(RecordModel.fromJson(record()));
      expect(exact.afstandMeter, isNull);
      expect(exact.isLocatieVaag, isFalse);
    });

    test('open en ongekeurd: wordt nagekeken', () {
      final klus = HhKlus.vanRecord(RecordModel.fromJson(record()));
      expect(klus.wordtNagekeken, isTrue);
      expect(klus.afkeurReden, isEmpty);
    });

    test('goedgekeurd of al aangenomen: niet meer nagekeken', () {
      expect(
        HhKlus.vanRecord(
          RecordModel.fromJson(record(goedgekeurd: '2026-09-15 10:00:00.000Z')),
        ).wordtNagekeken,
        isFalse,
      );
      expect(
        HhKlus.vanRecord(
          RecordModel.fromJson(record(status: 'geaccepteerd')),
        ).wordtNagekeken,
        isFalse,
      );
    });

    test('B11: wacht_op_kennismaking van de server -> wachtOpBelletje', () {
      final klus = HhKlus.vanRecord(
        RecordModel.fromJson({...record(), 'wacht_op_kennismaking': true}),
      );
      expect(klus.wordtNagekeken, isTrue);
      expect(klus.wachtOpBelletje, isTrue);
      expect(
        HhKlus.vanRecord(RecordModel.fromJson(record())).wachtOpBelletje,
        isFalse,
      );
      // Alleen zolang hij nog nagekeken wordt.
      expect(
        HhKlus.vanRecord(
          RecordModel.fromJson({
            ...record(goedgekeurd: '2026-09-15 10:00:00.000Z'),
            'wacht_op_kennismaking': true,
          }),
        ).wachtOpBelletje,
        isFalse,
      );
    });

    test('afgekeurd: de reden, niet "nagekeken"', () {
      final klus = HhKlus.vanRecord(
        RecordModel.fromJson(
          record(
            status: 'geannuleerd',
            afgekeurd: '2026-09-15 10:00:00.000Z',
            reden: 'Sigaretten kan niet.',
          ),
        ),
      );
      expect(klus.wordtNagekeken, isFalse);
      expect(klus.afkeurReden, 'Sigaretten kan niet.');
    });

    test('de foto komt via de url-maker (met token)', () {
      final klus = HhKlus.vanRecord(
        RecordModel.fromJson(record(foto: ['klus_abc.jpg'])),
        klusFotoUrl: (r, bestand) => 'https://x/$bestand?token=t',
      );
      expect(klus.klusFotoUrl, 'https://x/klus_abc.jpg?token=t');
      expect(
        klus.copyWith(status: HhKlusStatus.geaccepteerd).klusFotoUrl,
        klus.klusFotoUrl,
        reason: 'copyWith houdt de B4-velden vast',
      );
    });
  });

  test('klus ophalen met foto vraagt een bestandstoken', () async {
    final server = _NepServer()
      ..zet('GET', '/api/collections/hh_klussen/records/k1', {
        'id': 'k1',
        'collectionId': 'col_klussen',
        'collectionName': 'hh_klussen',
        'hulpvrager': 'o1',
        'status': 'open',
        'klus_goedgekeurd_op': '2026-09-15 10:00:00.000Z',
        'foto': ['klus_abc.jpg'],
      })
      ..zet('POST', '/api/files/token', {'token': 'bestandstoken'});

    final klus = _ok(
      await PocketBaseKlussenGateway(server.client()).klus('k1'),
    );

    expect(
      server.verzoeken.map((v) => v.url.path),
      contains('/api/files/token'),
    );
    expect(klus.klusFotoUrl, contains('klus_abc.jpg'));
    expect(klus.klusFotoUrl, contains('token=bestandstoken'));
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/pb/reactie_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/reacties/model/hh_reactie.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Een nep-server: antwoord per (methode, pad), alles anders 404.
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

  PocketBaseReactieGateway gateway() {
    final client = PocketBase(
      'https://nep.test',
      httpClientFactory: () => MockClient((verzoek) async {
        verzoeken.add((
          methode: verzoek.method,
          pad: verzoek.url.path,
          query: verzoek.url.query,
          body: verzoek.body,
        ));
        return antwoorden['${verzoek.method} ${verzoek.url.path}'] ??
            http.Response('{"status":404,"message":"x","data":{}}', 404);
      }),
    );
    return PocketBaseReactieGateway(PocketBaseClientGateway(client: client));
  }
}

void main() {
  group('reageren', () {
    test('stuurt berichtje en vinkje mee en leest de stand', () async {
      final server = _NepServer()
        ..zet('POST', '/api/hh/klussen/k1/reageren', 200, {
          'status': 'wacht_op_ouder',
          'melding': 'Eerst kijkt je ouder.',
          'reactie': 'r1',
        });
      final uit = await server.gateway().reageren(
        'k1',
        bericht: '  Ik help graag  ',
        ouderGaatMee: true,
      );
      expect(uit, isA<Gereageerd>());
      expect((uit as Gereageerd).status, HhReactieStatus.wachtOpOuder);
      expect(uit.melding, 'Eerst kijkt je ouder.');
      final body = jsonDecode(server.verzoeken.single.body) as Map;
      expect(body['bericht'], 'Ik help graag');
      expect(body['ouder_gaat_mee'], isTrue);
    });

    test('een weigering van de hook wordt ReageerGeweigerd', () async {
      final server = _NepServer()
        ..zet('POST', '/api/hh/klussen/k1/reageren', 400, {
          'reden': 'oudermee',
          'melding': 'Zet het vinkje.',
        });
      final uit = await server.gateway().reageren('k1');
      expect(uit, isA<ReageerGeweigerd>());
      expect((uit as ReageerGeweigerd).vraagtOuderMee, isTrue);
      expect(uit.melding, 'Zet het vinkje.');
    });

    test('401 zonder eigen melding is een gewone fout (sessie)', () async {
      final server = _NepServer()
        ..zet('POST', '/api/hh/klussen/k1/reageren', 401, {
          'status': 401,
          'message': 'auth',
          'data': {},
        });
      final uit = await server.gateway().reageren('k1');
      expect(uit, isA<ReageerFout>());
      expect((uit as ReageerFout).fout.soort, HhFoutSoort.nietIngelogd);
    });
  });

  test('mijnReacties filtert op de strijder en leest de velden', () async {
    final server = _NepServer()
      ..zet('GET', '/api/collections/hh_reacties/records', 200, {
        'page': 1,
        'perPage': 500,
        'totalItems': 1,
        'totalPages': 1,
        'items': [
          {
            'id': 'r1',
            'collectionName': 'hh_reacties',
            'klus': 'k1',
            'helper': 'h1',
            'status': 'afgewezen',
            'bericht': 'Graag',
            'klus_samenvatting': 'Tuin, zaterdag 10 oktober om 10:00',
            'ouder_besluit': 'liever_niet',
            'ouder_gaat_mee': true,
            'created': '2026-10-04 10:00:00.000Z',
          },
        ],
      });
    final uit = await server.gateway().mijnReacties('h1');
    final lijst = (uit as Ok<List<HhReactie>>).waarde;
    expect(lijst.single.status, HhReactieStatus.afgewezen);
    expect(lijst.single.isDoorOuderAfgewezen, isTrue);
    expect(lijst.single.klusSamenvatting, startsWith('Tuin'));
    expect(lijst.single.ouderGaatMee, isTrue);
    expect(
      Uri.decodeQueryComponent(server.verzoeken.single.query),
      contains('helper = "h1"'),
    );
  });

  test(
    'reacties voor KiesHelper: kaarten zonder achternaam of adres',
    () async {
      final server = _NepServer()
        ..zet('GET', '/api/hh/klussen/k1/reacties', 200, {
          'klus': 'k1',
          'reacties': [
            {
              'reactie': 'r1',
              'helper': 'h1',
              'voornaam': 'Daan',
              'leeftijd': 14,
              'niveau': 'Nieuw',
              'sterren': 4.8,
              'beoordelingen': 12,
              'id_gecontroleerd': true,
              'laatste_recensie': 'Heel netjes.',
              'bericht': 'Ik heb tijd.',
              'ouder_gaat_mee': false,
            },
          ],
        });
      final uit = await server.gateway().reactiesVoorKlus('k1');
      final k = (uit as Ok<List<HhReactieKaart>>).waarde.single;
      expect(k.voornaam, 'Daan');
      expect(k.leeftijd, 14);
      expect(k.sterren, 4.8);
      expect(k.beoordelingen, 12);
      expect(k.isIdGecontroleerd, isTrue);
      expect(k.laatsteRecensie, 'Heel netjes.');
      expect(k.bericht, 'Ik heb tijd.');
    },
  );

  group('kiezen', () {
    test('200 is de match met de voornaam van de strijder', () async {
      final server = _NepServer()
        ..zet('POST', '/api/hh/klussen/k1/kiezen', 200, {
          'melding': 'Het is een match!',
          'helper_voornaam': 'Ruud',
        });
      final uit = await server.gateway().kiezen('k1', 'r1');
      expect((uit as Gekozen).helperVoornaam, 'Ruud');
      expect(jsonDecode(server.verzoeken.single.body), {'reactie': 'r1'});
    });

    test('409 helperbezet wordt KiesGeweigerd met de melding', () async {
      final server = _NepServer()
        ..zet('POST', '/api/hh/klussen/k1/kiezen', 409, {
          'reden': 'helperbezet',
          'melding': 'Deze strijder heeft op dat moment al een andere klus.',
        });
      final uit = await server.gateway().kiezen('k1', 'r1');
      expect((uit as KiesGeweigerd).reden, 'helperbezet');
    });
  });

  test('Ik kan nu helpen: aan geeft het eindmoment, uit null', () async {
    final server = _NepServer()
      ..zet('POST', '/api/hh/beschikbaar', 200, {
        'beschikbaar_tot': '2026-10-04 13:00:00.000Z',
        'aan': true,
      });
    final aan = await server.gateway().zetBeschikbaar(true);
    expect((aan as Ok<DateTime?>).waarde, DateTime.utc(2026, 10, 4, 13));
    server.zet('POST', '/api/hh/beschikbaar', 200, {
      'beschikbaar_tot': '',
      'aan': false,
    });
    final uit = await server.gateway().zetBeschikbaar(false);
    expect((uit as Ok<DateTime?>).waarde, isNull);
  });

  test('aantal strijders dat nu kan: klustype en tijden in de vraag', () async {
    final server = _NepServer()
      ..zet('GET', '/api/hh/beschikbaar', 200, {'aantal': 4});
    final uit = await server.gateway().aantalBeschikbaar(
      klustypeId: 't1',
      van: DateTime.utc(2026, 10, 10, 8),
    );
    expect((uit as Ok<int>).waarde, 4);
    final q = Uri.splitQueryString(server.verzoeken.single.query);
    expect(q['klustype'], 't1');
    expect(q['van'], '2026-10-10T08:00:00.000Z');
    expect(q.containsKey('tot'), isFalse);
  });

  test('HhKlus leest reacties_aantal en mijn_reactie (verrijking B5)', () {
    final klus = HhKlus.vanRecord(
      RecordModel.fromJson({
        'id': 'k1',
        'hulpvrager': 'b1',
        'status': 'open',
        'reacties_aantal': 3,
        'mijn_reactie': 'wacht_op_ouder',
      }),
    );
    expect(klus.reactiesAantal, 3);
    expect(klus.mijnReactie, 'wacht_op_ouder');
    final zonder = HhKlus.vanRecord(
      RecordModel.fromJson({'id': 'k2', 'status': 'open'}),
    );
    expect(zonder.reactiesAantal, 0);
    expect(zonder.mijnReactie, '');
  });

  test('HhProfiel leest beschikbaar_tot', () {
    final p = HhProfiel.vanRecord(
      RecordModel.fromJson({
        'id': 'p1',
        'gebruiker': 'h1',
        'beschikbaar_tot': '2026-10-04 13:00:00.000Z',
      }),
    );
    expect(p.beschikbaarTot, DateTime.utc(2026, 10, 4, 13));
    expect(p.copyWith(beschikbaarTot: () => null).beschikbaarTot, isNull);
  });
}

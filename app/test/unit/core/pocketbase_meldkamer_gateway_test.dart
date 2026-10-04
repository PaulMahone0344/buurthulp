import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/meldkamer_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_te_doen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Nep-server: antwoordt per pad (collectie-lijst of route).
class _Nep {
  final List<({String methode, String pad, String query, String body})>
  verzoeken = [];
  int status = 200;
  final Map<String, Object> perPad = {};

  PocketBaseMeldkamerGateway gateway() => PocketBaseMeldkamerGateway(
    PocketBaseClientGateway(
      client: PocketBase(
        'https://nep.test',
        httpClientFactory: () => MockClient((v) async {
          verzoeken.add((
            methode: v.method,
            pad: v.url.path,
            query: v.url.queryParameters['filter'] ?? '',
            body: v.body,
          ));
          final antwoord =
              perPad[v.url.path] ??
              {'items': [], 'page': 1, 'perPage': 500, 'totalItems': 0};
          return http.Response(
            jsonEncode(antwoord),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ),
  );
}

Map<String, Object> _lijst(List<Map<String, Object>> items) => {
  'items': items,
  'page': 1,
  'perPage': 500,
  'totalItems': items.length,
  'totalPages': 1,
};

void main() {
  test('teDoen: vier lijsten met de juiste filters', () async {
    final nep = _Nep()
      ..perPad['/api/collections/hh_users/records'] = _lijst([
        {
          'id': 'b1',
          'collectionName': 'hh_users',
          'naam': 'Anja',
          'telefoon': '0612345678',
          'plaats': 'Tiel',
        },
      ])
      ..perPad['/api/collections/hh_profielen/records'] = _lijst([
        {
          'id': 'p1',
          'collectionName': 'hh_profielen',
          'gebruiker': 'u1',
          'expand': {
            'gebruiker': {
              'id': 'u1',
              'collectionName': 'hh_users',
              'naam': 'Sanne',
              'geboortedatum': '2006-01-01 00:00:00.000Z',
            },
          },
        },
      ])
      ..perPad['/api/collections/hh_ouder_toestemming/records'] = _lijst([
        {
          'id': 'o1',
          'collectionName': 'hh_ouder_toestemming',
          'helper': 'h1',
          'expand': {
            'helper': {
              'id': 'h1',
              'collectionName': 'hh_users',
              'naam': 'Daan',
            },
          },
        },
      ])
      ..perPad['/api/collections/hh_klussen/records'] = _lijst([
        {
          'id': 'k1',
          'collectionName': 'hh_klussen',
          'omschrijving': 'Heg knippen',
          'wacht_op_kennismaking': true,
          'expand': {
            'hulpvrager': {
              'id': 'b1',
              'collectionName': 'hh_users',
              'naam': 'Anja',
            },
            'klustype': {
              'id': 't1',
              'collectionName': 'hh_klustypes',
              'naam': 'tuin',
            },
          },
        },
      ]);

    final result = await nep.gateway().teDoen();
    final t = (result as Ok<HhTeDoen>).waarde;
    expect(t.bellen.single.telefoon, '0612345678');
    expect(t.helpers.single.naam, 'Sanne');
    expect(t.helpers.single.geboortedatum, DateTime.utc(2006));
    expect(t.ouders.single.helperId, 'h1');
    expect(t.klussen.single.wachtOpBelletje, isTrue);
    expect(t.klussen.single.soort, 'tuin');
    expect(t.totaal, 4);

    String query(String pad) =>
        nep.verzoeken.firstWhere((v) => v.pad == pad).query;
    expect(
      query('/api/collections/hh_users/records'),
      contains(HhTeBellen.filter),
    );
    expect(
      query('/api/collections/hh_profielen/records'),
      contains('verificatiestatus = "in_behandeling"'),
    );
    expect(
      query('/api/collections/hh_ouder_toestemming/records'),
      contains('status = "ingetrokken"'),
    );
    expect(
      query('/api/collections/hh_klussen/records'),
      contains(HhTeKeurenKlus.filter),
    );
  });

  test('kennismaking: POST besluit + notitie, uitkomst terug', () async {
    final nep = _Nep()
      ..perPad[kennismakingRoute('b1')] = {
        'gebruiker': 'b1',
        'kennismaking_status': 'geweigerd',
        'geannuleerd': 2,
        'lopend': 1,
      };
    final r = await nep.gateway().kennismaking(
      'b1',
      KennismakingBesluit.geweigerd,
      ' Wil zorg. ',
    );
    final uit = (r as Ok<KennismakingUitkomst>).waarde;
    expect(uit.geannuleerd, 2);
    expect(uit.lopend, 1);
    expect(nep.verzoeken.single.methode, 'POST');
    expect(jsonDecode(nep.verzoeken.single.body), {
      'besluit': 'geweigerd',
      'notitie': 'Wil zorg.',
    });
  });

  test(
    'beoordeelHelper: PATCH verificatiestatus + notitie, niets anders',
    () async {
      final nep = _Nep()
        ..perPad['/api/collections/hh_profielen/records/p1'] = {
          'id': 'p1',
          'collectionName': 'hh_profielen',
        };
      await nep.gateway().beoordeelHelper(
        'p1',
        goedkeuren: false,
        notitie: 'ID klopt niet',
      );
      expect(nep.verzoeken.single.methode, 'PATCH');
      expect(jsonDecode(nep.verzoeken.single.body), {
        'verificatiestatus': 'afgewezen',
        'screening_notitie': 'ID klopt niet',
      });
    },
  );

  test('keurKlus en ouderVrijgeven: de bestaande routes', () async {
    final nep = _Nep()
      ..perPad[keurRoute('k1')] = {'klus': 'k1'}
      ..perPad[ouderVrijgevenRoute] = {'ok': true};
    final g = nep.gateway();
    await g.keurKlus('k1', goedkeuren: true);
    await g.keurKlus('k1', goedkeuren: false, reden: ' Dit mag niet. ');
    await g.ouderVrijgeven('h1');
    expect(jsonDecode(nep.verzoeken[0].body), {'besluit': 'goedkeuren'});
    expect(jsonDecode(nep.verzoeken[1].body), {
      'besluit': 'afkeuren',
      'reden': 'Dit mag niet.',
    });
    expect(nep.verzoeken[2].pad, ouderVrijgevenRoute);
    expect(jsonDecode(nep.verzoeken[2].body), {'helper': 'h1'});
  });

  test('409 van de server: de Nederlandse melding komt mee', () async {
    final nep = _Nep()
      ..status = 409
      ..perPad[keurRoute('k1')] = {
        'melding': 'Bel eerst de bewoner voor de kennismaking.',
        'reden': 'kennismaking',
      };
    final r = await nep.gateway().keurKlus('k1', goedkeuren: true);
    expect(
      (r as Err<void>).fout.melding,
      'Bel eerst de bewoner voor de kennismaking.',
    );
  });
}

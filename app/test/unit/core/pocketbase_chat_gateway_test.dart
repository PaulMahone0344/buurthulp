import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/chat_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/chat/model/hh_bericht.dart';
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

const _berichten = '/api/collections/hh_berichten/records';

Map<String, dynamic> _bericht({
  String id = 'm1',
  String klus = 'k1',
  String gelezen = '',
  bool gefilterd = false,
  bool gewist = false,
}) => {
  'id': id,
  'collectionName': 'hh_berichten',
  'klus': klus,
  'afzender': 'j1',
  'helper': 'j1',
  'tekst': 'Ik ben onderweg',
  'soort': 'snel',
  'gelezen_op': gelezen,
  'gefilterd': gefilterd,
  'gewist': gewist,
  'created': '2026-10-04 09:52:00.000Z',
};

Map<String, dynamic> _pagina(List<Map<String, dynamic>> items) => {
  'page': 1,
  'perPage': 500,
  'totalItems': -1,
  'totalPages': -1,
  'items': items,
};

void main() {
  test('berichten: van deze klus en deze strijder, oudste eerst', () async {
    final server = _NepServer()
      ..zet('GET', _berichten, 200, _pagina([_bericht(gefilterd: true)]));
    final r = await PocketBaseChatGateway(
      server.gateway(),
    ).berichten('k1', helperId: 'j1');
    final b = (r as Ok<List<HhBericht>>).waarde.single;
    expect(b.soort, HhBerichtSoort.snel);
    expect(b.helperId, 'j1');
    expect(b.isGefilterd, isTrue);
    expect(b.gemaakt, DateTime.utc(2026, 10, 4, 9, 52));
    final query = server.verzoeken.single.query;
    expect(query, contains('klus = "k1"'));
    expect(query, contains('helper = "j1"'));
    expect(query, contains('sort=created,id'));
  });

  test('verstuur: stuurt alleen klus, afzender, tekst en soort', () async {
    final server = _NepServer()..zet('POST', _berichten, 200, _bericht());
    final uit = await PocketBaseChatGateway(server.gateway()).verstuur(
      klusId: 'k1',
      afzenderId: 'j1',
      tekst: 'Ik ben onderweg',
      soort: HhBerichtSoort.snel,
    );
    expect(uit, isA<Verstuurd>());
    final body = jsonDecode(server.verzoeken.single.body) as Map;
    expect(body.keys.toSet(), {'klus', 'afzender', 'tekst', 'soort'});
    expect(body['soort'], 'snel');
  });

  test(
    'verstuur: 403 (dicht) en 400 (rule) -> geweigerd, 500 -> fout',
    () async {
      for (final (status, verwacht) in [
        (403, isA<VerstuurGeweigerd>()),
        (400, isA<VerstuurGeweigerd>()),
        (500, isA<VerstuurFout>()),
      ]) {
        final server = _NepServer()
          ..zet('POST', _berichten, status, {
            'status': status,
            'message': 'Deze chat is gesloten.',
            'data': {},
          });
        final uit = await PocketBaseChatGateway(
          server.gateway(),
        ).verstuur(klusId: 'k1', afzenderId: 'b1', tekst: 'Hoi');
        expect(uit, verwacht, reason: '$status');
      }
    },
  );

  test('markeerGelezen: alleen gelezen_op in de body', () async {
    final server = _NepServer()
      ..zet(
        'PATCH',
        '$_berichten/m1',
        200,
        _bericht(gelezen: '2026-10-04 10:00:00.000Z'),
      );
    final r = await PocketBaseChatGateway(
      server.gateway(),
    ).markeerGelezen('m1', DateTime.utc(2026, 10, 4, 10));
    expect((r as Ok<HhBericht>).waarde.isGelezen, isTrue);
    final body = jsonDecode(server.verzoeken.single.body) as Map;
    expect(body.keys.toList(), ['gelezen_op']);
  });

  test('ongelezenPerKlus: telt per klus, alleen het huidige gesprek', () async {
    final server = _NepServer()
      ..zet(
        'GET',
        _berichten,
        200,
        _pagina([
          _bericht(id: 'a'),
          _bericht(id: 'b'),
          _bericht(id: 'c', klus: 'k2'),
        ]),
      );
    final r = await PocketBaseChatGateway(
      server.gateway(),
    ).ongelezenPerKlus('b1');
    expect((r as Ok<Map<String, int>>).waarde, {'k1': 2, 'k2': 1});
    final query = server.verzoeken.first.query;
    expect(query, contains('afzender != "b1"'));
    expect(query, contains('gelezen_op = ""'));
    expect(query, contains('helper = klus.toegewezen_jongere'));
  });

  test('geen verbinding: een nette fout, geen exception', () async {
    final client = PocketBase(
      'https://nep.test',
      httpClientFactory: () =>
          MockClient((_) async => throw http.ClientException('weg')),
    );
    final r = await PocketBaseChatGateway(
      PocketBaseClientGateway(client: client),
    ).berichten('k1', helperId: 'j1');
    expect((r as Err).fout.soort, HhFoutSoort.geenVerbinding);
  });

  // Integratie (antwoorden Ibrahim 4 okt): gesprek verwijderen en AVG.
  test('een gewist bericht (account weg) komt binnen als isGewist', () async {
    final server = _NepServer()
      ..zet('GET', _berichten, 200, _pagina([_bericht(gewist: true)]));
    final r = await PocketBaseChatGateway(
      server.gateway(),
    ).berichten('k1', helperId: 'j1');
    expect((r as Ok<List<HhBericht>>).waarde.single.isGewist, isTrue);
  });

  test(
    'verbergGesprek: POST naar de route; 409 = incident, 500 = fout',
    () async {
      const pad = '/api/hh/chat/k1/verbergen';
      for (final (status, verwacht) in [
        (200, isA<GesprekVerborgen>()),
        (409, isA<GesprekIncident>()),
        (500, isA<GesprekVerbergFout>()),
      ]) {
        final server = _NepServer()
          ..zet(
            'POST',
            pad,
            status,
            status == 200
                ? {'verborgen': 2}
                : {'status': status, 'message': 'x', 'data': {}},
          );
        final uit = await PocketBaseChatGateway(
          server.gateway(),
        ).verbergGesprek('k1');
        expect(uit, verwacht, reason: '$status');
        expect(server.verzoeken.single.methode, 'POST');
        expect(server.verzoeken.single.pad, pad);
      }
    },
  );
}

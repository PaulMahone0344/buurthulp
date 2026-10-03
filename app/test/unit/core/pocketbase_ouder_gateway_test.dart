import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/ouder_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/jongere/ouder/model/hh_ouder_stand.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

class _Nep {
  final List<({String methode, String pad, String body})> verzoeken = [];
  int status = 200;
  Object antwoord = const {};

  PocketBaseOuderGateway gateway() => PocketBaseOuderGateway(
    PocketBaseClientGateway(
      client: PocketBase(
        'https://nep.test',
        httpClientFactory: () => MockClient((v) async {
          verzoeken.add((methode: v.method, pad: v.url.path, body: v.body));
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

void main() {
  test('haalStand: GET /api/hh/ouder/status', () async {
    final nep = _Nep()
      ..antwoord = {'status': 'gegeven', 'nodig': true, 'nog_te_sturen': 3};
    final result = await nep.gateway().haalStand();
    expect(nep.verzoeken.single.methode, 'GET');
    expect(nep.verzoeken.single.pad, hhOuderStatusPad);
    expect((result as Ok<HhOuderStand>).waarde.status, HhOuderStatus.gegeven);
  });

  test('verstuur: POST met het nieuwe adres, nooit een code', () async {
    final nep = _Nep()
      ..antwoord = {
        'status': 'verstuurd',
        'ouder_email': 'mama@voorbeeld.nl',
        'nog_te_sturen': 2,
      };
    final uit = await nep.gateway().verstuur(ouderEmail: ' mama@voorbeeld.nl ');
    expect(nep.verzoeken.single.methode, 'POST');
    expect(nep.verzoeken.single.pad, hhOuderVersturenPad);
    expect(jsonDecode(nep.verzoeken.single.body), {
      'ouder_email': 'mama@voorbeeld.nl',
    });
    expect((uit as OuderVerstuurd).stand.nogTeSturen, 2);
  });

  test(
    'verstuur zonder adres: lege body (de server pakt het bewaarde)',
    () async {
      final nep = _Nep()..antwoord = {'status': 'verstuurd'};
      await nep.gateway().verstuur();
      final body = nep.verzoeken.single.body;
      expect(body.isEmpty || body == '{}', isTrue, reason: body);
    },
  );

  test('weigering van de hook: reden en melding van de server', () async {
    final nep = _Nep()
      ..status = 429
      ..antwoord = {
        'melding': 'Je hebt vandaag al 3 keer een mail gestuurd.',
        'reden': 'limiet',
      };
    final uit = await nep.gateway().verstuur();
    expect(uit, isA<OuderGeweigerd>());
    expect((uit as OuderGeweigerd).reden, 'limiet');
    expect(uit.melding, startsWith('Je hebt vandaag'));
  });

  test('401 is gewoon sessie verlopen', () async {
    final nep = _Nep()
      ..status = 401
      ..antwoord = {'message': 'x'};
    final uit = await nep.gateway().verstuur();
    expect((uit as OuderVerstuurFout).fout.soort, HhFoutSoort.nietIngelogd);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/adres_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/features/adres/model/hh_adres.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Nep-server: nooit een echt verzoek naar PDOK of prod.
class _Nep {
  final List<Uri> verzoeken = [];
  int status = 200;
  Object antwoord = const {};
  bool geenVerbinding = false;

  PocketBaseAdresGateway gateway() => PocketBaseAdresGateway(
    PocketBaseClientGateway(
      client: PocketBase(
        'https://nep.test',
        httpClientFactory: () => MockClient((v) async {
          verzoeken.add(v.url);
          if (geenVerbinding) throw http.ClientException('weg');
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

Map<String, Object> _adres({String toevoeging = '', bool binnen = true}) => {
  'straat': 'Kerkstraat',
  'huisnummer': '1',
  'toevoeging': toevoeging,
  'postcode': '4001 MA',
  'plaats': 'Tiel',
  'gemeente': 'Tiel',
  'lat': 51.88761538,
  'lon': 5.43597055,
  'adres': 'Kerkstraat 1$toevoeging',
  'weergave': 'Kerkstraat 1$toevoeging, 4001 MA Tiel',
  'binnen_werkgebied': binnen,
};

void main() {
  test(
    'zoek: GET /api/hh/adres met postcode, huisnummer, toevoeging',
    () async {
      final nep = _Nep()
        ..antwoord = {
          'gevonden': true,
          'adressen': [_adres()],
        };
      final uit = await nep.gateway().zoek(
        postcode: '4001 MA',
        huisnummer: '1',
        toevoeging: '',
      );
      final url = nep.verzoeken.single;
      expect(url.path, hhAdresPad);
      expect(url.queryParameters['postcode'], '4001 MA');
      expect(url.queryParameters['huisnummer'], '1');
      expect(url.queryParameters['toevoeging'], '');
      expect(
        (uit as AdresGevonden).adressen.single.weergave,
        'Kerkstraat 1, 4001 MA Tiel',
      );
    },
  );

  test('meerdere adressen -> keuzelijst', () async {
    final nep = _Nep()
      ..antwoord = {
        'gevonden': true,
        'adressen': [_adres(toevoeging: 'A'), _adres(toevoeging: 'B')],
      };
    final uit = await nep.gateway().zoek(postcode: '4001 MA', huisnummer: '1');
    expect((uit as AdresGevonden).adressen, hasLength(2));
  });

  test('niet gevonden -> rustige melding van de server', () async {
    final nep = _Nep()
      ..antwoord = {
        'gevonden': false,
        'reden': 'nietgevonden',
        'melding':
            'We vinden dit adres niet. Klopt de postcode en het huisnummer?',
      };
    final uit = await nep.gateway().zoek(postcode: '4001 MA', huisnummer: '9');
    expect(uit, isA<AdresNietGevonden>());
    expect((uit as AdresNietGevonden).keuzes, isEmpty);
  });

  test('onbekende toevoeging -> niet gevonden mét de keuzes', () async {
    final nep = _Nep()
      ..antwoord = {
        'gevonden': false,
        'reden': 'toevoeging',
        'melding': 'Kies er een.',
        'adressen': [_adres(toevoeging: 'A')],
      };
    final uit = await nep.gateway().zoek(
      postcode: '4001 MA',
      huisnummer: '1',
      toevoeging: 'Z',
    );
    expect((uit as AdresNietGevonden).keuzes, hasLength(1));
  });

  test('PDOK onbereikbaar (reden dienst) -> AdresDienstWeg', () async {
    final nep = _Nep()
      ..antwoord = {'gevonden': false, 'reden': 'dienst', 'melding': 'x'};
    expect(
      await nep.gateway().zoek(postcode: '4001 MA', huisnummer: '1'),
      isA<AdresDienstWeg>(),
    );
  });

  test('400 -> AdresOngeldig met de reden van de server', () async {
    final nep = _Nep()
      ..status = 400
      ..antwoord = {
        'gevonden': false,
        'reden': 'postcode',
        'melding': 'Een postcode is ...',
      };
    final uit = await nep.gateway().zoek(postcode: '4001', huisnummer: '1');
    expect((uit as AdresOngeldig).reden, 'postcode');
  });

  test('429 -> AdresLimiet', () async {
    final nep = _Nep()
      ..status = 429
      ..antwoord = {
        'gevonden': false,
        'reden': 'limiet',
        'melding': 'Probeer het over een uur opnieuw.',
      };
    expect(
      await nep.gateway().zoek(postcode: '4001 MA', huisnummer: '1'),
      isA<AdresLimiet>(),
    );
  });

  test(
    'geen verbinding -> AdresDienstWeg (aanmelden mag dan ongecontroleerd)',
    () async {
      final nep = _Nep()..geenVerbinding = true;
      expect(
        await nep.gateway().zoek(postcode: '4001 MA', huisnummer: '1'),
        isA<AdresDienstWeg>(),
      );
    },
  );
}

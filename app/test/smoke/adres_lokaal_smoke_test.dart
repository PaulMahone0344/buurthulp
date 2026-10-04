// Lokale proef voor ADRES: de ECHTE app-code (PocketBaseAdresGateway en
// PocketBaseAuthGateway) tegen een LOKALE PocketBase 0.25.9 met het
// prod-schema, 120 en de hooks van deze branch, met een nep-PDOK. Nooit
// tegen prod: de test weigert elke URL die niet met http://127.0.0.1 begint.
//
// Draait alleen met een define; anders wordt hij overgeslagen:
//   flutter test test/smoke/adres_lokaal_smoke_test.dart \
//     --dart-define=HH_ADRES_LOKAAL=http://127.0.0.1:8290

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/adres_gateway.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/adres/domein/adres_invoer.dart';
import 'package:heitjehulp_app/features/adres/model/hh_adres.dart';
import 'package:heitjehulp_app/features/toegang/domein/aanmelding.dart';
import 'package:heitjehulp_app/features/toegang/domein/werkgebied.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:pocketbase/pocketbase.dart';

const _url = String.fromEnvironment('HH_ADRES_LOKAAL');

void main() {
  final overslaan = _url.isEmpty
      ? 'alleen met --dart-define=HH_ADRES_LOKAAL=http://127.0.0.1:...'
      : (!_url.startsWith('http://127.0.0.1') ? 'alleen lokaal' : null);

  PocketBaseGateway gateway() =>
      PocketBaseClientGateway(client: PocketBase(_url));

  test('opzoeken: Kerkstraat 1 en een flat met toevoegingen', () async {
    final adres = PocketBaseAdresGateway(gateway());
    final een = await adres.zoek(postcode: '4001 MA', huisnummer: '1');
    expect(
      (een as AdresGevonden).adressen.single.weergave,
      'Kerkstraat 1, 4001 MA Tiel',
    );
    expect(een.adressen.single.binnenWerkgebied, isTrue);
    final flat = await adres.zoek(postcode: '4001 JS', huisnummer: '1');
    expect((flat as AdresGevonden).adressen, hasLength(3));
    final niet = await adres.zoek(postcode: '4001 MA', huisnummer: '9999');
    expect(niet, isA<AdresNietGevonden>());
    final fout = await adres.zoek(postcode: '0401 MA', huisnummer: '1');
    expect((fout as AdresOngeldig).reden, 'postcode');
  }, skip: overslaan);

  test(
    'aanmelden met de keuze: straat/plaats van PDOK, wijk uit het punt',
    () async {
      final adres = PocketBaseAdresGateway(gateway());
      final keuze = AdresKeuze.bevestigd(
        ((await adres.zoek(postcode: '4001 MA', huisnummer: '1'))
                as AdresGevonden)
            .adressen
            .single,
      );
      final email =
          'adres-smoke-${Random().nextInt(1 << 30)}@heitjehulp.invalid';
      final result = await PocketBaseAuthGateway(gateway()).registreren(
        BewonerAanmelding(
          naam: '[adres-smoke] bewoner',
          email: email,
          wachtwoord: 'AdresSmoke-2026x',
          adres: keuze,
        ),
      );
      final gebruiker = (result as Ok<HhGebruiker>).waarde;
      expect(gebruiker.postcode, '4001 MA');
      expect(gebruiker.heeftVolledigAdres, isTrue);
      expect(gebruiker.werkgebiedStatus, HhWerkgebiedStatus.binnen);
      expect(gebruiker.wijkId, isNotEmpty);
    },
    skip: overslaan,
  );

  test(
    'aanmelden met een adres dat niet bestaat: de melding van de server',
    () async {
      final email =
          'adres-smoke-${Random().nextInt(1 << 30)}@heitjehulp.invalid';
      final result = await PocketBaseAuthGateway(gateway()).registreren(
        BewonerAanmelding(
          naam: '[adres-smoke] niet',
          email: email,
          wachtwoord: 'AdresSmoke-2026x',
          adres: const AdresKeuze.ongecontroleerd(
            postcode: '4001 MA',
            huisnummer: '9999',
          ),
        ),
      );
      final fout = (result as Err<HhGebruiker>).fout;
      expect(fout.soort, HhFoutSoort.adresOngeldig);
      expect(
        fout.melding,
        'We vinden dit adres niet. Klopt de postcode en het huisnummer?',
      );
    },
    skip: overslaan,
  );
}

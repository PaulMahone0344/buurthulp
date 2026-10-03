import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/dichtheid_controller.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_auth_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/toegang/domein/aanmelding.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_toegang_wikkel.dart';

const _tokenSleutel = 'hh_auth_token';

({
  ProviderContainer container,
  FakeAuthGateway gateway,
  GeheugenKeyValueStore opslag,
})
_maak({Map<String, String>? opslagBegin}) {
  final gateway = fakeMetAlleRollen();
  final opslag = GeheugenKeyValueStore(opslagBegin);
  final container = toegangContainer(gateway: gateway, opslag: opslag);
  // Providers zijn lui: een keer lezen start het herstel bij het opstarten.
  container.read(sessieControllerProvider);
  return (container: container, gateway: gateway, opslag: opslag);
}

Future<void> _wacht() => Future<void>.delayed(Duration.zero);

void main() {
  group('SessieController.herstel', () {
    test('zonder bewaard token: uitgelogd', () async {
      final t = _maak();

      expect(t.container.read(sessieControllerProvider), isA<SessieOnbekend>());
      await _wacht();

      final state = t.container.read(sessieControllerProvider);
      expect(state, isA<SessieUitgelogd>());
      expect((state as SessieUitgelogd).reden, UitlogReden.geen);
    });

    test('met geldig token: ingelogd en token opnieuw bewaard', () async {
      final t = _maak(
        opslagBegin: {_tokenSleutel: testToken(HhRol.hulpvrager)},
      );

      await _wacht();

      final state = t.container.read(sessieControllerProvider);
      expect((state as SessieIngelogd).gebruiker.rol, HhRol.hulpvrager);
      expect(t.opslag.waarden[_tokenSleutel], testToken(HhRol.hulpvrager));
    });

    test(
      '401 bij herstel: token gewist, uitgelogd met reden verlopen',
      () async {
        final t = _maak(opslagBegin: {_tokenSleutel: 'verlopen'});
        t.gateway.tokenIsVerlopen = true;

        await _wacht();

        final state = t.container.read(sessieControllerProvider);
        expect((state as SessieUitgelogd).reden, UitlogReden.sessieVerlopen);
        expect(t.opslag.waarden.containsKey(_tokenSleutel), isFalse);
      },
    );

    test(
      'geen verbinding bij herstel: onbekend met fout, token blijft',
      () async {
        final t = _maak(opslagBegin: {_tokenSleutel: testToken(HhRol.jongere)});
        t.gateway.isOffline = true;

        await _wacht();

        final state = t.container.read(sessieControllerProvider);
        expect((state as SessieOnbekend).fout?.isGeenVerbinding, isTrue);
        expect(t.opslag.waarden[_tokenSleutel], testToken(HhRol.jongere));

        // Verbinding terug: opnieuw proberen slaagt.
        t.gateway.isOffline = false;
        await t.container.read(sessieControllerProvider.notifier).herstel();
        expect(
          t.container.read(sessieControllerProvider),
          isA<SessieIngelogd>(),
        );
      },
    );
  });

  group('SessieController.inloggen en registreren', () {
    test('inloggen slaagt: ingelogd, token bewaard, letters normaal', () async {
      final t = _maak();
      await _wacht();

      final result = await t.container
          .read(sessieControllerProvider.notifier)
          .inloggen(
            email: testGebruiker(HhRol.hulpvrager).email,
            wachtwoord: testWachtwoord,
          );

      expect(result, isA<Ok<void>>());
      expect(t.container.read(huidigeGebruikerProvider)?.rol, HhRol.hulpvrager);
      expect(t.opslag.waarden[_tokenSleutel], testToken(HhRol.hulpvrager));
      expect(t.container.read(dichtheidProvider), HhDichtheid.normaal);
    });

    test('inloggen met fout wachtwoord: Err en uitgelogd', () async {
      final t = _maak();
      await _wacht();

      final result = await t.container
          .read(sessieControllerProvider.notifier)
          .inloggen(
            email: testGebruiker(HhRol.jongere).email,
            wachtwoord: 'verkeerd',
          );

      expect((result as Err<void>).fout.soort, HhFoutSoort.ongeldigeInlog);
      expect(
        t.container.read(sessieControllerProvider),
        isA<SessieUitgelogd>(),
      );
      expect(t.opslag.waarden.containsKey(_tokenSleutel), isFalse);
    });

    test('inloggen offline: Err geen verbinding', () async {
      final t = _maak();
      await _wacht();
      t.gateway.isOffline = true;

      final result = await t.container
          .read(sessieControllerProvider.notifier)
          .inloggen(
            email: testGebruiker(HhRol.jongere).email,
            wachtwoord: testWachtwoord,
          );

      expect((result as Err<void>).fout.isGeenVerbinding, isTrue);
    });

    test('registreren stuurt rol en taal nl mee en logt in', () async {
      final t = _maak();
      await _wacht();

      final result = await t.container
          .read(sessieControllerProvider.notifier)
          .registreren(
            const BewonerAanmelding(
              naam: 'Nieuw',
              email: 'nieuw@voorbeeld.nl',
              wachtwoord: 'wachtwoord1',
              straat: 'Dorpsstraat',
              huisnummer: '1',
              postcode: '4003 AB',
              plaats: 'Tiel',
            ),
          );

      expect(result, isA<Ok<void>>());
      expect(t.gateway.laatsteRegistratieBody?['rol'], 'hulpvrager');
      expect(t.gateway.laatsteRegistratieBody?['taal'], 'nl');
      expect(t.gateway.laatsteRegistratieBody?['adres'], 'Dorpsstraat 1');
      expect(t.container.read(huidigeGebruikerProvider)?.naam, 'Nieuw');
      expect(t.container.read(dichtheidProvider), HhDichtheid.normaal);
    });
  });

  group('SessieController: uitloggen, bijwerken, wissen', () {
    Future<ProviderContainer> ingelogdAls(
      ({
        ProviderContainer container,
        FakeAuthGateway gateway,
        GeheugenKeyValueStore opslag,
      })
      t,
      HhRol rol,
    ) async {
      await _wacht();
      await t.container
          .read(sessieControllerProvider.notifier)
          .inloggen(
            email: testGebruiker(rol).email,
            wachtwoord: testWachtwoord,
          );
      return t.container;
    }

    test('uitloggen wist token en zet uitgelogd', () async {
      final t = _maak();
      final container = await ingelogdAls(t, HhRol.coordinator);

      await container.read(sessieControllerProvider.notifier).uitloggen();

      expect(container.read(sessieControllerProvider), isA<SessieUitgelogd>());
      expect(t.opslag.waarden.containsKey(_tokenSleutel), isFalse);
      expect(t.gateway.ingelogd, isNull);
    });

    test('bijwerken stuurt alleen het gewijzigde veld', () async {
      final t = _maak();
      final container = await ingelogdAls(t, HhRol.jongere);

      final result = await container
          .read(sessieControllerProvider.notifier)
          .bijwerken({'taal': 'ar'});

      expect(result, isA<Ok<void>>());
      expect(t.gateway.laatsteUpdateBody, {'taal': 'ar'});
      expect(container.read(huidigeGebruikerProvider)?.taal.code, 'ar');
    });

    test('bijwerken met 401 logt uit met reden verlopen', () async {
      final t = _maak();
      final container = await ingelogdAls(t, HhRol.jongere);
      t.gateway.volgendeFout = const HhFout(HhFoutSoort.nietIngelogd);

      final result = await container
          .read(sessieControllerProvider.notifier)
          .bijwerken({'taal': 'ar'});

      expect(result, isA<Err<void>>());
      final state = container.read(sessieControllerProvider);
      expect((state as SessieUitgelogd).reden, UitlogReden.sessieVerlopen);
      expect(t.opslag.waarden.containsKey(_tokenSleutel), isFalse);
    });

    test('accountWissen: record weg, token weg, uitgelogd', () async {
      final t = _maak();
      final container = await ingelogdAls(t, HhRol.hulpvrager);

      final result = await container
          .read(sessieControllerProvider.notifier)
          .accountWissen();

      expect(result, isA<Ok<void>>());
      expect(t.gateway.gewisteAccounts, [testGebruiker(HhRol.hulpvrager).id]);
      final state = container.read(sessieControllerProvider);
      expect((state as SessieUitgelogd).reden, UitlogReden.accountGewist);
      expect(t.opslag.waarden.containsKey(_tokenSleutel), isFalse);
    });
  });

  group('dichtheidProvider', () {
    test('normaal voor elke rol, ook de gekozen hulpvrager', () async {
      final t = _maak();
      await _wacht();

      expect(t.container.read(dichtheidProvider), HhDichtheid.normaal);
      t.container.read(gekozenRolProvider.notifier).kies(HhRol.hulpvrager);
      expect(t.container.read(dichtheidProvider), HhDichtheid.normaal);
    });

    test('grotere letters aan: groot, en lokaal bewaard', () async {
      final t = _maak();
      await _wacht();

      await t.container.read(groteLettersProvider.notifier).zet(true);

      expect(t.container.read(dichtheidProvider), HhDichtheid.groot);
      expect(t.opslag.waarden['hh_grote_letters'], 'true');
    });

    test('bewaarde keuze wordt bij opstarten geladen', () async {
      final t = _maak();
      await t.opslag.schrijf('hh_grote_letters', 'true');
      t.container.invalidate(groteLettersProvider);
      t.container.read(groteLettersProvider);
      await _wacht();

      expect(t.container.read(dichtheidProvider), HhDichtheid.groot);
    });
  });
}

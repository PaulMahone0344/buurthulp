import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/features/toegang/kennismaken/kennismaken_controller.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';

import '../../../support/hh_toegang_wikkel.dart';

const _sleutel = 'hh_kennismaking_gezien';

void main() {
  group('kennismakingRedirect', () {
    const uit = SessieUitgelogd();

    test('nog niet gezien: welkom wordt kennismaken', () {
      expect(
        kennismakingRedirect(uit, false, HhPaden.welkom),
        HhPaden.kennismaken,
      );
    });

    test('nog onbekend: de splash blijft staan', () {
      expect(kennismakingRedirect(uit, null, HhPaden.splash), HhPaden.splash);
    });

    test('al gezien: kennismaken wordt welkom, welkom blijft', () {
      expect(
        kennismakingRedirect(uit, true, HhPaden.kennismaken),
        HhPaden.welkom,
      );
      expect(kennismakingRedirect(uit, true, HhPaden.welkom), isNull);
    });

    test('andere schermen en ingelogd: geen mening', () {
      expect(kennismakingRedirect(uit, false, HhPaden.inloggen), isNull);
      expect(
        kennismakingRedirect(
          SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
          false,
          HhPaden.welkom,
        ),
        isNull,
      );
    });
  });

  group('KennismakingController', () {
    Future<void> wacht() => Future<void>.delayed(Duration.zero);

    test('leest uit de opslag: leeg = niet gezien', () async {
      final container = toegangContainer(
        gateway: fakeMetAlleRollen(),
        isKennismakingGezien: false,
      );
      expect(container.read(kennismakingGezienProvider), isNull);
      await wacht();
      expect(container.read(kennismakingGezienProvider), isFalse);
    });

    test('bewaard = gezien', () async {
      final container = toegangContainer(
        gateway: fakeMetAlleRollen(),
        opslag: GeheugenKeyValueStore({_sleutel: 'true'}),
        isKennismakingGezien: false,
      );
      container.read(kennismakingGezienProvider);
      await wacht();
      expect(container.read(kennismakingGezienProvider), isTrue);
    });

    test('markeer bewaart het in de opslag', () async {
      final opslag = GeheugenKeyValueStore();
      final container = toegangContainer(
        gateway: fakeMetAlleRollen(),
        opslag: opslag,
        isKennismakingGezien: false,
      );
      await container.read(kennismakingGezienProvider.notifier).markeer();
      expect(container.read(kennismakingGezienProvider), isTrue);
      expect(opslag.waarden[_sleutel], 'true');
    });

    test('wie inlogt heeft hem ook gezien (na uitloggen niet terug)', () async {
      final opslag = GeheugenKeyValueStore();
      final container = toegangContainer(
        gateway: fakeMetAlleRollen(),
        opslag: opslag,
        isKennismakingGezien: false,
      );
      container.read(kennismakingGezienProvider);
      await wacht();
      await container
          .read(sessieControllerProvider.notifier)
          .inloggen(
            email: testGebruiker(HhRol.hulpvrager).email,
            wachtwoord: testWachtwoord,
          );
      await wacht();
      expect(container.read(kennismakingGezienProvider), isTrue);
      expect(opslag.waarden[_sleutel], 'true');
    });
  });
}

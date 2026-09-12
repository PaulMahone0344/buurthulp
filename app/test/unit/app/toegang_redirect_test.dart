import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';

import '../../support/hh_toegang_wikkel.dart';

void main() {
  group('toegangRedirect', () {
    test('sessie onbekend: iedereen blijft op de splash', () {
      const onbekend = SessieOnbekend();
      expect(toegangRedirect(onbekend, HhPaden.splash), isNull);
      expect(toegangRedirect(onbekend, HhPaden.welkom), HhPaden.splash);
      expect(toegangRedirect(onbekend, HhPaden.jongere), HhPaden.splash);

      const offline = SessieOnbekend(fout: HhFout(HhFoutSoort.geenVerbinding));
      expect(toegangRedirect(offline, HhPaden.splash), isNull);
    });

    test('bezig: niets doorsturen', () {
      expect(toegangRedirect(const SessieBezig(), HhPaden.inloggen), isNull);
    });

    test('uitgelogd: toegangsschermen mogen, de rest gaat naar welkom', () {
      const uit = SessieUitgelogd();
      for (final pad in HhPaden.zonderSessie) {
        expect(toegangRedirect(uit, pad), isNull, reason: pad);
      }
      expect(toegangRedirect(uit, HhPaden.splash), HhPaden.welkom);
      expect(toegangRedirect(uit, HhPaden.instellingen), HhPaden.welkom);
      expect(toegangRedirect(uit, HhPaden.bevestigEmail), HhPaden.welkom);
      for (final rol in HhRol.values) {
        expect(toegangRedirect(uit, rol.pad), HhPaden.welkom, reason: rol.code);
      }
    });

    test('sessie verlopen: naar inloggen in plaats van welkom', () {
      const verlopen = SessieUitgelogd(reden: UitlogReden.sessieVerlopen);
      expect(toegangRedirect(verlopen, HhPaden.hulpvrager), HhPaden.inloggen);
      expect(toegangRedirect(verlopen, HhPaden.splash), HhPaden.inloggen);
      expect(toegangRedirect(verlopen, HhPaden.inloggen), isNull);
      expect(toegangRedirect(verlopen, HhPaden.welkom), isNull);
    });

    test('ingelogd: elke rol landt op de eigen route', () {
      for (final rol in HhRol.values) {
        final aan = SessieIngelogd(testGebruiker(rol));
        for (final pad in HhPaden.alleenUitgelogd.where(
          (p) => p != HhPaden.registreren,
        )) {
          expect(
            toegangRedirect(aan, pad),
            rol.pad,
            reason: '$pad ${rol.code}',
          );
        }
        expect(toegangRedirect(aan, rol.pad), isNull, reason: rol.code);
        for (final andere in HhRol.values.where((r) => r != rol)) {
          expect(
            toegangRedirect(aan, andere.pad),
            rol.pad,
            reason: '${rol.code} op ${andere.code}',
          );
        }
        expect(toegangRedirect(aan, HhPaden.instellingen), isNull);
        expect(toegangRedirect(aan, HhPaden.hulp), isNull);
        expect(toegangRedirect(aan, HhPaden.bevestigEmail), isNull);
      }
    });

    test('ingelogd op registreren: eerst e-mail bevestigen (G5)', () {
      final aan = SessieIngelogd(testGebruiker(HhRol.hulpvrager));
      expect(toegangRedirect(aan, HhPaden.registreren), HhPaden.bevestigEmail);
    });
  });
}

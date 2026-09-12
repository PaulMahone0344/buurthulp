import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/model/screening_stap.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/screening_guard.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';

import '../../../support/hh_toegang_wikkel.dart';

void main() {
  final jongere = SessieIngelogd(testGebruiker(HhRol.jongere));

  AsyncValue<ScreeningGegevens> met(HhScreeningStatus status) => AsyncData(
    ScreeningGegevens(
      profiel: HhProfiel(id: 'p', gebruikerId: 'j', verificatiestatus: status),
    ),
  );

  group('screeningRedirect', () {
    test('zonder sessie of bezig: niets', () {
      expect(
        screeningRedirect(
          const SessieUitgelogd(),
          met(HhScreeningStatus.nieuw),
          HhPaden.jongere,
        ),
        isNull,
      );
      expect(
        screeningRedirect(
          const SessieBezig(),
          met(HhScreeningStatus.nieuw),
          HhPaden.jongere,
        ),
        isNull,
      );
    });

    test('jongere zonder profiel gaat van /jongere naar het overzicht', () {
      expect(
        screeningRedirect(
          jongere,
          const AsyncData(ScreeningGegevens()),
          HhPaden.jongere,
        ),
        HhPadenJongere.overzicht,
      );
    });

    test('status -> guard: alleen goedgekeurd mag op /jongere blijven', () {
      for (final status in HhScreeningStatus.values) {
        expect(
          screeningRedirect(jongere, met(status), HhPaden.jongere),
          status == HhScreeningStatus.goedgekeurd
              ? isNull
              : HhPadenJongere.overzicht,
          reason: status.code,
        );
      }
    });

    test('op een screeningpad blijft de jongere altijd', () {
      for (final status in HhScreeningStatus.values) {
        expect(
          screeningRedirect(jongere, met(status), HhPadenJongere.overzicht),
          isNull,
        );
        expect(
          screeningRedirect(jongere, met(status), HhPadenJongere.profiel),
          isNull,
        );
      }
    });

    test('laden of fout: geen redirect (de landing toont de staat)', () {
      expect(
        screeningRedirect(jongere, const AsyncLoading(), HhPaden.jongere),
        isNull,
      );
      expect(
        screeningRedirect(
          jongere,
          const AsyncError(
            HhFout(HhFoutSoort.geenVerbinding),
            StackTrace.empty,
          ),
          HhPaden.jongere,
        ),
        isNull,
      );
    });

    test('andere paden van de jongere raakt de guard niet', () {
      expect(
        screeningRedirect(
          jongere,
          met(HhScreeningStatus.nieuw),
          HhPaden.instellingen,
        ),
        isNull,
      );
      expect(
        screeningRedirect(jongere, met(HhScreeningStatus.nieuw), HhPaden.hulp),
        isNull,
      );
    });

    test('M5: klussenpaden volgen dezelfde regel als /jongere', () {
      final paden = [
        HhPadenKlussen.mijnKlussen,
        HhPadenKlussen.profiel,
        HhPadenKlussen.instellingen,
        HhPadenKlussen.klusDetail('abc'),
      ];
      for (final pad in paden) {
        expect(HhPadenKlussen.isKlussenPad(pad), isTrue, reason: pad);
        for (final status in HhScreeningStatus.values) {
          expect(
            screeningRedirect(jongere, met(status), pad),
            status == HhScreeningStatus.goedgekeurd
                ? isNull
                : HhPadenJongere.overzicht,
            reason: '$pad ${status.code}',
          );
        }
        expect(
          screeningRedirect(jongere, const AsyncLoading(), pad),
          isNull,
          reason: pad,
        );
        for (final rol in HhRol.values.where((r) => r != HhRol.jongere)) {
          expect(
            screeningRedirect(
              SessieIngelogd(testGebruiker(rol)),
              const AsyncData(ScreeningGegevens()),
              pad,
            ),
            rol.pad,
            reason: '$pad ${rol.code}',
          );
        }
      }
      expect(HhPadenKlussen.isKlussenPad(HhPaden.jongere), isFalse);
      expect(HhPadenKlussen.isKlussenPad(HhPadenJongere.overzicht), isFalse);
    });

    test('een andere rol op een screeningpad gaat naar de eigen rolroute', () {
      for (final rol in HhRol.values.where((r) => r != HhRol.jongere)) {
        final sessie = SessieIngelogd(testGebruiker(rol));
        expect(
          screeningRedirect(
            sessie,
            const AsyncData(ScreeningGegevens()),
            HhPadenJongere.overzicht,
          ),
          rol.pad,
          reason: rol.code,
        );
        expect(
          screeningRedirect(
            sessie,
            const AsyncData(ScreeningGegevens()),
            rol.pad,
          ),
          isNull,
          reason: rol.code,
        );
      }
    });
  });
}

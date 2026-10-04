import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/model/screening_stap.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/screening_guard.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';

import '../../../support/hh_toegang_wikkel.dart';

void main() {
  final jongere = SessieIngelogd(testGebruiker(HhRol.jongere));
  DateTime klok() => DateTime(2026, 10, 3);

  /// Een helper van 25 met [status]; [vog] = de meldkamer zag zijn VOG.
  AsyncValue<ScreeningGegevens> met(
    HhScreeningStatus status, {
    bool vog = true,
  }) => AsyncData(
    ScreeningGegevens(
      profiel: HhProfiel(
        id: 'p',
        gebruikerId: 'j',
        verificatiestatus: status,
        vogGezienOp: vog ? DateTime.utc(2026, 9, 1) : null,
      ),
      account: HhAccountGegevens(
        geboortedatum: DateTime.utc(2001, 1, 1),
        wijkId: 'w',
      ),
    ),
  );

  String? guard(AsyncValue<ScreeningGegevens> stand, String pad) =>
      screeningRedirect(jongere, stand, pad, klok: klok);

  group('screeningRedirect (B2)', () {
    test('zonder sessie of bezig: niets', () {
      for (final sessie in const [SessieUitgelogd(), SessieBezig()]) {
        expect(
          screeningRedirect(
            sessie,
            met(HhScreeningStatus.nieuw),
            HhPaden.jongere,
            klok: klok,
          ),
          isNull,
        );
      }
    });

    test('zonder profiel of nog niet verstuurd: naar "Je aanmelding"', () {
      expect(
        guard(const AsyncData(ScreeningGegevens()), HhPaden.jongere),
        HhPadenJongere.overzicht,
      );
      expect(
        guard(met(HhScreeningStatus.nieuw), HhPaden.jongere),
        HhPadenJongere.overzicht,
      );
    });

    test('afgewezen: naar "Je aanmelding" (met Bel ons)', () {
      expect(
        guard(met(HhScreeningStatus.afgewezen), HhPaden.jongere),
        HhPadenJongere.overzicht,
      );
    });

    test('nagekeken of zonder VOG: blijft op Start (gele balk)', () {
      expect(
        guard(met(HhScreeningStatus.inBehandeling), HhPaden.jongere),
        isNull,
      );
      expect(
        guard(met(HhScreeningStatus.goedgekeurd, vog: false), HhPaden.jongere),
        isNull,
      );
    });

    test('wachtend: een klus openen kan niet, de tabs wel', () {
      final wacht = met(HhScreeningStatus.goedgekeurd, vog: false);
      expect(guard(wacht, HhPadenKlussen.klusDetail('abc')), HhPaden.jongere);
      expect(guard(wacht, HhPadenKlussen.mijnKlussen), isNull);
      expect(guard(wacht, HhPadenKlussen.profiel), isNull);
      expect(guard(wacht, HhPadenKlussen.instellingen), isNull);
    });

    test('alles rond: overal welkom', () {
      final klaar = met(HhScreeningStatus.goedgekeurd);
      for (final pad in [
        HhPaden.jongere,
        HhPadenKlussen.mijnKlussen,
        HhPadenKlussen.klusDetail('abc'),
      ]) {
        expect(guard(klaar, pad), isNull, reason: pad);
      }
    });

    test('op een aanmeldpad blijft de strijder altijd', () {
      for (final status in HhScreeningStatus.values) {
        for (final pad in [
          HhPadenJongere.overzicht,
          HhPadenJongere.identiteit,
          HhPadenJongere.binnen,
        ]) {
          expect(guard(met(status), pad), isNull, reason: '$pad $status');
        }
      }
    });

    test('laden of fout: geen redirect (de landing toont de staat)', () {
      expect(guard(const AsyncLoading(), HhPaden.jongere), isNull);
      expect(
        guard(
          const AsyncError(
            HhFout(HhFoutSoort.geenVerbinding),
            StackTrace.empty,
          ),
          HhPadenKlussen.klusDetail('abc'),
        ),
        isNull,
      );
    });

    test('andere paden van de strijder raakt de guard niet', () {
      expect(guard(met(HhScreeningStatus.nieuw), HhPaden.instellingen), isNull);
      expect(guard(met(HhScreeningStatus.nieuw), HhPaden.hulp), isNull);
    });

    test(
      'een andere rol op een aanmeld- of klussenpad gaat naar zijn rolroute',
      () {
        for (final rol in HhRol.values.where((r) => r != HhRol.jongere)) {
          final sessie = SessieIngelogd(testGebruiker(rol));
          for (final pad in [
            HhPadenJongere.overzicht,
            HhPadenKlussen.klusDetail('abc'),
          ]) {
            expect(
              screeningRedirect(
                sessie,
                const AsyncData(ScreeningGegevens()),
                pad,
                klok: klok,
              ),
              rol.pad,
              reason: '${rol.code} $pad',
            );
          }
          expect(
            screeningRedirect(
              sessie,
              const AsyncData(ScreeningGegevens()),
              rol.pad,
              klok: klok,
            ),
            isNull,
          );
        }
      },
    );
  });
}

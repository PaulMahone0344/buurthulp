import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/features/coordinator/coordinator_guard.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';

import '../../../support/hh_toegang_wikkel.dart';

void main() {
  final coordinator = SessieIngelogd(testGebruiker(HhRol.coordinator));
  final jongere = SessieIngelogd(testGebruiker(HhRol.jongere));

  final coordinatorPaden = [
    HhPadenCoordinator.klussen,
    HhPadenCoordinator.instellingen,
    HhPadenCoordinator.incidentDetail('i-nood'),
    HhPadenCoordinator.klusDetail('k-open-oud'),
  ];

  test('de coordinator mag op elk coordinatorpad blijven', () {
    for (final pad in coordinatorPaden) {
      expect(coordinatorRedirect(coordinator, pad), isNull, reason: pad);
    }
  });

  test('een andere rol wordt van elk coordinatorpad geweerd', () {
    for (final pad in coordinatorPaden) {
      expect(coordinatorRedirect(jongere, pad), HhPaden.jongere, reason: pad);
    }
  });

  test('elke rol houdt zijn eigen landing als doel', () {
    for (final rol in HhRol.values) {
      if (rol == HhRol.coordinator) continue;
      expect(
        coordinatorRedirect(
          SessieIngelogd(testGebruiker(rol)),
          HhPadenCoordinator.klussen,
        ),
        rol.pad,
      );
    }
  });

  test('zegt niets over paden buiten M10', () {
    for (final pad in [
      HhPaden.coordinator,
      HhPaden.jongere,
      HhPaden.instellingen,
      HhPaden.welkom,
    ]) {
      expect(coordinatorRedirect(jongere, pad), isNull, reason: pad);
    }
  });

  test('zegt niets zolang er geen sessie is', () {
    for (final sessie in [
      const SessieOnbekend(),
      const SessieBezig(),
      const SessieUitgelogd(),
    ]) {
      expect(coordinatorRedirect(sessie, HhPadenCoordinator.klussen), isNull);
    }
  });

  group('isCoordinatorPad', () {
    test('herkent de paden onder de landing', () {
      for (final pad in coordinatorPaden) {
        expect(HhPadenCoordinator.isCoordinatorPad(pad), isTrue, reason: pad);
      }
    });

    test('de landing zelf hoort bij de bestaande rol-guard', () {
      expect(HhPadenCoordinator.isCoordinatorPad(HhPaden.coordinator), isFalse);
    });

    test('herkent geen paden van een andere rol', () {
      expect(HhPadenCoordinator.isCoordinatorPad(HhPaden.jongere), isFalse);
      expect(HhPadenCoordinator.isCoordinatorPad('/jongere/klus/k1'), isFalse);
    });
  });
}

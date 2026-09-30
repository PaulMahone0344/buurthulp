import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/beoordelen/paden_beoordelen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/model/screening_stap.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/paden_reputatie.dart';
import 'package:heitjehulp_app/features/jongere/screening_guard.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';

import '../../../../support/hh_toegang_wikkel.dart';

void main() {
  AsyncValue<ScreeningGegevens> met(HhScreeningStatus status) => AsyncData(
    ScreeningGegevens(
      profiel: HhProfiel(id: 'p', gebruikerId: 'j', verificatiestatus: status),
    ),
  );

  final j17 = HhPadenReputatie.beoordelen('k1');

  test('J17 hangt onder het klusdetail, O9 onder O7', () {
    expect(j17, '/jongere/klus/k1/beoordelen');
    expect(
      HhPadenBeoordelen.beoordelen('k1'),
      '/hulpvrager/hulpvragen/k1/beoordelen',
    );
  });

  test('de screening-guard dekt J17 vanzelf', () {
    expect(HhPadenKlussen.isKlussenPad(j17), isTrue);
    final jongere = SessieIngelogd(testGebruiker(HhRol.jongere));
    expect(
      screeningRedirect(jongere, met(HhScreeningStatus.inBehandeling), j17),
      HhPadenJongere.overzicht,
    );
    expect(
      screeningRedirect(jongere, met(HhScreeningStatus.goedgekeurd), j17),
      isNull,
    );
    // Een andere rol op J17 gaat naar zijn eigen landing.
    final oudere = SessieIngelogd(testGebruiker(HhRol.hulpvrager));
    expect(
      screeningRedirect(oudere, met(HhScreeningStatus.goedgekeurd), j17),
      HhRol.hulpvrager.pad,
    );
  });
}

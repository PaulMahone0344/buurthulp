// B9 — schermsweep van Profiel (met XP, badges, vertrouwen, verdiensten),
// "Mijn verdiensten" en de Verklaring van inzet op 320/390/430 bij 100 en
// 200%, plus HBeloning (die alleen met een beloning als extra opent) apart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_xp_gateway.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/features/jongere/xp/screen/beloning_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/xp/model/hh_xp.dart';
import 'package:heitjehulp_app/features/jongere/xp/paden_xp.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/theme.dart';

import '../support/hh_beoordelen_wikkel.dart';
import '../support/hh_uitvoeren_wikkel.dart';
import '../support/hh_xp_data.dart';
import 'sweep_steun.dart';

void main() {
  testWidgets('B9-schermen passen op 320/390/430 bij 100 en 200%', (
    tester,
  ) async {
    final bevindingen = await sweep(
      tester,
      rol: HhRol.jongere,
      paden: [
        HhPaden.jongere,
        HhPadenKlussen.profiel,
        HhPadenXp.verdiensten,
        HhPadenXp.verklaring,
      ],
      data: SweepData(
        xp: () => FakeXpGateway(
          overzicht: testXpOverzicht(verlopenVog: true),
          verklaring: HhVerklaring.vanJson(testVerklaringJson),
        ),
      ),
    );
    for (final b in bevindingen) {
      // ignore: avoid_print
      print(b);
    }
    expect(bevindingen, isEmpty, reason: '${bevindingen.length} layoutfouten');
  });

  testWidgets('HBeloning past op 320 bij 200% (lange badge, nieuw niveau)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = fakeUitvoer(status: HhKlusStatus.bezig)
      ..beloningBijAfgerond = testBeloning;
    await tester.pumpWidget(
      hhReputatieWikkel(
        HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
        uitvoerGateway: fake,
        beoordelingGateway: fakeBeoordeling(),
        tekstschaal: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    final knop = find.text(TekstenUitvoerenNl.j15KnopAfgerond);
    await tester.ensureVisible(knop);
    await tester.tap(knop);
    await tester.pumpAndSettle();
    expect(find.byType(BeloningScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

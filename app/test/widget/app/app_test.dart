import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/app/screens/dev_screen.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/toegang/screen/welkom_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_toegang_wikkel.dart';

void main() {
  group('HeitjeHulpApp', () {
    testWidgets('start op de splash en komt zonder sessie op welkom', (
      tester,
    ) async {
      await pompApp(tester, gateway: fakeMetAlleRollen());

      expect(find.byType(WelkomScreen), findsOneWidget);
      expect(find.text(TekstenNl.welkomTitel), findsOneWidget);
    });

    testWidgets(
      '"Ik zoek hulp" houdt de gewone knophoogte (geen verschil per rol)',
      (tester) async {
        await pompApp(tester, gateway: fakeMetAlleRollen());

        final normaal = tester
            .getSize(find.widgetWithText(HhKnop, TekstenNl.alEenAccount))
            .height;
        expect(
          normaal,
          greaterThanOrEqualTo(HhMaten.knopHoogte(HhDichtheid.normaal)),
        );

        await tester.tap(find.widgetWithText(HhKnop, TekstenNl.keuzeZoekHulp));
        await tester.pumpAndSettle();

        final groot = tester
            .getSize(find.widgetWithText(HhKnop, TekstenNl.registrerenKnop))
            .height;
        expect(groot, lessThan(HhMaten.knopHoogte(HhDichtheid.groot)));
      },
    );

    testWidgets('/dev bestaat alleen in debug-builds', (tester) async {
      final container = await pompApp(tester, gateway: fakeMetAlleRollen());

      container.read(routerProvider).go(HhPaden.dev);
      await tester.pumpAndSettle();

      // Tests draaien in debug; daar bestaat de route.
      expect(
        find.byType(DevScreen),
        kDebugMode ? findsOneWidget : findsNothing,
      );
    });
  });
}

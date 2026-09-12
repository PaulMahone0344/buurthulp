import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/dichtheid_controller.dart';
import 'package:heitjehulp_app/app/screens/rolwissel_screen.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/theme.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: HeitjeHulpApp()));
  await tester.pumpAndSettle();
}

void main() {
  group('HeitjeHulpApp', () {
    testWidgets('start op het tijdelijke rolwisselscherm', (tester) async {
      await _pumpApp(tester);

      expect(find.byType(RolwisselScreen), findsOneWidget);
      expect(find.text('Rolwissel (tijdelijk)'), findsOneWidget);
    });

    for (final rol in ['Hulpvrager', 'Jongere', 'Familie', 'Coordinator']) {
      testWidgets('navigeert naar de stub van $rol en weer terug', (
        tester,
      ) async {
        await _pumpApp(tester);

        await tester.tap(find.widgetWithText(HhKnop, rol));
        await tester.pumpAndSettle();

        expect(find.byType(RolwisselScreen), findsNothing);
        expect(find.widgetWithText(AppBar, rol), findsOneWidget);
        expect(
          find.text('Dit deel van de app komt in een latere opdracht.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Terug naar rolwissel'));
        await tester.pumpAndSettle();

        expect(find.byType(RolwisselScreen), findsOneWidget);
      });
    }

    testWidgets('dichtheid groot maakt de knoppen 60 hoog', (tester) async {
      await _pumpApp(tester);

      final normaal = tester.getSize(find.widgetWithText(HhKnop, 'Jongere'));
      expect(
        normaal.height,
        greaterThanOrEqualTo(HhMaten.knopHoogte(HhDichtheid.normaal)),
      );

      await tester.tap(find.text('Groot'));
      await tester.pumpAndSettle();

      final groot = tester.getSize(find.widgetWithText(HhKnop, 'Jongere'));
      expect(
        groot.height,
        greaterThanOrEqualTo(HhMaten.knopHoogte(HhDichtheid.groot)),
      );
      expect(groot.height, greaterThan(normaal.height));
    });
  });

  group('DichtheidController', () {
    test('start op normaal en wisselt met zet()', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(dichtheidControllerProvider), HhDichtheid.normaal);
      container
          .read(dichtheidControllerProvider.notifier)
          .zet(HhDichtheid.groot);
      expect(container.read(dichtheidControllerProvider), HhDichtheid.groot);
    });
  });
}

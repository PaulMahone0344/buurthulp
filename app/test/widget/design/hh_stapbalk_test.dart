import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_stapbalk.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

void main() {
  group('HhStapbalk', () {
    testWidgets('toont "Stap 2 van 4" en de titel', (tester) async {
      await tester.pumpWidget(
        hhWikkel(const HhStapbalk(stap: 2, totaal: 4, titel: 'Wat voor hulp')),
      );

      expect(find.text('Stap 2 van 4'), findsOneWidget);
      expect(find.text('Wat voor hulp'), findsOneWidget);
    });

    testWidgets('tekent evenveel balken als stappen, gevuld tot de stap', (
      tester,
    ) async {
      await tester.pumpWidget(hhWikkel(const HhStapbalk(stap: 2, totaal: 4)));

      final balken = tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(HhStapbalk),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(balken.length, 4);
      final gevuld = balken.where((b) => b.color == HhKleuren.primair).length;
      expect(gevuld, 2);
    });

    testWidgets('semantiek: een zin, geen losse balken', (tester) async {
      await tester.pumpWidget(
        hhWikkel(const HhStapbalk(stap: 2, totaal: 4, titel: 'Wat voor hulp')),
      );

      final semantiek = tester.getSemantics(find.byType(HhStapbalk));
      expect(semantiek.label, 'Stap 2 van 4, Wat voor hulp');
    });

    testWidgets('wikkelt bij 200 procent tekst zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhStapbalk(
            stap: 3,
            totaal: 4,
            titel: 'Waar moet de jongere naartoe en wat moet hij weten',
          ),
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

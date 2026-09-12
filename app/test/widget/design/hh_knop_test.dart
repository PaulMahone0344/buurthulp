import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

void main() {
  group('HhKnop', () {
    testWidgets('rendert alle vier soorten', (tester) async {
      await tester.pumpWidget(
        hhWikkel(
          Column(
            children: [
              HhKnop(label: 'Primair', onPressed: () {}),
              HhKnop(
                label: 'Tweede',
                soort: HhKnopSoort.tweedeKeus,
                onPressed: () {},
              ),
              HhKnop(
                label: 'Tekst',
                soort: HhKnopSoort.tekst,
                onPressed: () {},
              ),
              HhKnop(
                label: 'Gevaar',
                soort: HhKnopSoort.gevaar,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      for (final label in ['Primair', 'Tweede', 'Tekst', 'Gevaar']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('reageert op een tik', (tester) async {
      var getikt = 0;
      await tester.pumpWidget(
        hhWikkel(HhKnop(label: 'Verder', onPressed: () => getikt++)),
      );

      await tester.tap(find.text('Verder'));

      expect(getikt, 1);
    });

    testWidgets('uitgeschakeld: geen tik-actie voor de schermlezer', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(const HhKnop(label: 'Verder', onPressed: null)),
      );

      final semantiek = tester.getSemantics(find.byType(HhKnop));
      expect(
        semantiek.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    });

    testWidgets('laadtoestand: spinner, geen tik, label zegt bezig', (
      tester,
    ) async {
      var getikt = 0;
      await tester.pumpWidget(
        hhWikkel(
          HhKnop(label: 'Versturen', isBezig: true, onPressed: () => getikt++),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(HhKnop), warnIfMissed: false);
      expect(getikt, 0);

      final semantiek = tester.getSemantics(find.byType(HhKnop));
      expect(semantiek.label, 'Versturen, bezig');
      expect(
        semantiek.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    });

    testWidgets('raakvlak is minstens 48 in normaal en 60 in groot', (
      tester,
    ) async {
      for (final dichtheid in HhDichtheid.values) {
        await tester.pumpWidget(
          hhWikkel(
            HhKnop(label: 'Verder', onPressed: () {}),
            dichtheid: dichtheid,
          ),
        );

        final hoogte = tester.getSize(find.byType(HhKnop)).height;
        expect(
          hoogte,
          greaterThanOrEqualTo(HhMaten.knopHoogte(dichtheid)),
          reason: 'dichtheid $dichtheid',
        );
      }
    });

    testWidgets('maat groot overrulet de dichtheid van de scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          HhKnop(label: 'Verder', maat: HhDichtheid.groot, onPressed: () {}),
        ),
      );

      final hoogte = tester.getSize(find.byType(HhKnop)).height;
      expect(
        hoogte,
        greaterThanOrEqualTo(HhMaten.knopHoogte(HhDichtheid.groot)),
      );
    });

    testWidgets('semantiek: knop met label', (tester) async {
      await tester.pumpWidget(
        hhWikkel(HhKnop(label: 'Verder', onPressed: () {})),
      );

      final semantiek = tester.getSemantics(find.byType(HhKnop));
      expect(semantiek.label, 'Verder');
      expect(semantiek.getSemanticsData().flagsCollection.isButton, isTrue);
    });

    testWidgets('wikkelt bij 200 procent tekst zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          HhKnop(
            label:
                'Een behoorlijk lang label dat moet wikkelen op een '
                'smal scherm',
            icoon: Icons.check,
            onPressed: () {},
          ),
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(HhKnop), findsOneWidget);
    });
  });
}

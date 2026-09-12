import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_lege_staat.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

void main() {
  group('HhLegeStaat', () {
    testWidgets('rendert icoon, titel en uitleg zonder knop', (tester) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhLegeStaat(
            icoon: Icons.inbox,
            titel: 'Nog geen hulpvragen',
            uitleg: 'Zodra u hulp vraagt, staat die hier.',
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('Nog geen hulpvragen'), findsOneWidget);
      expect(find.text('Zodra u hulp vraagt, staat die hier.'), findsOneWidget);
      expect(find.byType(HhKnop), findsNothing);
    });

    testWidgets('optionele knop reageert op tik', (tester) async {
      var getikt = 0;
      await tester.pumpWidget(
        hhWikkel(
          HhLegeStaat(
            icoon: Icons.inbox,
            titel: 'Nog geen hulpvragen',
            uitleg: 'Vraag nu hulp.',
            knopLabel: 'Hulp vragen',
            onKnop: () => getikt++,
          ),
        ),
      );

      await tester.tap(find.text('Hulp vragen'));
      expect(getikt, 1);
    });

    testWidgets('semantiek: titel en uitleg zijn hoorbaar, icoon niet', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhLegeStaat(
            icoon: Icons.inbox,
            titel: 'Nog geen hulpvragen',
            uitleg: 'Vraag nu hulp.',
          ),
        ),
      );

      // Een node voor de schermlezer: titel en uitleg samen.
      final label = tester.getSemantics(find.byType(HhLegeStaat)).label;
      expect(label, contains('Nog geen hulpvragen'));
      expect(label, contains('Vraag nu hulp.'));
      expect(
        find.ancestor(
          of: find.byIcon(Icons.inbox),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('wikkelt bij 200 procent tekst zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          HhLegeStaat(
            icoon: Icons.inbox,
            titel: 'Een lange titel die over meerdere regels loopt',
            uitleg:
                'Een uitleg van een paar zinnen. Die moet gewoon '
                'wikkelen en nooit kleiner worden gemaakt.',
            knopLabel: 'Een knop met een lang label',
            onKnop: () {},
          ),
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

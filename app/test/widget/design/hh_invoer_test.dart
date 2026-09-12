import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_invoer.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

void main() {
  group('HhInvoer', () {
    testWidgets('rendert label, hulptekst en neemt invoer aan', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        hhWikkel(
          HhInvoer(
            label: 'Straat',
            hulptekst: 'Met huisnummer',
            controller: controller,
          ),
        ),
      );

      expect(find.text('Straat'), findsOneWidget);
      expect(find.text('Met huisnummer'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Kerkstraat 14');
      expect(controller.text, 'Kerkstraat 14');
    });

    testWidgets('foutstaat toont de fouttekst', (tester) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhInvoer(label: 'Telefoon', fouttekst: 'Nummer is te kort.'),
        ),
      );

      expect(find.text('Nummer is te kort.'), findsOneWidget);
    });

    testWidgets('verplicht: sterretje zichtbaar, schermlezer hoort verplicht', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(const HhInvoer(label: 'Naam', isVerplicht: true)),
      );

      // Zichtbaar staat er een sterretje; voor de schermlezer het woord.
      final label = tester.widget<Text>(find.byType(Text).first);
      expect(
        label.textSpan!.toPlainText(includeSemanticsLabels: false),
        'Naam *',
      );
      final semantiek = tester.getSemantics(find.byType(HhInvoer));
      expect(semantiek.label, contains('Naam'));
      expect(semantiek.label, contains(HhInvoer.verplichtWoord));
    });

    testWidgets('uitgeschakeld: veld neemt geen invoer aan', (tester) async {
      await tester.pumpWidget(
        hhWikkel(const HhInvoer(label: 'Naam', isActief: false)),
      );

      final veld = tester.widget<TextField>(find.byType(TextField));
      expect(veld.enabled, isFalse);
      final semantiek = tester.getSemantics(find.byType(HhInvoer));
      expect(
        semantiek.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );
    });

    testWidgets('raakvlak is minstens de knophoogte per dichtheid', (
      tester,
    ) async {
      for (final dichtheid in HhDichtheid.values) {
        await tester.pumpWidget(
          hhWikkel(const HhInvoer(label: 'Naam'), dichtheid: dichtheid),
        );

        final hoogte = tester.getSize(find.byType(TextField)).height;
        expect(
          hoogte,
          greaterThanOrEqualTo(HhMaten.knopHoogte(dichtheid)),
          reason: 'dichtheid $dichtheid',
        );
      }
    });

    testWidgets('wikkelt bij 200 procent tekst zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhInvoer(
            label: 'Een lang label dat over meerdere regels moet kunnen',
            hulptekst:
                'Een lange hulptekst die uitlegt wat er in dit veld '
                'hoort te staan en waarom.',
            fouttekst:
                'Een lange foutmelding die de gebruiker precies '
                'vertelt wat er mis is.',
            isVerplicht: true,
          ),
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

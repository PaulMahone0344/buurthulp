import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_keuzerij.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

const _keuzes = [
  HhKeuze(
    waarde: 'boodschappen',
    label: 'Boodschappen',
    icoon: Icons.shopping_bag,
  ),
  HhKeuze(waarde: 'tuin', label: 'Tuin', icoon: Icons.yard),
  HhKeuze(waarde: 'telefoon', label: 'Telefoon', icoon: Icons.phone_android),
];

void main() {
  group('HhKeuzerij', () {
    testWidgets('rendert alle keuzes', (tester) async {
      await tester.pumpWidget(
        hhWikkel(
          HhKeuzerij<String>(
            keuzes: _keuzes,
            geselecteerd: const {},
            onGewijzigd: (_) {},
          ),
        ),
      );

      for (final keuze in _keuzes) {
        expect(find.text(keuze.label), findsOneWidget);
      }
    });

    testWidgets('een keuze: tik vervangt de selectie', (tester) async {
      Set<String>? uitkomst;
      await tester.pumpWidget(
        hhWikkel(
          HhKeuzerij<String>(
            keuzes: _keuzes,
            geselecteerd: const {'tuin'},
            onGewijzigd: (nieuw) => uitkomst = nieuw,
          ),
        ),
      );

      await tester.tap(find.text('Telefoon'));

      expect(uitkomst, {'telefoon'});
    });

    testWidgets('meerdere: tik voegt toe en haalt weer weg', (tester) async {
      Set<String>? uitkomst;
      const start = {'tuin'};
      await tester.pumpWidget(
        hhWikkel(
          HhKeuzerij<String>(
            keuzes: _keuzes,
            geselecteerd: start,
            meerdere: true,
            onGewijzigd: (nieuw) => uitkomst = nieuw,
          ),
        ),
      );

      await tester.tap(find.text('Telefoon'));
      expect(uitkomst, {'tuin', 'telefoon'});

      await tester.tap(find.text('Tuin'));
      expect(uitkomst, isEmpty);
      // De oorspronkelijke set is niet aangeraakt.
      expect(start, {'tuin'});
    });

    testWidgets('uitgeschakeld: geen tik-actie', (tester) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhKeuzerij<String>(
            keuzes: _keuzes,
            geselecteerd: {},
            onGewijzigd: null,
          ),
        ),
      );

      await tester.tap(find.text('Tuin'));
      final semantiek = tester.getSemantics(find.text('Tuin'));
      expect(
        semantiek.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    });

    testWidgets('semantiek: rijlabel en gekozen-vlag', (tester) async {
      await tester.pumpWidget(
        hhWikkel(
          HhKeuzerij<String>(
            semantiekLabel: 'Soort klus',
            keuzes: _keuzes,
            geselecteerd: const {'tuin'},
            onGewijzigd: (_) {},
          ),
        ),
      );

      final rij = tester.getSemantics(find.byType(HhKeuzerij<String>));
      expect(rij.label, 'Soort klus');

      final tuin = tester.getSemantics(find.text('Tuin'));
      expect(
        tuin.getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      final telefoon = tester.getSemantics(find.text('Telefoon'));
      expect(
        telefoon.getSemanticsData().flagsCollection.isChecked,
        CheckedState.isFalse,
      );
    });

    testWidgets('elke keuze is minstens de knophoogte per dichtheid', (
      tester,
    ) async {
      for (final dichtheid in HhDichtheid.values) {
        await tester.pumpWidget(
          hhWikkel(
            HhKeuzerij<String>(
              keuzes: _keuzes,
              geselecteerd: const {},
              onGewijzigd: (_) {},
            ),
            dichtheid: dichtheid,
          ),
        );

        final hoogte = tester.getSize(find.byType(HhKeuzerij<String>)).height;
        expect(hoogte, greaterThanOrEqualTo(HhMaten.knopHoogte(dichtheid)));
      }
    });

    testWidgets('wikkelt bij 200 procent tekst zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          HhKeuzerij<String>(
            keuzes: _keuzes,
            geselecteerd: const {'tuin'},
            onGewijzigd: (_) {},
          ),
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

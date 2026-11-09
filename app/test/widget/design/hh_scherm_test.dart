import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

Widget _wikkel(Widget scherm, {HhDichtheid dichtheid = HhDichtheid.normaal}) {
  return MaterialApp(
    theme: hhThema(dichtheid),
    builder: (context, kind) =>
        HhDichtheidScope(dichtheid: dichtheid, child: kind!),
    home: scherm,
  );
}

void main() {
  group('HhScherm', () {
    testWidgets('toont titel en inhoud, zonder terugknop op een wortel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wikkel(const HhScherm(titel: 'Kop', child: Text('Inhoud'))),
      );

      expect(find.text('Kop'), findsOneWidget);
      expect(find.text('Inhoud'), findsOneWidget);
      expect(find.byType(HhTerugKnop), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('met onTerug: terugknop altijd zichtbaar en werkend', (
      tester,
    ) async {
      var terug = 0;
      await tester.pumpWidget(
        _wikkel(
          HhScherm(
            titel: 'Kop',
            onTerug: () => terug++,
            child: const Text('Inhoud'),
          ),
        ),
      );

      expect(find.byType(HhTerugKnop), findsOneWidget);
      await tester.tap(find.text(TekstenNl.terug));
      expect(terug, 1);

      final semantiek = tester.getSemantics(find.byType(HhTerugKnop));
      expect(semantiek.label, TekstenNl.terug);
      expect(semantiek.getSemanticsData().flagsCollection.isButton, isTrue);
    });

    testWidgets('toonTerug false verbergt de knop ook met onTerug', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wikkel(
          HhScherm(
            titel: 'Kop',
            onTerug: () {},
            toonTerug: false,
            child: const Text('Inhoud'),
          ),
        ),
      );

      expect(find.byType(HhTerugKnop), findsNothing);
    });

    testWidgets('terugknop is minstens 48 hoog in normaal en 60 in groot', (
      tester,
    ) async {
      for (final dichtheid in HhDichtheid.values) {
        await tester.pumpWidget(
          _wikkel(
            HhScherm(titel: 'Kop', onTerug: () {}, child: const Text('x')),
            dichtheid: dichtheid,
          ),
        );
        final hoogte = tester.getSize(find.byType(HhTerugKnop)).height;
        expect(
          hoogte,
          greaterThanOrEqualTo(HhMaten.knopHoogte(dichtheid)),
          reason: '$dichtheid',
        );
      }
    });

    testWidgets('niet-scrollbaar geeft het kind de resthoogte', (tester) async {
      await tester.pumpWidget(
        _wikkel(
          HhScherm(
            titel: 'Kop',
            scrollbaar: false,
            child: ListView(children: const [Text('Rij')]),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Rij'), findsOneWidget);
    });

    testWidgets('lange titel bij 200 procent wikkelt zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: hhThema(HhDichtheid.groot),
          builder: (context, kind) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(hhMaxTekstschaal)),
            child: HhDichtheidScope(dichtheid: HhDichtheid.groot, child: kind!),
          ),
          home: HhScherm(
            titel: 'Een behoorlijk lange titel die over meerdere regels gaat',
            onTerug: () {},
            child: const Text('Inhoud'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('een knop uit HhKopActie staat in de groene bovenbalk', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          const SizedBox(
            height: 400,
            child: HhKopActie(
              // Zo breed als het echte belletje: de knophoogte.
              actie: SizedBox.square(
                dimension: 48,
                child: Icon(Icons.notifications_none_outlined),
              ),
              child: HhScherm(
                titel: 'Start',
                toonTerug: false,
                child: Text('inhoud'),
              ),
            ),
          ),
        ),
      );

      final inBalk = find.descendant(
        of: find.byType(HhBovenbalk),
        matching: find.byIcon(Icons.notifications_none_outlined),
      );
      expect(inBalk, findsOneWidget);
      // De titel blijft in het midden van de balk staan.
      final balk = tester.getRect(find.byType(HhBovenbalk));
      expect(tester.getCenter(find.text('Start')).dx, balk.center.dx);
    });

    testWidgets('zonder HhKopActie staat er niets extra in de bovenbalk', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          const SizedBox(
            height: 400,
            child: HhScherm(
              titel: 'Start',
              toonTerug: false,
              child: Text('inhoud'),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(HhBovenbalk),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });
  });
}

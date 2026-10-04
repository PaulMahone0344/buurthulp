// B10: de Start van de helper (mockup StartHelper) en van de bewoner
// (mockup Main), en de tabbalken op HhTabbalk.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_xp_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_tabbalk.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_home_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/klussen_home_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/klus_tegel.dart';
import 'package:heitjehulp_app/features/jongere/start/helper_niveau_kaart.dart';
import 'package:heitjehulp_app/features/jongere/start/helper_start_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/widget/hulpvraag_tegel.dart';
import 'package:heitjehulp_app/l10n/teksten_start_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_xp_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_hulpvrager_wikkel.dart';
import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_klussen_wikkel.dart';
import '../../../support/hh_uitvoeren_wikkel.dart';
import '../../../support/hh_xp_data.dart';

Future<void> _scrollNaar(WidgetTester tester, Finder doel) async {
  await tester.scrollUntilVisible(
    doel,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _helperStart(
  WidgetTester tester, {
  FakeXpGateway? xp,
  bool metEigenKlus = true,
  bool leeg = false,
}) async {
  await tester.pumpWidget(
    hhKlussenWikkel(
      HhPaden.jongere,
      klussenGateway: fakeKlussen(
        open: leeg ? const [] : null,
        mijn: metEigenKlus
            ? [
                testKlus(
                  id: 'eigen',
                  status: HhKlusStatus.geaccepteerd,
                  toegewezenJongereId: jongereId,
                  omschrijving: 'Lamp ophangen',
                ),
              ]
            : const [],
      ),
      xpGateway: xp ?? FakeXpGateway(overzicht: testXpOverzicht()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Start helper (StartHelper)', () {
    testWidgets('hoi, niveau met volgende, XP-balk en badges', (tester) async {
      await _helperStart(tester);
      expect(find.byType(HelperStartScreen), findsOneWidget);
      expect(find.text(TekstenStartNl.niveauKop), findsOneWidget);
      expect(find.text('Ervaren'), findsOneWidget);
      expect(find.text(TekstenStartNl.volgende('Top')), findsOneWidget);
      expect(
        find.bySemanticsLabel(TekstenXpNl.balkSemantiek(605, 1000, 'Top')),
        findsOneWidget,
      );
      // De drie behaalde badges als rondjes.
      expect(find.bySemanticsLabel('Eerste klus'), findsOneWidget);
      expect(find.bySemanticsLabel('Weer gevraagd'), findsOneWidget);
    });

    testWidgets('volgende eigen klus, drie klussen in de buurt, verdiensten', (
      tester,
    ) async {
      await _helperStart(tester);
      expect(find.text(TekstenStartNl.volgendeKlusKop), findsOneWidget);
      await _scrollNaar(tester, find.text(TekstenStartNl.inDeBuurtKop));
      // 1 eigen + hooguit 3 in de buurt.
      expect(find.byType(KlusTegel, skipOffstage: false), findsNWidgets(4));
      await _scrollNaar(tester, find.text(TekstenXpNl.dezeMaand));
      expect(find.text('€ 37,50'), findsOneWidget);
    });

    testWidgets('"Alle" gaat naar de tab Klussen', (tester) async {
      await _helperStart(tester);
      await _scrollNaar(tester, find.text(TekstenStartNl.alle));
      await tester.tap(find.text(TekstenStartNl.alle));
      await tester.pumpAndSettle();
      expect(find.byType(KlussenHomeScreen), findsOneWidget);
    });

    testWidgets(
      'lege buurt en geen eigen klus: rustige zin, geen volgende-klus-kaart',
      (tester) async {
        await _helperStart(tester, leeg: true, metEigenKlus: false);
        expect(find.text(TekstenStartNl.volgendeKlusKop), findsNothing);
        await _scrollNaar(tester, find.text(TekstenStartNl.geenInDeBuurt));
        expect(find.text(TekstenStartNl.geenInDeBuurt), findsOneWidget);
      },
    );

    testWidgets('XP niet te laden: Start werkt verder zonder niveau-kaart', (
      tester,
    ) async {
      await _helperStart(tester, xp: FakeXpGateway()..isOffline = true);
      expect(find.byType(HelperNiveauKaart), findsNothing);
      expect(find.text(TekstenStartNl.volgendeKlusKop), findsOneWidget);
    });

    testWidgets('tabbalk: vier tabs op HhTabbalk, Start actief', (
      tester,
    ) async {
      await _helperStart(tester);
      final balk = find.byType(HhTabbalk);
      expect(balk, findsOneWidget);
      for (final t in ['Start', 'Klussen', 'Mijn klussen', 'Profiel']) {
        expect(
          find.descendant(of: balk, matching: find.text(t)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: balk, matching: find.text('Instellingen')),
        findsNothing,
      );
    });
  });

  group('Start bewoner (Main)', () {
    // Testklok di 15 sep 2026 10:00: week ma 14 t/m zo 20 september.
    final hulpvragen = [
      uitvoerKlus(
        id: 'vandaag',
        status: HhKlusStatus.geaccepteerd,
        wanneerVan: DateTime(2026, 9, 15, 16),
      ),
      uitvoerKlus(
        id: 'zondag',
        status: HhKlusStatus.open,
        metJongere: false,
        wanneerVan: DateTime(2026, 9, 20, 11),
      ).copyWith(reactiesAantal: 3),
      uitvoerKlus(
        id: 'later',
        status: HhKlusStatus.open,
        metJongere: false,
        wanneerVan: DateTime(2026, 9, 28, 11),
      ),
      uitvoerKlus(
        id: 'klaar',
        status: HhKlusStatus.afgerond,
        wanneerVan: DateTime(2026, 9, 10, 11),
      ),
    ];

    Future<void> pomp(WidgetTester tester) async {
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpvragerHomeScreen(),
          klusGateway: fakeKlusGateway(),
          uitvoerGateway: fakeUitvoer(klussen: hulpvragen, ikBen: oudereId),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tegels: aankomend en nieuwe reacties', (tester) async {
      await pomp(tester);
      expect(
        find.bySemanticsLabel(TekstenStartNl.aankomendSemantiek(3)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(TekstenStartNl.reactiesSemantiek(3)),
        findsOneWidget,
      );
    });

    testWidgets(
      'weekstrook ma-zo; week toont deze week, maand meer, dag de gekozen dag',
      (tester) async {
        await pomp(tester);
        await _scrollNaar(tester, find.text(TekstenStartNl.aankomendKop));
        expect(
          find.bySemanticsLabel(TekstenStartNl.dagSemantiek('di 15', 1)),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(TekstenStartNl.dagSemantiek('za 19', 0)),
          findsOneWidget,
        );
        // Week (standaard): vandaag + zondag.
        expect(find.byType(HulpvraagTegel), findsNWidgets(2));
        await tester.tap(find.text(TekstenStartNl.maand));
        await tester.pumpAndSettle();
        expect(find.byType(HulpvraagTegel), findsNWidgets(3));
        final zondag = find.bySemanticsLabel(
          TekstenStartNl.dagSemantiek('zo 20', 1),
        );
        await tester.ensureVisible(zondag);
        await tester.tap(zondag);
        await tester.pumpAndSettle();
        expect(find.byType(HulpvraagTegel), findsOneWidget);
        final zaterdag = find.bySemanticsLabel(
          TekstenStartNl.dagSemantiek('za 19', 0),
        );
        await tester.tap(zaterdag);
        await tester.pumpAndSettle();
        expect(find.text(TekstenStartNl.geenAankomend), findsOneWidget);
      },
    );

    testWidgets('op 200 procent en 320 breed geen overloop', (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpvragerHomeScreen(),
          klusGateway: fakeKlusGateway(),
          uitvoerGateway: fakeUitvoer(klussen: hulpvragen, ikBen: oudereId),
          tekstschaal: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

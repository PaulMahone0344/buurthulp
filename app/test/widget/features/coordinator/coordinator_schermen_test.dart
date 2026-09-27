import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_coordinator_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_lege_staat.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_incidenten_screen.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_klussen_screen.dart';
import 'package:heitjehulp_app/features/coordinator/widget/coordinator_tabbalk.dart';
import 'package:heitjehulp_app/features/coordinator/widget/incident_tegel.dart';
import 'package:heitjehulp_app/features/coordinator/widget/kandidaat_lijst.dart';
import 'package:heitjehulp_app/features/coordinator/widget/vrijgeef_blok.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_coordinator_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_coordinator_wikkel.dart';
import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_wikkel.dart';

/// Elk M10-scherm in de staat die het nodig heeft.
class _Geval {
  const _Geval(this.naam, this.pad, this.fake);

  final String naam;
  final String pad;
  final FakeCoordinatorGateway Function() fake;
}

final _gevallen = [
  const _Geval('C1 meldingen', HhPaden.coordinator, fakeCoordinator),
  _Geval(
    'C1 leeg',
    HhPaden.coordinator,
    () => fakeCoordinator(incidenten: const []),
  ),
  _Geval(
    'C1 laadfout',
    HhPaden.coordinator,
    () => fakeCoordinator()..isOffline = true,
  ),
  _Geval(
    'C1 detail noodmelding',
    HhPadenCoordinator.incidentDetail('i-nood'),
    fakeCoordinator,
  ),
  _Geval(
    'C1 detail met klus',
    HhPadenCoordinator.incidentDetail('i-probleem'),
    fakeCoordinator,
  ),
  const _Geval('C2 open klussen', HhPadenCoordinator.klussen, fakeCoordinator),
  _Geval(
    'C2 leeg',
    HhPadenCoordinator.klussen,
    () => fakeCoordinator(klussen: const []),
  ),
  _Geval(
    'C2 detail open klus',
    HhPadenCoordinator.klusDetail('k-open-oud'),
    fakeCoordinator,
  ),
  _Geval(
    'C2 detail toegewezen klus',
    HhPadenCoordinator.klusDetail('k-toegewezen'),
    fakeCoordinator,
  ),
  const _Geval(
    'tab instellingen (G7)',
    HhPadenCoordinator.instellingen,
    fakeCoordinator,
  ),
];

Future<FakeCoordinatorGateway> _pomp(
  WidgetTester tester,
  _Geval geval, {
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) async {
  final fake = geval.fake();
  await tester.pumpWidget(
    hhCoordinatorWikkel(
      geval.pad,
      gateway: fake,
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('elk scherm rendert in beide dichtheden met semantiek', () {
    for (final geval in _gevallen) {
      for (final dichtheid in HhDichtheid.values) {
        testWidgets('${geval.naam} in $dichtheid', (tester) async {
          await _pomp(tester, geval, dichtheid: dichtheid);

          expect(tester.takeException(), isNull);
          expect(find.byType(Scaffold), findsWidgets);
          controleerSemantiek(tester);
        });
      }

      testWidgets(
        '${geval.naam} 200 procent op een smal scherm zonder overloop',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await _pomp(tester, geval, tekstschaal: hhMaxTekstschaal);

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('C1 lijst', () {
    testWidgets('toont de open meldingen, nieuwste bovenaan', (tester) async {
      await _pomp(tester, _gevallen[0]);

      final tegels = tester.widgetList<IncidentTegel>(
        find.byType(IncidentTegel),
      );
      expect([for (final t in tegels) t.incident.id], [
        'i-nood',
        'i-probleem',
      ]);
    });

    testWidgets('de afgehandelde melding staat achter de filter', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[0]);
      expect(find.text('Sanne Bakker'), findsNothing);

      await tikTekst(tester, TekstenCoordinatorNl.c1FilterAfgehandeld);

      expect(find.byType(IncidentTegel), findsOneWidget);
      expect(find.text('Sanne Bakker'), findsOneWidget);
    });

    testWidgets('lege lijst toont de lege staat, niet nul meldingen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);

      expect(find.byType(HhLegeStaat), findsOneWidget);
      expect(find.text(TekstenCoordinatorNl.c1LegeOpenTitel), findsOneWidget);
    });

    testWidgets('een tik opent het detail', (tester) async {
      await _pomp(tester, _gevallen[0]);

      await tikTekst(tester, TekstenCoordinatorNl.soortNood);

      expect(find.text('Gevallen in de gang, kan niet opstaan.'), findsOneWidget);
      expect(find.text(TekstenCoordinatorNl.c1Afhandelen), findsOneWidget);
    });
  });

  group('C1 detail', () {
    testWidgets('een lege afhandeling wordt geweigerd', (tester) async {
      final fake = await _pomp(tester, _gevallen[3]);

      await tikKnop(tester, TekstenCoordinatorNl.c1Afhandelen);

      expect(find.text(TekstenCoordinatorNl.c1AfhandelingLeeg), findsOneWidget);
      expect(fake.alleIncidenten.firstWhere((i) => i.id == 'i-nood').isAfgehandeld, isFalse);
    });

    testWidgets('afhandelen zet de tekst en meldt dat het gelukt is', (
      tester,
    ) async {
      final fake = await _pomp(tester, _gevallen[3]);

      await vulVeld(tester, 0, 'Ambulance gebeld, dochter op de hoogte.');
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenCoordinatorNl.c1Afhandelen);

      expect(find.text(TekstenCoordinatorNl.c1Afgehandeld), findsOneWidget);
      final incident = fake.alleIncidenten.firstWhere((i) => i.id == 'i-nood');
      expect(incident.afhandeling, 'Ambulance gebeld, dochter op de hoogte.');
    });

    testWidgets('een melding zonder klus zegt dat het de noodknop was', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[3]);

      expect(find.text(TekstenCoordinatorNl.c1GeenKlus), findsOneWidget);
    });

    testWidgets('bij een klus staat de knop naar die klus', (tester) async {
      await _pomp(tester, _gevallen[4]);

      expect(find.text(TekstenCoordinatorNl.c1NaarKlus), findsOneWidget);
    });

    testWidgets('bellen dat niet lukt geeft het nummer in beeld', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhCoordinatorWikkel(
          HhPadenCoordinator.incidentDetail('i-nood'),
          gateway: fakeCoordinator(),
          urlOpenerLukt: false,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenCoordinatorNl.c1Bellen);

      expect(
        find.text(TekstenCoordinatorNl.c1BellenLuktNiet('0344-100001')),
        findsOneWidget,
      );
    });
  });

  group('C2 lijst', () {
    testWidgets('toont de open klussen, oudste eerst', (tester) async {
      await _pomp(tester, _gevallen[5]);

      final namen = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      // De klus van drie dagen oud staat boven die van vier uur oud.
      expect(
        namen.indexOf('Mevrouw A. de Vries'),
        lessThan(namen.indexOf('Meneer B. Jansen')),
      );
    });

    testWidgets('toont hoe lang een klus al open staat', (tester) async {
      await _pomp(tester, _gevallen[5]);

      expect(
        find.text(TekstenCoordinatorNl.c2OpenSinds('3 dagen')),
        findsOneWidget,
      );
      expect(
        find.text(TekstenCoordinatorNl.c2OpenSinds('4 uur')),
        findsOneWidget,
      );
    });

    testWidgets('een toegewezen klus staat niet in de lijst', (tester) async {
      await _pomp(tester, _gevallen[5]);

      expect(find.text('Yusuf el Amrani'), findsNothing);
    });
  });

  group('C2 detail', () {
    testWidgets('een open klus toont de koppellijst, eigen wijk eerst', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[7]);

      expect(find.byType(KandidaatLijst), findsOneWidget);
      expect(find.byType(VrijgeefBlok), findsNothing);
      final namen = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(
        namen.indexOf('Sanne Bakker'),
        lessThan(namen.indexOf('Daan Verhoeven')),
      );
    });

    testWidgets('de jongere uit een andere wijk is als zodanig gemerkt', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[7]);

      expect(
        find.text(TekstenCoordinatorNl.c2AndereWijkKort),
        findsOneWidget,
      );
    });

    testWidgets('het zoekveld filtert de lijst', (tester) async {
      await _pomp(tester, _gevallen[7]);

      await vulVeld(tester, 0, 'daan');
      await tester.pumpAndSettle();

      expect(find.text('Daan Verhoeven'), findsOneWidget);
      expect(find.text('Sanne Bakker'), findsNothing);
    });

    testWidgets('een toegewezen klus toont vrijgeven, niet koppelen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[8]);

      expect(find.byType(VrijgeefBlok), findsOneWidget);
      expect(find.byType(KandidaatLijst), findsNothing);
      expect(find.text('Yusuf el Amrani'), findsWidgets);
    });

    testWidgets('vrijgeven zonder reden wordt geweigerd', (tester) async {
      final fake = await _pomp(tester, _gevallen[8]);

      await tikKnop(tester, TekstenCoordinatorNl.c2Vrijgeven);

      expect(
        find.text(TekstenCoordinatorNl.c2VrijgevenRedenLeeg),
        findsOneWidget,
      );
      expect(fake.vrijgegevenIds, isEmpty);
    });
  });

  group('tabbalk', () {
    testWidgets('drie tabbladen, de actieve is geselecteerd voor de lezer', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[0]);
      final balk = find.byType(CoordinatorTabbalk);
      expect(balk, findsOneWidget);
      for (final tab in CoordinatorTab.values) {
        expect(
          find.descendant(of: balk, matching: find.text(tab.label)),
          findsOneWidget,
        );
      }
      final actief = tester.getSemantics(
        find.descendant(
          of: balk,
          matching: find.bySemanticsLabel(
            TekstenCoordinatorNl.tabIncidentenSemantiek(2),
          ),
        ),
      );
      expect(
        actief.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      final ander = tester.getSemantics(
        find.descendant(
          of: balk,
          matching: find.bySemanticsLabel(TekstenCoordinatorNl.tabKlussen),
        ),
      );
      expect(
        ander.getSemanticsData().flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );
    });

    testWidgets('de teller telt alleen de open meldingen', (tester) async {
      await _pomp(tester, _gevallen[0]);

      expect(
        find.text(TekstenCoordinatorNl.tabIncidentenTeller(2)),
        findsOneWidget,
      );
    });

    testWidgets('zonder open meldingen geen teller: geen nul in beeld', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);

      expect(
        find.text(TekstenCoordinatorNl.tabIncidentenTeller(0)),
        findsNothing,
      );
    });

    testWidgets('tik op een tab wisselt van scherm', (tester) async {
      await _pomp(tester, _gevallen[0]);
      expect(find.byType(CoordinatorIncidentenScreen), findsOneWidget);

      await tikTekst(tester, TekstenCoordinatorNl.tabKlussen);
      expect(find.byType(CoordinatorKlussenScreen), findsOneWidget);

      await tikTekst(tester, TekstenCoordinatorNl.tabInstellingen);
      expect(find.byType(InstellingenScreen), findsOneWidget);
    });
  });
}

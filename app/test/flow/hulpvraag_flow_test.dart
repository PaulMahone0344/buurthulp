import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/concept_controller.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_bevestigen_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_verstuurd_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_waar_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_wanneer_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_wat_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_home_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/mijn_gegevens_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/mijn_hulpvragen_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../support/hh_hulpvrager_wikkel.dart';

Future<void> _tik(WidgetTester tester, String tekst) async {
  final doel = find.text(tekst);
  await tester.ensureVisible(doel);
  await tester.tap(doel);
  await tester.pumpAndSettle();
}

Future<void> _terug(WidgetTester tester) async {
  // Op het woord tikken, niet op het midden van de (volle breedte) knop.
  final terug = find.descendant(
    of: find.byType(HhTerugKnop),
    matching: find.text(TekstenNl.terug),
  );
  await tester.ensureVisible(terug);
  await tester.tap(terug);
  await tester.pumpAndSettle();
}

/// Loopt de semantiekboom af zoals een schermlezer: alle knoppen op het
/// scherm, in leesvolgorde.
List<SemanticsNode> _knoppen(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(MaterialApp));
  final knoppen = <SemanticsNode>[];
  void loop(SemanticsNode node) {
    if (node.isMergedIntoParent) return;
    final data = node.getSemanticsData();
    if (data.flagsCollection.isButton && !data.flagsCollection.isHidden) {
      knoppen.add(node);
    }
    node.visitChildren((kind) {
      loop(kind);
      return true;
    });
  }

  loop(root);
  return knoppen;
}

/// Elke knop heeft een niet-leeg label, geen twee knoppen delen een label,
/// en de stapbalk (als die er is) meldt de stap.
void _controleerSchermlezer(WidgetTester tester, {int? stap}) {
  final knoppen = _knoppen(tester);
  expect(knoppen, isNotEmpty, reason: 'geen knoppen voor de schermlezer');
  final labels = <String>[];
  for (final knop in knoppen) {
    final label = knop.getSemanticsData().label;
    expect(label.trim(), isNotEmpty, reason: 'knop zonder label');
    labels.add(label);
  }
  expect(
    labels.toSet().length,
    labels.length,
    reason: 'dubbele knoplabels: $labels',
  );
  if (stap != null) {
    expect(
      find.bySemanticsLabel(RegExp('Stap $stap van 4')),
      findsOneWidget,
      reason: 'stapbalk meldt stap $stap niet',
    );
  }
}

void main() {
  testWidgets(
    'O1 -> O6 plaatst precies een klus met status open en juiste bedragen',
    (tester) async {
      final handle = tester.ensureSemantics();
      final klusGateway = fakeKlusGateway();
      await pompHulpvragerApp(tester, klusGateway: klusGateway);

      // O1
      expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
      _controleerSchermlezer(tester);
      await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);

      // O2: klusje in huis (1250 cent, 60 minuten)
      expect(find.byType(HulpVragenWatScreen), findsOneWidget);
      _controleerSchermlezer(tester, stap: 1);
      await _tik(tester, 'klusje in huis');
      await _tik(tester, TekstenNl.verder);

      // O3: morgen, middag
      expect(find.byType(HulpVragenWanneerScreen), findsOneWidget);
      _controleerSchermlezer(tester, stap: 2);
      await _tik(tester, TekstenHulpvragerNl.dagMorgen);
      await _tik(tester, TekstenHulpvragerNl.dagdeelMiddag);
      await _tik(tester, TekstenNl.verder);

      // O4: adres voorgevuld, toelichting erbij
      expect(find.byType(HulpVragenWaarScreen), findsOneWidget);
      _controleerSchermlezer(tester, stap: 3);
      await tester.enterText(find.byType(TextField).at(3), 'Lamp ophangen.');
      await _tik(tester, TekstenNl.verder);

      // O5
      expect(find.byType(HulpVragenBevestigenScreen), findsOneWidget);
      _controleerSchermlezer(tester, stap: 4);
      expect(find.text('€ 12,50'), findsOneWidget);
      expect(find.text('Prins Bernhardlaan 12, 4003 AB Tiel'), findsOneWidget);
      await _tik(tester, TekstenHulpvragerNl.bevestigenAkkoord);

      // O6
      expect(find.byType(HulpVragenVerstuurdScreen), findsOneWidget);
      _controleerSchermlezer(tester);
      expect(klusGateway.aangemaakteKlussen, hasLength(1));
      final body = klusGateway.aangemaakteKlussen.single.alsBody;
      expect(body['status'], 'open');
      expect(body['bron'], 'app');
      expect(body['klustype'], 'kt-klusje');
      expect(body['bedrag_bruto'], 1250);
      expect(body['vergoeding_jongere'], 1250);
      expect(body['commissie'], 0);
      expect(body['omschrijving'], 'Lamp ophangen.');
      expect(body['adres'], 'Prins Bernhardlaan 12, 4003 AB Tiel');
      expect(
        DateTime.parse(body['wanneer_van'] as String).toLocal(),
        DateTime(2026, 9, 16, 13),
      );
      expect(klusGateway.logregels.single.naar, 'open');

      // Terug bestaat niet meer; naar het begin.
      expect(find.byType(HhTerugKnop), findsNothing);
      await _tik(tester, TekstenHulpvragerNl.verstuurdNaarBegin);
      expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
      expect(find.byType(HulpVragenVerstuurdScreen), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('terugknop bewaart de invoer van elke stap', (tester) async {
    final klusGateway = fakeKlusGateway();
    final container = await pompHulpvragerApp(tester, klusGateway: klusGateway);

    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);
    await _tik(tester, 'tuin');
    await _tik(tester, TekstenNl.verder);
    await _tik(tester, TekstenHulpvragerNl.dagVandaag);
    await _tik(tester, TekstenHulpvragerNl.dagdeelAvond);
    await _tik(tester, TekstenNl.verder);
    await tester.enterText(find.byType(TextField).at(0), 'Kerkstraat 9');
    await tester.enterText(find.byType(TextField).at(3), 'Heg knippen');
    await _tik(tester, TekstenNl.verder);
    expect(find.byType(HulpVragenBevestigenScreen), findsOneWidget);

    // O5 -> O4: adres en toelichting staan er nog.
    await _terug(tester);
    expect(find.byType(HulpVragenWaarScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'Kerkstraat 9',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(3)).controller?.text,
      'Heg knippen',
    );

    // O4 -> O3: dag en dagdeel staan er nog.
    await _terug(tester);
    expect(find.byType(HulpVragenWanneerScreen), findsOneWidget);
    expect(
      find.text(TekstenHulpvragerNl.dagGekozen(TekstenHulpvragerNl.vandaag)),
      findsOneWidget,
    );
    final concept = container.read(conceptProvider);
    expect(concept.klustype?.naam, 'tuin');
    expect(concept.adres, 'Kerkstraat 9');
    expect(concept.toelichting, 'Heg knippen');

    // O3 -> O2: de keuze staat nog en verder is meteen bruikbaar.
    await _terug(tester);
    expect(find.byType(HulpVragenWatScreen), findsOneWidget);
    final verder = tester.widget<HhKnop>(
      find.widgetWithText(HhKnop, TekstenNl.verder),
    );
    expect(verder.isActief, isTrue);
    expect(klusGateway.aangemaakteKlussen, isEmpty);
  });

  testWidgets('stroom verlaten vraagt weet u het zeker, met twee knoppen', (
    tester,
  ) async {
    final klusGateway = fakeKlusGateway();
    final container = await pompHulpvragerApp(tester, klusGateway: klusGateway);

    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);
    await _tik(tester, 'vervoer');
    await _terug(tester);

    expect(find.text(TekstenHulpvragerNl.verlatenVraag), findsOneWidget);
    expect(find.byType(HhKnop), findsWidgets);

    // Nee: blijven, keuze blijft staan.
    await _tik(tester, TekstenHulpvragerNl.verlatenNee);
    expect(find.byType(HulpVragenWatScreen), findsOneWidget);
    expect(container.read(conceptProvider).klustype?.naam, 'vervoer');

    // Ja: terug naar O1, concept leeg.
    await _terug(tester);
    await _tik(tester, TekstenHulpvragerNl.verlatenJa);
    expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
    expect(container.read(conceptProvider).isLeeg, isTrue);
  });

  testWidgets('zonder keuze verlaat de terugknop de stroom zonder vraag', (
    tester,
  ) async {
    await pompHulpvragerApp(tester, klusGateway: fakeKlusGateway());

    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);
    await _terug(tester);

    expect(find.text(TekstenHulpvragerNl.verlatenVraag), findsNothing);
    expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
  });

  testWidgets('zonder adres: O4 stuurt naar O12, na opslaan is O4 gevuld', (
    tester,
  ) async {
    final klusGateway = fakeKlusGateway(metAdres: false);
    await pompHulpvragerApp(tester, klusGateway: klusGateway);

    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);
    await _tik(tester, 'boodschappen');
    await _tik(tester, TekstenNl.verder);
    await _tik(tester, TekstenHulpvragerNl.dagMorgen);
    await _tik(tester, TekstenHulpvragerNl.dagdeelOchtend);
    await _tik(tester, TekstenNl.verder);

    expect(find.text(TekstenHulpvragerNl.waarGeenAdresTitel), findsOneWidget);
    await _tik(tester, TekstenHulpvragerNl.waarGeenAdresKnop);
    expect(find.byType(MijnGegevensScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'Kerkstraat 3');
    await tester.enterText(find.byType(TextField).at(3), '4001 AB');
    await tester.enterText(find.byType(TextField).at(4), 'Tiel');
    await _tik(tester, TekstenNl.opslaan);
    expect(klusGateway.laatsteGegevensBody, {
      'adres': 'Kerkstraat 3',
      'postcode': '4001 AB',
      'plaats': 'Tiel',
    });

    await _terug(tester);
    expect(find.byType(HulpVragenWaarScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'Kerkstraat 3',
    );
  });

  testWidgets(
    'O1: mijn hulpvragen, mijn gegevens en instellingen zijn bereikbaar',
    (tester) async {
      await pompHulpvragerApp(tester, klusGateway: fakeKlusGateway());

      await _tik(tester, TekstenHulpvragerNl.homeMijnHulpvragen);
      expect(find.byType(MijnHulpvragenScreen), findsOneWidget);
      expect(
        find.text(TekstenHulpvragerNl.mijnHulpvragenKomtBinnenkort),
        findsOneWidget,
      );
      await _terug(tester);

      await _tik(tester, TekstenHulpvragerNl.homeMijnGegevens);
      expect(find.byType(MijnGegevensScreen), findsOneWidget);
      await _terug(tester);

      await _tik(tester, TekstenHulpvragerNl.homeInstellingen);
      expect(find.byType(InstellingenScreen), findsOneWidget);
      await _terug(tester);
      expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
    },
  );
}

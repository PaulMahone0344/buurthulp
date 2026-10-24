import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/adres/domein/adres_invoer.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/concept_controller.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_verstuurd_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_home_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/mijn_gegevens_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/oudere_meer_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/screen/hulpvragen_lijst_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klus_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../support/hh_hulpvrager_wikkel.dart';

Future<void> _tik(WidgetTester tester, String tekst) async {
  final doel = find.text(tekst);
  await tester.ensureVisible(doel);
  await tester.tap(doel);
  await tester.pumpAndSettle();
}

/// "Klus plaatsen" staat ook in de titel: tik op de knop.
Future<void> _tikPlaatsen(WidgetTester tester) async {
  final knop = find.widgetWithText(HhKnop, TekstenKlusNl.plaatsen);
  await tester.ensureVisible(knop);
  await tester.tap(knop);
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

/// Elke knop heeft een niet-leeg label en geen twee knoppen delen een label.
void _controleerSchermlezer(WidgetTester tester) {
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
}

void main() {
  testWidgets(
    'O1 -> klus plaatsen (één pagina) -> O6 plaatst precies een klus met '
    'foto, vinkje, tijd en status open',
    (tester) async {
      final handle = tester.ensureSemantics();
      final klusGateway = fakeKlusGateway();
      await pompHulpvragerApp(tester, klusGateway: klusGateway);

      // O1
      expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
      _controleerSchermlezer(tester);
      await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);

      // Eén pagina zoals de mockup KlusPlaatsen.
      expect(find.byType(HulpVragenScreen), findsOneWidget);
      await vulKlusIn(tester);
      // Het adres komt uit Mijn gegevens en wordt niet opnieuw gevraagd.
      expect(
        find.text(
          TekstenKlusNl.waarAdres('Prins Bernhardlaan 12, 4003 AB Tiel'),
        ),
        findsOneWidget,
      );
      _controleerSchermlezer(tester);
      await _tikPlaatsen(tester);

      // O6: de meldkamer kijkt eerst.
      expect(find.byType(HulpVragenVerstuurdScreen), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.verstuurdUitleg), findsOneWidget);
      _controleerSchermlezer(tester);
      expect(klusGateway.aangemaakteKlussen, hasLength(1));
      final klus = klusGateway.aangemaakteKlussen.single;
      final body = klus.alsBody;
      expect(body['status'], 'open');
      expect(body['bron'], 'app');
      expect(body['klustype'], 'kt-klusje');
      expect(body['bedrag_bruto'], 1250);
      expect(body['vergoeding_jongere'], 1250);
      expect(body['commissie'], 0);
      expect(body['omschrijving'], 'Lamp ophangen in de gang.');
      expect(body['adres'], 'Prins Bernhardlaan 12, 4003 AB Tiel');
      expect(body['nee_lijst_akkoord'], isTrue);
      expect(klus.foto.bestandsnaam, 'klus.png');
      // Morgen, de tijdwielen op 10:00 en 11:00 (eindtijd verplicht).
      expect(
        DateTime.parse(body['wanneer_van'] as String).toLocal(),
        DateTime(2026, 9, 16, 10),
      );
      expect(
        DateTime.parse(body['wanneer_tot'] as String).toLocal(),
        DateTime(2026, 9, 16, 11),
      );
      // M6: de app schrijft geen logregel meer; de hook doet dat.

      // Terug bestaat niet meer; naar het begin.
      expect(find.byType(HhTerugKnop), findsNothing);
      await _tik(tester, TekstenHulpvragerNl.verstuurdNaarBegin);
      expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
      expect(find.byType(HulpVragenVerstuurdScreen), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('plaatsen zonder alles ingevuld zegt wat er ontbreekt', (
    tester,
  ) async {
    final klusGateway = fakeKlusGateway();
    await pompHulpvragerApp(tester, klusGateway: klusGateway);
    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);

    await _tikPlaatsen(tester);
    expect(find.text(TekstenKlusNl.ontbreektWat), findsWidgets);

    await _tik(tester, 'Tuin');
    await _tikPlaatsen(tester);
    expect(find.text(TekstenKlusNl.ontbreektOmschrijving), findsWidgets);
    expect(klusGateway.aangemaakteKlussen, isEmpty);
  });

  testWidgets('invoer gaat meteen in het concept', (tester) async {
    final container = await pompHulpvragerApp(
      tester,
      klusGateway: fakeKlusGateway(),
    );

    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);
    await vulKlusIn(tester, categorie: 'Tuin', omschrijving: 'Heg knippen');

    expect(
      find.text(TekstenHulpvragerNl.dagGekozen(TekstenHulpvragerNl.morgen)),
      findsOneWidget,
    );
    final concept = container.read(conceptProvider);
    expect(concept.klustype?.naam, 'Tuin');
    expect(concept.adres, 'Prins Bernhardlaan 12');
    expect(concept.omschrijving, 'Heg knippen');
    expect(concept.heeftFoto, isTrue);
    expect(concept.isCompleet, isTrue);
  });

  testWidgets('pagina verlaten vraagt weet u het zeker, met twee knoppen', (
    tester,
  ) async {
    final klusGateway = fakeKlusGateway();
    final container = await pompHulpvragerApp(tester, klusGateway: klusGateway);

    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);
    await _tik(tester, 'Dieren');
    await _terug(tester);

    expect(find.text(TekstenHulpvragerNl.verlatenVraag), findsOneWidget);
    expect(find.byType(HhKnop), findsWidgets);

    // Nee: blijven, keuze blijft staan.
    await _tik(tester, TekstenHulpvragerNl.verlatenNee);
    expect(find.byType(HulpVragenScreen), findsOneWidget);
    expect(container.read(conceptProvider).klustype?.naam, 'Dieren');

    // Ja: terug naar O1, concept leeg.
    await _terug(tester);
    await _tik(tester, TekstenHulpvragerNl.verlatenJa);
    expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
    expect(container.read(conceptProvider).isLeeg, isTrue);
  });

  testWidgets('zonder adres: naar Mijn gegevens, daarna is het adres bekend', (
    tester,
  ) async {
    final klusGateway = fakeKlusGateway(metAdres: false);
    final container = await pompHulpvragerApp(tester, klusGateway: klusGateway);

    await _tik(tester, TekstenHulpvragerNl.homeHulpVragen);
    expect(find.text(TekstenHulpvragerNl.waarGeenAdresTitel), findsOneWidget);
    await _tik(tester, TekstenHulpvragerNl.waarGeenAdresKnop);
    expect(find.byType(MijnGegevensScreen), findsOneWidget);

    // ADRES: postcode + huisnummer, straat en plaats komen van PDOK (nep).
    await tester.enterText(find.byType(TextField).at(2), '4001ma');
    await tester.enterText(find.byType(TextField).at(3), '1');
    await tester.pump(adresZoekWachttijd);
    await tester.pumpAndSettle();
    expect(find.text('Kerkstraat 1, 4001 MA Tiel'), findsOneWidget);
    await _tik(tester, TekstenNl.opslaan);
    expect(klusGateway.laatsteGegevensBody, {
      'postcode': '4001 MA',
      'huisnummer': '1',
      'toevoeging': '',
      'adres': 'Kerkstraat 1',
      'plaats': 'Tiel',
    });

    await _terug(tester);
    expect(find.byType(HulpVragenScreen), findsOneWidget);
    // Nu bekend: geen adresvelden meer, het adres zit in het concept.
    expect(
      find.text(TekstenKlusNl.waarAdres('Kerkstraat 1, 4001 MA Tiel')),
      findsOneWidget,
    );
    expect(container.read(conceptProvider).adres, 'Kerkstraat 1');
  });

  testWidgets(
    'O1: mijn hulpvragen, mijn gegevens en instellingen zijn bereikbaar',
    (tester) async {
      await pompHulpvragerApp(tester, klusGateway: fakeKlusGateway());

      // Tabs zijn eigen plekken: geen terugknop.
      await _tik(tester, TekstenHulpvragerNl.tabMijnHulpvragen);
      expect(find.byType(HulpvragenLijstScreen), findsOneWidget);
      expect(find.byType(HhTerugKnop), findsNothing);

      await _tik(tester, TekstenHulpvragerNl.tabMeer);
      expect(find.byType(OudereMeerScreen), findsOneWidget);

      await _tik(tester, TekstenHulpvragerNl.homeMijnGegevens);
      expect(find.byType(MijnGegevensScreen), findsOneWidget);
      await _terug(tester);
      expect(find.byType(OudereMeerScreen), findsOneWidget);

      await _tik(tester, TekstenHulpvragerNl.homeInstellingen);
      expect(find.byType(InstellingenScreen), findsOneWidget);
      await _terug(tester);

      // Feedbackronde 1: Voorwaarden & privacy los van Hulp en uitleg; opent
      // de website, de bewoner blijft op Meer.
      await _tik(tester, TekstenHulpvragerNl.meerVoorwaardenTitel);
      expect(find.byType(OudereMeerScreen), findsOneWidget);

      await _tik(tester, TekstenHulpvragerNl.tabStart);
      expect(find.byType(HulpvragerHomeScreen), findsOneWidget);
    },
  );
}

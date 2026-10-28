import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/config.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/fake_adres_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_invoer.dart';
import 'package:heitjehulp_app/design/components/hh_keuzerij.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_lege_staat.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/design/components/hh_stapbalk.dart';
import 'package:heitjehulp_app/features/adres/domein/adres_invoer.dart';
import 'package:heitjehulp_app/features/adres/widget/adres_zoeker.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hulpvraag_concept.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/concept_controller.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_verstuurd_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_home_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/mijn_gegevens_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/screen/bel_ons_screen.dart';
import 'package:heitjehulp_app/features/toegang/domein/werkgebied.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_adres_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klus_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_meldingen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_hulpvrager_wikkel.dart';
import '../../../support/hh_toegang_wikkel.dart';
import '../../../support/hh_wikkel.dart';

class _Geval {
  const _Geval(this.naam, this.scherm, {this.vulConcept = false});

  final String naam;
  final Widget scherm;

  /// Vooraf een compleet concept in de state.
  final bool vulConcept;
}

const _gevallen = [
  _Geval('O1 home', HulpvragerHomeScreen()),
  _Geval('klus plaatsen', HulpVragenScreen()),
  _Geval('klus plaatsen met invoer', HulpVragenScreen(), vulConcept: true),
  _Geval('O6 verstuurd', HulpVragenVerstuurdScreen()),
  _Geval('O12 mijn gegevens', MijnGegevensScreen()),
];

/// De maximale keuzes per rij (ouderenregel: drie).
const _maxPerRij = 3;

/// Punt B: tik "Bij mij thuis" of "Ergens anders".
Future<void> _kiesWaar(WidgetTester tester, String label) async {
  final knop = find.text(label);
  await tester.ensureVisible(knop);
  await tester.tap(knop);
  await tester.pumpAndSettle();
}

/// Postcode en huisnummer in de adreszoeker, dan wachten op PDOK (nep).
Future<void> _vulAdres(
  WidgetTester tester,
  String postcode,
  String huisnummer,
) async {
  Finder veld(String label) => find.descendant(
    of: find
        .ancestor(
          of: find.textContaining(label, findRichText: true),
          matching: find.byType(Column),
        )
        .first,
    matching: find.byType(TextField),
  );
  await tester.enterText(veld(TekstenAdresNl.veldPostcode), postcode);
  await tester.enterText(veld(TekstenAdresNl.veldHuisnummer), huisnummer);
  await tester.pump(adresZoekWachttijd);
  await tester.pumpAndSettle();
}

Future<void> _pomp(
  WidgetTester tester,
  _Geval geval, {
  double tekstschaal = 1.0,
  HhDichtheid dichtheid = HhDichtheid.groot,
  bool metAdres = true,
}) async {
  final klusGateway = fakeKlusGateway(metAdres: metAdres);
  final container = hulpvragerContainer(
    klusGateway: klusGateway,
    sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
  );
  if (geval.vulConcept) _vulCompleet(container);
  await tester.pumpWidget(
    hhHulpvragerWikkel(
      geval.scherm,
      klusGateway: klusGateway,
      container: container,
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pumpAndSettle();
}

/// De pagina met een eigen container (voor de state) en een vaste klok.
Future<ProviderContainer> _pompMetContainer(
  WidgetTester tester, {
  FakeFotoKiezer? fotoKiezer,
  DateTime? nu,
}) async {
  final klusGateway = fakeKlusGateway();
  final container = hulpvragerContainer(
    klusGateway: klusGateway,
    sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
    fotoKiezer: fotoKiezer,
    nu: nu,
  );
  await tester.pumpWidget(
    hhHulpvragerWikkel(
      const HulpVragenScreen(),
      klusGateway: klusGateway,
      container: container,
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Een compleet concept met eindtijd, zoals na het invullen van de pagina.
void _vulCompleet(ProviderContainer container) {
  container.read(conceptProvider.notifier)
    ..kiesKlustype(testKlustypes.first)
    ..zetOmschrijving('Twee tassen boodschappen.')
    ..zetFoto(testKlusFoto)
    ..kiesDagKeuze(HhDagKeuze.morgen)
    ..zetWaar(adres: 'Kerkstraat 1', postcode: '4001 AA', plaats: 'Tiel');
}

Future<void> _tikTekst(WidgetTester tester, String tekst) async {
  final doel = find.text(tekst);
  await tester.ensureVisible(doel);
  await tester.tap(doel);
  await tester.pumpAndSettle();
}

final _omschrijvingVeld = find.byWidgetPredicate(
  (w) => w is HhInvoer && w.label == TekstenKlusNl.omschrijvingTitel,
);

/// "Klus plaatsen" staat ook in de titel: tik op de knop.
Future<void> _tikPlaatsen(WidgetTester tester) async {
  final knop = find.widgetWithText(HhKnop, TekstenKlusNl.plaatsen);
  await tester.ensureVisible(knop);
  await tester.tap(knop);
  await tester.pumpAndSettle();
}

/// Elke knop heeft een label en is een knop; elke keuze in een keuzerij
/// heeft een werkwoord-label; elk invoerveld heeft een label.
void _controleerSemantiek(WidgetTester tester) {
  for (final knop in find.byType(HhKnop).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(knop.widget));
    expect(semantiek.label, isNotEmpty, reason: 'knop zonder label');
    expect(
      semantiek.getSemanticsData().flagsCollection.isButton,
      isTrue,
      reason: 'knop ${semantiek.label} is geen knop voor de schermlezer',
    );
  }
  for (final terug in find.byType(HhTerugKnop).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(terug.widget));
    expect(semantiek.label, TekstenNl.terug);
  }
  for (final veld in find.byType(TextField).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(veld.widget));
    expect(semantiek.label, isNotEmpty, reason: 'invoerveld zonder label');
  }
  for (final rij in find.byType(HhKeuzerij<String>).evaluate()) {
    final keuzerij = rij.widget as HhKeuzerij<String>;
    expect(keuzerij.keuzes.length, lessThanOrEqualTo(_maxPerRij));
    for (final keuze in keuzerij.keuzes) {
      expect(keuze.semantiekLabel, startsWith('Kies '));
    }
  }
}

void main() {
  for (final geval in _gevallen) {
    group(geval.naam, () {
      testWidgets('rendert in dichtheid groot met semantiek en terugknop', (
        tester,
      ) async {
        await _pomp(tester, geval);

        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsWidgets);
        _controleerSemantiek(tester);
        // Ouderenregel: altijd een terugknop, behalve op O1 (het begin) en
        // O6 (de stroom is klaar, een knop naar het begin).
        final zonderTerug =
            geval.scherm is HulpvragerHomeScreen ||
            geval.scherm is HulpVragenVerstuurdScreen;
        expect(
          find.byType(HhTerugKnop),
          zonderTerug ? findsNothing : findsOneWidget,
        );
      });

      testWidgets('rendert ook in de normale dichtheid', (tester) async {
        await _pomp(tester, geval, dichtheid: HhDichtheid.normaal);

        expect(tester.takeException(), isNull);
      });

      testWidgets('200 procent tekst op een smal scherm zonder overloop', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pomp(tester, geval, tekstschaal: hhMaxTekstschaal);

        expect(tester.takeException(), isNull);
      });
    });
  }

  group('O1', () {
    testWidgets('toont naam, de knop hulp vragen en de tabbalk', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[0]);

      expect(
        find.text(TekstenNl.landingWelkom(testGegevens().naam)),
        findsOneWidget,
      );
      expect(find.text(TekstenHulpvragerNl.homeHulpVragen), findsOneWidget);
      // Sinds 3 okt tabs onderin; instellingen en gegevens zitten in Meer.
      for (final tab in [
        TekstenHulpvragerNl.tabStart,
        TekstenHulpvragerNl.tabMijnHulpvragen,
        TekstenHulpvragerNl.tabBelOns,
        TekstenHulpvragerNl.tabMeer,
      ]) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text(TekstenHulpvragerNl.homeInstellingen), findsNothing);
      expect(find.text(TekstenHulpvragerNl.homeMijnGegevens), findsNothing);
      expect(find.text(TekstenNl.uitloggen), findsNothing);
    });

    testWidgets('elke knop heeft een raakvlak van minstens 60', (tester) async {
      await _pomp(tester, _gevallen[0]);

      for (final knop in find.byType(HhKnop).evaluate()) {
        expect(
          tester.getSize(find.byWidget(knop.widget)).height,
          greaterThanOrEqualTo(HhMaten.knopHoogte(HhDichtheid.groot)),
        );
      }
    });

    // M8: "Bel ons" op O1 opent O10; daar zit nu het bellen.
    testWidgets('bel ons (O10) dat mislukt toont het nummer in een meldbalk', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const BelOnsScreen(),
          klusGateway: klusGateway,
          urlOpenerLukt: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(TekstenMeldingenNl.o10Bellen));
      await tester.pumpAndSettle();

      expect(
        find.text(TekstenNl.hulpBellenLuktNiet(HhConfig.meldkamerTelefoon)),
        findsOneWidget,
      );
    });
  });

  group('wat', () {
    testWidgets('één pagina met de koppen uit de mockup, geen stapbalk', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);

      expect(find.byType(HhStapbalk), findsNothing);
      expect(find.text(TekstenKlusNl.paginaTitel), findsWidgets);
      for (final kop in [
        TekstenKlusNl.watTitel,
        TekstenKlusNl.fotoTitel,
        TekstenKlusNl.wanneerTitel,
        TekstenKlusNl.herhalenTitel,
        TekstenKlusNl.waarTitel,
        TekstenKlusNl.prijsJijBetaalt,
      ]) {
        expect(find.text(kop), findsWidgets, reason: kop);
      }
      // Feedbackronde 1: geen "Morgen" en geen nee-lijst meer op de pagina.
      expect(find.text('Morgen'), findsNothing);
      expect(find.text('Dit kan niet via HeitjeHulp'), findsNothing);
      expect(find.text(TekstenKlusNl.fotoVerplicht), findsOneWidget);
      // Antwoord Ibrahim 4 okt: een korte tip bij de foto.
      expect(find.text(TekstenKlusNl.fotoTip), findsOneWidget);
      expect(_omschrijvingVeld, findsOneWidget);
    });

    testWidgets('de kop van de omschrijving volgt de gekozen categorie', (
      tester,
    ) async {
      String kop() => tester.widget<HhInvoer>(find.byType(HhInvoer)).label;
      await _pomp(tester, _gevallen[1]);
      expect(kop(), TekstenKlusNl.omschrijvingTitel);

      await _tikTekst(tester, 'Tuin');
      expect(kop(), 'Vertel meer over het tuinwerk');

      await _tikTekst(tester, 'Overig');
      expect(kop(), 'Vertel wat je wilt');
    });

    testWidgets('dertien categorieën op volgorde, in rijen van drie; '
        'een oud klustype staat er niet bij', (tester) async {
      await _pomp(tester, _gevallen[1]);

      // 13 = 4 rijen van drie + 1.
      expect(find.byType(HhKeuzerij<String>), findsNWidgets(5));
      final actief = testKlustypes.where((t) => t.isActief).toList();
      expect(actief, hasLength(13));
      for (final type in actief) {
        expect(find.text(type.naam), findsOneWidget);
      }
      expect(find.text('vervoer'), findsNothing);
      final eerste = tester.widget<HhKeuzerij<String>>(
        find.byType(HhKeuzerij<String>).first,
      );
      expect(eerste.keuzes.map((k) => k.label), [
        'Tuin',
        'Auto & fiets',
        'Schoonmaak',
      ]);
      // De laatste tegel blijft even breed als de rest (raster van drie).
      final tuin = tester.getSize(find.text('Tuin'));
      final overig = tester.getSize(find.text('Overig'));
      expect(overig.width, lessThan(tuin.width * 2));
    });

    testWidgets('fout bij laden toont de melding en opnieuw proberen', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway()..isOffline = true;
      await tester.pumpWidget(
        hhHulpvragerWikkel(const HulpVragenScreen(), klusGateway: klusGateway),
      );
      await tester.pumpAndSettle();

      // Wat en waar laden allebei; allebei melden ze de fout.
      expect(find.text(TekstenNl.foutGeenVerbinding), findsWidgets);

      klusGateway.isOffline = false;
      await tester.tap(find.text(TekstenNl.opnieuwProberen).first);
      await tester.pumpAndSettle();

      expect(find.text(testKlustypes.first.naam), findsOneWidget);
    });

    testWidgets('geen categorieën: lege staat', (tester) async {
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenScreen(),
          klusGateway: fakeKlusGateway(klustypes: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HhLegeStaat), findsOneWidget);
    });
  });

  group('vertel wat je wilt', () {
    testWidgets('teller loopt mee en het veld is meerregelig', (tester) async {
      await _pomp(tester, _gevallen[1]);

      final invoer = tester.widget<HhInvoer>(_omschrijvingVeld);
      expect(invoer.maxRegels, greaterThan(1));
      expect(invoer.isVerplicht, isTrue);
      expect(find.text(TekstenKlusNl.omschrijvingTeller(0)), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Heg knippen');
      await tester.pumpAndSettle();
      expect(find.text(TekstenKlusNl.omschrijvingTeller(11)), findsOneWidget);
    });

    testWidgets('meer dan 300 tekens wordt afgeknipt', (tester) async {
      final container = await _pompMetContainer(tester);
      await tester.enterText(find.byType(TextField).first, 'a' * 320);
      await tester.pumpAndSettle();

      expect(container.read(conceptProvider).omschrijving.length, 300);
      expect(find.text(TekstenKlusNl.omschrijvingTeller(300)), findsOneWidget);
    });
  });

  group('foto', () {
    testWidgets('kiezen toont het voorbeeld en een knop om te verwijderen', (
      tester,
    ) async {
      final container = await _pompMetContainer(tester);

      await _tikTekst(tester, TekstenKlusNl.fotoKiezen);
      expect(container.read(conceptProvider).foto, same(testKlusFoto));
      expect(find.text(TekstenKlusNl.fotoGekozen), findsOneWidget);
      expect(
        find.bySemanticsLabel(TekstenKlusNl.fotoVoorbeeldSemantiek),
        findsOneWidget,
      );

      await _tikTekst(tester, TekstenKlusNl.fotoVerwijderen);
      expect(container.read(conceptProvider).foto, isNull);
      expect(find.text(TekstenKlusNl.fotoMaken), findsOneWidget);
    });

    testWidgets('maken gebruikt de camera; mislukt toont een melding', (
      tester,
    ) async {
      final kiezer = FakeFotoKiezer(volgende: testKlusFoto)
        ..volgendeFout = const HhFout(HhFoutSoort.onbekend);
      await _pompMetContainer(tester, fotoKiezer: kiezer);

      await _tikTekst(tester, TekstenKlusNl.fotoMaken);
      expect(kiezer.aanroepen, [HhFotoBron.camera]);
      expect(find.text(TekstenKlusNl.fotoLuktNiet), findsOneWidget);
    });

    testWidgets('annuleren laat de foto leeg', (tester) async {
      final container = await _pompMetContainer(
        tester,
        fotoKiezer: FakeFotoKiezer(),
      );

      await _tikTekst(tester, TekstenKlusNl.fotoKiezen);
      expect(container.read(conceptProvider).foto, isNull);
      expect(find.text(TekstenKlusNl.fotoLuktNiet), findsNothing);
    });
  });

  group('wanneer', () {
    testWidgets('het tijdwiel verschijnt pas na een dag', (tester) async {
      await _pomp(tester, _gevallen[1]);

      expect(find.byType(CupertinoDatePicker), findsNothing);

      await _tikTekst(tester, TekstenHulpvragerNl.dagVandaag);

      expect(
        find.text(TekstenHulpvragerNl.dagGekozen(TekstenHulpvragerNl.vandaag)),
        findsOneWidget,
      );
      // Feedbackronde 1: begin- en eindtijd, allebei verplicht.
      expect(find.byType(CupertinoDatePicker), findsNWidgets(2));
      // testNu is 10:00: het wiel begint op 12:00.
      expect(
        find.text(TekstenKlusNl.tijdGekozen(TekstenKlusNl.vanaf, '12:00')),
        findsOneWidget,
      );
    });

    testWidgets('begin- en eindtijd staan er meteen, de eindtijd een uur '
        'later', (tester) async {
      final container = await _pompMetContainer(tester);
      await kiesMorgen(tester);

      expect(find.text('Optioneel'), findsNothing);
      expect(find.byType(CupertinoDatePicker), findsNWidgets(2));
      expect(
        find.text(TekstenKlusNl.tijdGekozen(TekstenKlusNl.tot, '11:00')),
        findsOneWidget,
      );
      expect(container.read(conceptProvider).eindMinuten, 11 * 60);
    });

    testWidgets('het wiel draaien zet de begintijd in het concept', (
      tester,
    ) async {
      final container = await _pompMetContainer(tester);
      await kiesMorgen(tester);

      final wiel = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker).first,
      );
      wiel.onDateTimeChanged(DateTime(2000, 1, 1, 14, 30));
      await tester.pumpAndSettle();

      expect(container.read(conceptProvider).vanafMinuten, 14 * 60 + 30);
      expect(wiel.use24hFormat, isTrue);
      expect(wiel.minuteInterval, 15);
    });

    testWidgets('kies een dag opent een lijst met grote dagknoppen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);

      await _tikTekst(tester, TekstenHulpvragerNl.dagAndere);

      expect(find.text(TekstenHulpvragerNl.dagKiezerTitel), findsOneWidget);
      // testNu is dinsdag 15 september; donderdag 17 september staat erbij.
      await _tikTekst(tester, 'donderdag 17 september');

      expect(
        find.text(TekstenHulpvragerNl.dagGekozen('donderdag 17 september')),
        findsOneWidget,
      );
    });

    testWidgets('een tijd die al voorbij is wordt gemeld', (tester) async {
      final container = await _pompMetContainer(
        tester,
        nu: DateTime(2026, 9, 15, 15),
      );
      await _tikTekst(tester, TekstenHulpvragerNl.dagVandaag);
      container.read(conceptProvider.notifier).zetVanaf(9 * 60);
      await tester.pumpAndSettle();

      expect(find.text(TekstenKlusNl.ontbreektTijdVoorbij), findsOneWidget);
    });

    testWidgets('avond of langer dan 2 uur: waarschuwing alleen 18+', (
      tester,
    ) async {
      final container = await _pompMetContainer(tester);
      await kiesMorgen(tester);
      expect(find.text(TekstenKlusNl.alleen18Plus), findsNothing);

      container.read(conceptProvider.notifier)
        ..zetVanaf(20 * 60)
        ..zetTot(21 * 60);
      await tester.pumpAndSettle();
      expect(find.text(TekstenKlusNl.alleen18Plus), findsOneWidget);

      container.read(conceptProvider.notifier)
        ..zetVanaf(13 * 60)
        ..zetTot(16 * 60);
      await tester.pumpAndSettle();
      expect(find.text(TekstenKlusNl.alleen18Plus), findsOneWidget);

      container.read(conceptProvider.notifier).zetTot(14 * 60);
      await tester.pumpAndSettle();
      expect(find.text(TekstenKlusNl.alleen18Plus), findsNothing);
    });

    testWidgets('eindigt na 18:00: waarschuwing pas vanaf 15 jaar', (
      tester,
    ) async {
      final container = await _pompMetContainer(tester);
      await kiesMorgen(tester);
      container.read(conceptProvider.notifier)
        ..zetVanaf(17 * 60)
        ..zetTot(18 * 60 + 30);
      await tester.pumpAndSettle();
      expect(find.text(TekstenKlusNl.alleen15Plus), findsOneWidget);
      expect(find.text(TekstenKlusNl.alleen18Plus), findsNothing);

      container.read(conceptProvider.notifier).zetTot(18 * 60);
      await tester.pumpAndSettle();
      expect(find.text(TekstenKlusNl.alleen15Plus), findsNothing);
    });

    testWidgets('eindtijd voor de begintijd wordt gemeld', (tester) async {
      final container = await _pompMetContainer(tester);
      await kiesMorgen(tester);
      container.read(conceptProvider.notifier).zetTot(9 * 60);
      await tester.pumpAndSettle();

      expect(find.text(TekstenKlusNl.ontbreektTot), findsOneWidget);
    });
  });

  group('herhalen, nee-lijst en prijs', () {
    testWidgets('alleen eenmalig; de rest op slot met Plus', (tester) async {
      final handle = tester.ensureSemantics();
      await _pomp(tester, _gevallen[1]);

      expect(find.text(TekstenKlusNl.plus), findsNWidgets(3));
      expect(find.text(TekstenKlusNl.herhalenUitleg), findsOneWidget);
      final wekelijks = tester.getSemantics(
        find.bySemanticsLabel(
          TekstenKlusNl.herhalenSlotSemantiek(TekstenKlusNl.wekelijks),
        ),
      );
      expect(
        wekelijks.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      handle.dispose();
    });

    testWidgets('jij betaalt € 0,00, een voorbeeld', (tester) async {
      await _pomp(tester, _gevallen[1]);

      expect(find.text('€ 0,00'), findsOneWidget);
      expect(find.text(TekstenKlusNl.prijsVoorbeeld), findsOneWidget);
    });
  });

  group('waar', () {
    testWidgets('adres bekend uit mijn gegevens: één regel, geen velden', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);

      // Alleen "Vertel wat je wilt"; het adres wordt niet opnieuw gevraagd.
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text(
          TekstenKlusNl.waarAdres('Prins Bernhardlaan 12, 4003 AB Tiel'),
        ),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HulpVragenScreen)),
      );
      final concept = container.read(conceptProvider);
      expect(concept.adres, 'Prins Bernhardlaan 12');
      expect(concept.postcode, '4003 AB');
      expect(concept.plaats, 'Tiel');
    });

    testWidgets('eerder ingevuld adres uit het concept wint van de gegevens', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[2]);

      expect(
        find.text(TekstenKlusNl.waarAdres('Kerkstraat 1, 4001 AA Tiel')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Twee tassen boodschappen.',
      );
    });

    testWidgets('punt B: ergens anders gaat via postcode en huisnummer', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HulpVragenScreen)),
      );

      await _kiesWaar(tester, TekstenKlusNl.waarElders);
      expect(find.byType(AdresZoeker), findsOneWidget);
      expect(container.read(conceptProvider).isElders, isTrue);
      expect(container.read(conceptProvider).heeftWaar, isFalse);

      await _vulAdres(tester, '4001 MA', '1');
      final concept = container.read(conceptProvider);
      expect(concept.adres, 'Kerkstraat 1');
      expect(concept.postcode, '4001 MA');
      expect(concept.plaats, 'Tiel');
      expect(concept.eldersAdres, FakeAdresGateway.kerkstraat1);

      // Terug naar thuis: weer het eigen adres, het andere blijft bewaard.
      await _kiesWaar(tester, TekstenKlusNl.waarThuis);
      final thuis = container.read(conceptProvider);
      expect(thuis.isElders, isFalse);
      expect(thuis.adres, 'Prins Bernhardlaan 12');
      expect(
        find.text(
          TekstenKlusNl.waarAdres('Prins Bernhardlaan 12, 4003 AB Tiel'),
        ),
        findsOneWidget,
      );
      await _kiesWaar(tester, TekstenKlusNl.waarElders);
      expect(container.read(conceptProvider).adres, 'Kerkstraat 1');
    });

    testWidgets('punt B: buiten het werkgebied telt het adres niet', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HulpVragenScreen)),
      );

      await _kiesWaar(tester, TekstenKlusNl.waarElders);
      await _vulAdres(tester, '1012 JS', '1');

      expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsOneWidget);
      expect(container.read(conceptProvider).heeftWaar, isFalse);
    });

    testWidgets('punt B: ergens anders zonder adres geeft een veldfout', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);
      await _kiesWaar(tester, TekstenKlusNl.waarElders);

      await _tikPlaatsen(tester);

      expect(find.text(TekstenKlusNl.waarEldersFout), findsOneWidget);
    });

    testWidgets('zonder bekend adres: eerst mijn gegevens invullen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1], metAdres: false);

      expect(find.text(TekstenHulpvragerNl.waarGeenAdresTitel), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.waarGeenAdresKnop), findsOneWidget);
    });

    testWidgets('half adres in het concept: velden met veldfouten', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HulpVragenScreen)),
      );
      container
          .read(conceptProvider.notifier)
          .zetWaar(adres: '', postcode: ' ', plaats: 'Tiel');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenScreen(),
          klusGateway: fakeKlusGateway(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      // Omschrijving plus straat, postcode en plaats.
      expect(find.byType(TextField), findsNWidgets(4));

      await _tikPlaatsen(tester);

      expect(find.text(TekstenHulpvragerNl.validatieAdres), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.validatiePostcode), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.validatiePlaats), findsNothing);
    });
  });

  group('plaatsen', () {
    testWidgets('leeg: zegt wat er ontbreekt, in de volgorde van de pagina', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway();
      final container = hulpvragerContainer(
        klusGateway: klusGateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
      );
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenScreen(),
          klusGateway: klusGateway,
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(conceptProvider.notifier);

      Future<void> verwacht(String melding) async {
        await _tikPlaatsen(tester);
        expect(find.text(melding), findsWidgets, reason: melding);
      }

      await verwacht(TekstenKlusNl.ontbreektWat);
      controller.kiesKlustype(testKlustypes.first);
      await verwacht(TekstenKlusNl.ontbreektOmschrijving);
      controller.zetOmschrijving('Heg knippen');
      await verwacht(TekstenKlusNl.ontbreektFoto);
      controller.zetFoto(testKlusFoto);
      await verwacht(TekstenKlusNl.ontbreektWanneer);
      controller.kiesDagKeuze(HhDagKeuze.morgen);
      controller.zetTot(9 * 60);
      await verwacht(TekstenKlusNl.ontbreektTot);
      // Plaatsen zelf (en de stap naar O6) staat in de flowtest.
      expect(klusGateway.aangemaakteKlussen, isEmpty);
    });

    testWidgets('mislukt plaatsen toont de fout en houdt de knop bruikbaar', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway();
      final container = hulpvragerContainer(
        klusGateway: klusGateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
      );
      _vulCompleet(container);
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenScreen(),
          klusGateway: klusGateway,
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      // Pas nu: de pagina laadt eerst zelf de eigen gegevens.
      klusGateway.volgendeFout = const HhFout(HhFoutSoort.server);

      await _tikPlaatsen(tester);

      expect(find.text(TekstenNl.foutServer), findsOneWidget);
      expect(klusGateway.aangemaakteKlussen, isEmpty);
      final knop = tester.widget<HhKnop>(
        find.widgetWithText(HhKnop, TekstenKlusNl.plaatsen),
      );
      expect(knop.isActief, isTrue);
    });
  });

  group('O6', () {
    testWidgets('geen cijfers, een knop', (tester) async {
      await _pomp(tester, _gevallen[3]);

      expect(find.byType(HhKnop), findsOneWidget);
      for (final tekst in find.byType(Text).evaluate()) {
        final data = (tekst.widget as Text).data ?? '';
        expect(
          data,
          isNot(matches(RegExp(r'\d'))),
          reason: 'cijfer in "$data"',
        );
      }
    });
  });

  group('O12', () {
    testWidgets('velden zijn voorgevuld en opslaan stuurt alleen wijzigingen', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const MijnGegevensScreen(),
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();

      // Punt F: "Hoe kom je bij je deur?" staat voor de contactpersoon.
      expect(find.byType(TextField), findsNWidgets(8));
      expect(
        tester.widget<TextField>(find.byType(TextField).at(6)).controller?.text,
        'Dochter Jansen',
      );

      await tester.enterText(find.byType(TextField).at(7), '0699999999');
      await tester.ensureVisible(find.text(TekstenNl.opslaan));
      await tester.tap(find.text(TekstenNl.opslaan));
      await tester.pumpAndSettle();

      expect(klusGateway.laatsteGegevensBody, {
        'contact_telefoon': '0699999999',
      });
      expect(find.text(TekstenHulpvragerNl.gegevensOpgeslagen), findsOneWidget);
    });

    testWidgets('punt F: woning invullen stuurt alleen de woonvelden', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const MijnGegevensScreen(),
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(TekstenHulpvragerNl.gegevensKaartWoning),
        findsOneWidget,
      );
      // Verdieping en lift alleen bij een appartement.
      expect(find.text(TekstenHulpvragerNl.woningLiftVraag), findsNothing);

      Future<void> tik(Finder doel) async {
        await tester.ensureVisible(doel);
        await tester.tap(doel);
        await tester.pumpAndSettle();
      }

      await tik(find.text(TekstenHulpvragerNl.woningAppartement));
      expect(find.text(TekstenHulpvragerNl.woningLiftVraag), findsOneWidget);
      final verdieping = find.descendant(
        of: find
            .ancestor(
              of: find.textContaining(
                TekstenHulpvragerNl.veldVerdieping,
                findRichText: true,
              ),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(verdieping);
      await tester.enterText(verdieping, '3e');
      // Lift: Ja is de eerste "Ja" op de kaart, trap de tweede.
      await tik(find.text(TekstenHulpvragerNl.ja).first);
      await tik(find.text(TekstenHulpvragerNl.nee).last);
      await tik(find.text(TekstenNl.opslaan));

      expect(klusGateway.laatsteGegevensBody, {
        'woning_type': 'appartement',
        'verdieping': '3',
        'lift': 'ja',
        'trap': 'nee',
      });
    });

    testWidgets(
      'opslaan met een niet gecontroleerd adres: melding boven de knop, in beeld',
      (tester) async {
        final klusGateway = fakeKlusGateway();
        await tester.pumpWidget(
          hhHulpvragerWikkel(
            const MijnGegevensScreen(),
            klusGateway: klusGateway,
          ),
        );
        await tester.pumpAndSettle();
        // Huisnummer wijzigen = adres aangeraakt, maar nog niet gecontroleerd.
        final huisnummer = find.byType(TextField).at(3);
        await tester.ensureVisible(huisnummer);
        await tester.enterText(huisnummer, '86');
        await tester.pump();
        await tester.ensureVisible(find.text(TekstenNl.opslaan));
        await tester.tap(find.text(TekstenNl.opslaan));
        await tester.pumpAndSettle();
        expect(klusGateway.laatsteGegevensBody, isNull);
        final melding = find.text(TekstenHulpvragerNl.gegevensNakijken);
        expect(melding, findsOneWidget);
        // Boven de knop, niet bovenaan het scherm.
        expect(
          tester.getTopLeft(melding).dy,
          lessThan(tester.getTopLeft(find.text(TekstenNl.opslaan)).dy),
        );
        expect(
          tester.getTopLeft(melding).dy,
          greaterThan(
            tester
                .getTopLeft(find.text(TekstenHulpvragerNl.gegevensKaartAdres))
                .dy,
          ),
        );
      },
    );

    testWidgets('niets gewijzigd stuurt niets', (tester) async {
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const MijnGegevensScreen(),
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(TekstenNl.opslaan));
      await tester.tap(find.text(TekstenNl.opslaan));
      await tester.pumpAndSettle();

      expect(klusGateway.laatsteGegevensBody, isNull);
      expect(
        find.text(TekstenHulpvragerNl.gegevensNietsGewijzigd),
        findsOneWidget,
      );
    });

    testWidgets('lege naam wordt geweigerd', (tester) async {
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const MijnGegevensScreen(),
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '');
      await tester.ensureVisible(find.text(TekstenNl.opslaan));
      await tester.tap(find.text(TekstenNl.opslaan));
      await tester.pumpAndSettle();

      expect(
        find.text(TekstenHulpvragerNl.gegevensNaamVerplicht),
        findsOneWidget,
      );
      expect(klusGateway.laatsteGegevensBody, isNull);
    });
  });

  group('B2: werkgebied', () {
    Future<void> pompHome(WidgetTester tester, HhGebruiker gebruiker) async {
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpvragerHomeScreen(),
          klusGateway: fakeKlusGateway(),
          sessie: SessieIngelogd(gebruiker),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('met wijk: de knop Hulp vragen', (tester) async {
      await pompHome(tester, testGebruiker(HhRol.hulpvrager));

      expect(find.text(TekstenHulpvragerNl.homeHulpVragen), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsNothing);
    });

    testWidgets('buiten het werkgebied: melding en geen knop', (tester) async {
      await pompHome(
        tester,
        testGebruiker(
          HhRol.hulpvrager,
          wijkId: '',
        ).copyWith(werkgebiedStatus: HhWerkgebiedStatus.buiten),
      );

      expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.homeHulpVragen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('adres niet gevonden: de meldkamer kijkt ernaar', (
      tester,
    ) async {
      await pompHome(
        tester,
        testGebruiker(
          HhRol.hulpvrager,
          wijkId: '',
        ).copyWith(werkgebiedStatus: HhWerkgebiedStatus.onbekend),
      );

      expect(find.text(TekstenAanmeldenNl.adresOnbekend), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.homeHulpVragen), findsNothing);
    });

    testWidgets('klus plaatsen zonder wijk plaatst niets', (tester) async {
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenScreen(),
          klusGateway: klusGateway,
          sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager, wijkId: '')),
        ),
      );
      await tester.pumpAndSettle();

      final knop = find.byType(HhKnop).last;
      await tester.ensureVisible(knop);
      await tester.tap(knop);
      await tester.pumpAndSettle();

      expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsOneWidget);
      expect(klusGateway.aangemaakteKlussen, isEmpty);
    });
  });
}

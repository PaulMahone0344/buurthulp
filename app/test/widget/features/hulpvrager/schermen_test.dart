import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/config.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/design/components/hh_invoer.dart';
import 'package:heitjehulp_app/design/components/hh_keuzerij.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_lege_staat.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/design/components/hh_stapbalk.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hulpvraag_concept.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/concept_controller.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_bevestigen_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_verstuurd_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_waar_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_wanneer_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulp_vragen_wat_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_home_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/mijn_gegevens_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/screen/bel_ons_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
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

  /// Vooraf een compleet concept in de state, voor O4 en O5.
  final bool vulConcept;
}

const _gevallen = [
  _Geval('O1 home', HulpvragerHomeScreen()),
  _Geval('O2 wat', HulpVragenWatScreen()),
  _Geval('O3 wanneer', HulpVragenWanneerScreen()),
  _Geval('O4 waar', HulpVragenWaarScreen()),
  _Geval('O4 waar met invoer', HulpVragenWaarScreen(), vulConcept: true),
  _Geval('O5 bevestigen', HulpVragenBevestigenScreen(), vulConcept: true),
  _Geval('O6 verstuurd', HulpVragenVerstuurdScreen()),
  _Geval('O12 mijn gegevens', MijnGegevensScreen()),
];

/// De maximale keuzes per rij (ouderenregel: drie).
const _maxPerRij = 3;

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
  if (geval.vulConcept) {
    container.read(conceptProvider.notifier)
      ..kiesKlustype(testKlustypes.first)
      ..kiesDagKeuze(HhDagKeuze.morgen)
      ..kiesDagdeel(HhDagdeel.ochtend)
      ..zetWaar(
        adres: 'Kerkstraat 1',
        postcode: '4001 AA',
        plaats: 'Tiel',
        toelichting: 'Twee tassen.',
      );
  }
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

  group('O2', () {
    testWidgets('stapbalk zegt stap 1 van 4 en verder is uit zonder keuze', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);

      final stapbalk = tester.widget<HhStapbalk>(find.byType(HhStapbalk));
      expect(stapbalk.zin, 'Stap 1 van 4');
      expect(
        tester.getSemantics(find.byType(HhStapbalk)).label,
        contains('Stap 1 van 4'),
      );
      final verder = tester.widget<HhKnop>(
        find.widgetWithText(HhKnop, TekstenNl.verder),
      );
      expect(verder.isActief, isFalse);
    });

    testWidgets('zes soorten in twee rijen van drie, geen knop meer', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);

      expect(find.byType(HhKeuzerij<String>), findsNWidgets(2));
      expect(find.text(TekstenHulpvragerNl.watMeer), findsNothing);
      for (final type in testKlustypes) {
        expect(find.text(type.naam), findsOneWidget);
      }
    });

    testWidgets('zeven soorten: eerst zes, na meer alle zeven', (tester) async {
      final klusGateway = fakeKlusGateway(
        klustypes: [...testKlustypes, testExtraKlustype],
      );
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenWatScreen(),
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();

      // Op naam gesorteerd valt de laatste ("wandelen/gezelschap") buiten
      // de eerste zes; "huisdier" staat er wel bij.
      expect(find.text('wandelen/gezelschap'), findsNothing);
      expect(find.text(testExtraKlustype.naam), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.watMeer), findsOneWidget);

      await tester.ensureVisible(find.text(TekstenHulpvragerNl.watMeer));
      await tester.tap(find.text(TekstenHulpvragerNl.watMeer));
      await tester.pumpAndSettle();

      expect(find.text('wandelen/gezelschap'), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.watMinder), findsOneWidget);
      expect(find.byType(HhKeuzerij<String>), findsNWidgets(3));
    });

    testWidgets('fout bij laden toont de melding en opnieuw proberen', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway()..isOffline = true;
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenWatScreen(),
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);

      klusGateway.isOffline = false;
      await tester.tap(find.text(TekstenNl.opnieuwProberen));
      await tester.pumpAndSettle();

      expect(find.text(testKlustypes.first.naam), findsOneWidget);
    });

    testWidgets('geen soorten: lege staat', (tester) async {
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenWatScreen(),
          klusGateway: fakeKlusGateway(klustypes: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HhLegeStaat), findsOneWidget);
    });
  });

  group('O3', () {
    testWidgets('dagdeel verschijnt pas na een dag; vandaag wordt gemeld', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[2]);

      expect(find.text(TekstenHulpvragerNl.dagdeelOchtend), findsNothing);

      await tester.tap(find.text(TekstenHulpvragerNl.dagVandaag));
      await tester.pumpAndSettle();

      expect(
        find.text(TekstenHulpvragerNl.dagGekozen(TekstenHulpvragerNl.vandaag)),
        findsOneWidget,
      );
      expect(find.text(TekstenHulpvragerNl.dagdeelOchtend), findsOneWidget);
    });

    testWidgets('kies een dag opent een lijst met grote dagknoppen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[2]);

      await tester.tap(find.text(TekstenHulpvragerNl.dagAndere));
      await tester.pumpAndSettle();

      expect(find.text(TekstenHulpvragerNl.dagKiezerTitel), findsOneWidget);
      // testNu is dinsdag 15 september; donderdag 17 september staat erbij.
      await tester.tap(find.text('donderdag 17 september'));
      await tester.pumpAndSettle();

      expect(
        find.text(TekstenHulpvragerNl.dagGekozen('donderdag 17 september')),
        findsOneWidget,
      );
    });

    testWidgets('een dagdeel dat al voorbij is wordt geweigerd', (
      tester,
    ) async {
      // testNu is 10:00; de ochtend van vandaag loopt nog, dus we testen met
      // een klok om 15:00.
      final klusGateway = fakeKlusGateway();
      final container = hulpvragerContainer(
        klusGateway: klusGateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
        nu: DateTime(2026, 9, 15, 15),
      );
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenWanneerScreen(),
          klusGateway: klusGateway,
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(TekstenHulpvragerNl.dagVandaag));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TekstenHulpvragerNl.dagdeelOchtend));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(TekstenNl.verder));
      await tester.tap(find.text(TekstenNl.verder));
      await tester.pumpAndSettle();

      expect(find.text(TekstenHulpvragerNl.wanneerVoorbij), findsOneWidget);
    });
  });

  group('O4', () {
    testWidgets('adres is voorgevuld uit de eigen gegevens', (tester) async {
      await _pomp(tester, _gevallen[3]);

      final velden = find.byType(TextField);
      expect(
        tester.widget<TextField>(velden.at(0)).controller?.text,
        'Prins Bernhardlaan 12',
      );
      expect(
        tester.widget<TextField>(velden.at(1)).controller?.text,
        '4003 AB',
      );
      expect(tester.widget<TextField>(velden.at(2)).controller?.text, 'Tiel');
    });

    testWidgets('eerder ingevuld adres uit het concept wint van de gegevens', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[4]);

      final velden = find.byType(TextField);
      expect(
        tester.widget<TextField>(velden.at(0)).controller?.text,
        'Kerkstraat 1',
      );
      expect(
        tester.widget<TextField>(velden.at(3)).controller?.text,
        'Twee tassen.',
      );
    });

    testWidgets('zonder bekend adres: eerst mijn gegevens invullen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[3], metAdres: false);

      expect(find.text(TekstenHulpvragerNl.waarGeenAdresTitel), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.waarGeenAdresKnop), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('leeg adres geeft veldfouten; microfoon is uitgeschakeld', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[3]);
      await tester.enterText(find.byType(TextField).at(0), '');
      await tester.enterText(find.byType(TextField).at(1), ' ');

      await tester.ensureVisible(find.text(TekstenNl.verder));
      await tester.tap(find.text(TekstenNl.verder));
      await tester.pumpAndSettle();

      expect(find.text(TekstenHulpvragerNl.validatieAdres), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.validatiePostcode), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.validatiePlaats), findsNothing);

      final mic = tester.widget<HhKnop>(
        find.widgetWithText(HhKnop, TekstenHulpvragerNl.waarInspreken),
      );
      expect(mic.isActief, isFalse);
      expect(
        tester.getSemantics(find.byWidget(mic)).label,
        TekstenHulpvragerNl.waarInsprekenSemantiek,
      );
    });

    testWidgets('de toelichting is meerregelig', (tester) async {
      await _pomp(tester, _gevallen[3]);

      final invoer = tester.widget<HhInvoer>(
        find.widgetWithText(HhInvoer, TekstenHulpvragerNl.veldToelichting),
      );
      expect(invoer.maxRegels, greaterThan(1));
    });
  });

  group('O5', () {
    testWidgets('toont wat, wanneer, waar, duur en vergoeding in gewone taal', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[5]);

      expect(find.text('boodschappen'), findsOneWidget);
      expect(
        find.text('morgen in de ochtend (van 9 tot 12 uur)'),
        findsOneWidget,
      );
      expect(find.text('Kerkstraat 1, 4001 AA Tiel'), findsOneWidget);
      expect(find.text('ongeveer 1 uur'), findsOneWidget);
      expect(find.text('€ 10,00'), findsOneWidget);
      expect(find.text('Twee tassen.'), findsOneWidget);
      final stapbalk = tester.widget<HhStapbalk>(find.byType(HhStapbalk));
      expect(stapbalk.zin, 'Stap 4 van 4');
    });

    testWidgets('mislukt plaatsen toont de fout en houdt de knop bruikbaar', (
      tester,
    ) async {
      final klusGateway = fakeKlusGateway()
        ..volgendeFout = const HhFout(HhFoutSoort.server);
      final container = hulpvragerContainer(
        klusGateway: klusGateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
      );
      container.read(conceptProvider.notifier)
        ..kiesKlustype(testKlustypes.first)
        ..kiesDagKeuze(HhDagKeuze.morgen)
        ..kiesDagdeel(HhDagdeel.ochtend)
        ..zetWaar(
          adres: 'Kerkstraat 1',
          postcode: '4001 AA',
          plaats: 'Tiel',
          toelichting: '',
        );
      await tester.pumpWidget(
        hhHulpvragerWikkel(
          const HulpVragenBevestigenScreen(),
          klusGateway: klusGateway,
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.text(TekstenHulpvragerNl.bevestigenAkkoord),
      );
      await tester.tap(find.text(TekstenHulpvragerNl.bevestigenAkkoord));
      await tester.pumpAndSettle();

      expect(find.text(TekstenNl.foutServer), findsOneWidget);
      expect(klusGateway.aangemaakteKlussen, isEmpty);
      final knop = tester.widget<HhKnop>(
        find.widgetWithText(HhKnop, TekstenHulpvragerNl.bevestigenAkkoord),
      );
      expect(knop.isActief, isTrue);
    });
  });

  group('O6', () {
    testWidgets('geen cijfers, een knop', (tester) async {
      await _pomp(tester, _gevallen[6]);

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

      expect(find.byType(TextField), findsNWidgets(7));
      expect(
        tester.widget<TextField>(find.byType(TextField).at(5)).controller?.text,
        'Dochter Jansen',
      );

      await tester.enterText(find.byType(TextField).at(6), '0699999999');
      await tester.ensureVisible(find.text(TekstenNl.opslaan));
      await tester.tap(find.text(TekstenNl.opslaan));
      await tester.pumpAndSettle();

      expect(klusGateway.laatsteGegevensBody, {
        'contact_telefoon': '0699999999',
      });
      expect(find.text(TekstenHulpvragerNl.gegevensOpgeslagen), findsOneWidget);
    });

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
}

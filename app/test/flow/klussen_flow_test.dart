import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:heitjehulp_app/core/pb/fake_reactie_gateway.dart';
import 'package:heitjehulp_app/core/pb/reactie_gateway.dart';
import 'package:heitjehulp_app/features/reacties/screen/reactie_verstuurd_screen.dart';
import 'package:heitjehulp_app/features/reacties/widget/reactie_tegel.dart';
import 'package:heitjehulp_app/l10n/teksten_reacties_nl.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/features/jongere/klussen/provider/klussen_providers.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/klus_detail_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/klussen_home_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/mijn_klussen_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/klus_tegel.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/klussen_kaart.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_overzicht_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/inloggen_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../support/hh_jongere_wikkel.dart';
import '../support/hh_klussen_wikkel.dart';

/// Scrolt de eerste tegel in beeld en tikt erop.
Future<void> tikEersteTegel(WidgetTester tester) async {
  final tegel = find.byType(KlusTegel).first;
  await tester.ensureVisible(tegel);
  await tester.tap(tegel);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ingelogde goedgekeurde jongere landt op J11 met de klussen', (
    tester,
  ) async {
    await pompKlussenApp(tester, klussenGateway: fakeKlussen());
    expect(find.byType(KlussenHomeScreen), findsOneWidget);
    expect(find.byType(KlusTegel), findsNWidgets(4));
  });

  testWidgets('filteren op soort en dagdeel, en filters wissen', (
    tester,
  ) async {
    await pompKlussenApp(tester, klussenGateway: fakeKlussen());

    // Soort: tuin (de fake-klustypes van het profiel heten zo).
    await tikTekst(tester, 'Tuin');
    expect(find.byType(KlusTegel), findsNWidgets(2));
    expect(find.text(TekstenKlussenNl.j11Aantal(2)), findsOneWidget);

    // Plus dagdeel ochtend: geen tuinklus in de ochtend.
    await tikTekst(tester, TekstenKlussenNl.dagdeelOchtend);
    expect(find.byType(KlusTegel), findsNothing);
    expect(find.text(TekstenKlussenNl.j11LeegGefilterd), findsOneWidget);

    // Wissen (de knop in de lege staat; de filterbalk heeft er ook een).
    final wissen = find.widgetWithText(HhKnop, TekstenKlussenNl.filterWissen);
    expect(wissen, findsNWidgets(2));
    await tester.ensureVisible(wissen.last);
    await tester.tap(wissen.last);
    await tester.pumpAndSettle();
    expect(find.byType(KlusTegel), findsNWidgets(4));

    // Alleen dagdeel avond.
    await tikTekst(tester, TekstenKlussenNl.dagdeelAvond);
    expect(find.byType(KlusTegel), findsOneWidget);
    expect(
      find.text('donderdag 17 september van 18:30 tot 19:30'),
      findsOneWidget,
    );
  });

  // B5: niet meer aannemen maar reageren; de bewoner kiest.
  testWidgets(
    'reageren: berichtje mee, "Reactie verstuurd", daarna bij Gereageerd',
    (tester) async {
      final reacties = FakeReactieGateway(helperId: jongereId);
      await pompKlussenApp(
        tester,
        klussenGateway: fakeKlussen(),
        reactieGateway: reacties,
      );

      await tikEersteTegel(tester);
      expect(find.byType(KlusDetailScreen), findsOneWidget);
      expect(find.text(TekstenKlussenNl.buurtbewoner), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenKlussenNl.j13Aannemen),
        findsNothing,
      );

      await tester.enterText(
        find.byType(TextField).first,
        'Ik heb al vaker boodschappen gedaan.',
      );
      await tikKnop(tester, TekstenReactiesNl.reageerKnop);

      expect(reacties.verstuurd.single.klusId, 'k-ochtend');
      expect(
        reacties.verstuurd.single.bericht,
        'Ik heb al vaker boodschappen gedaan.',
      );
      expect(find.byType(ReactieVerstuurdScreen), findsOneWidget);
      expect(find.text(TekstenReactiesNl.verstuurdKop), findsOneWidget);
      expect(find.text(TekstenReactiesNl.verstuurdUitleg), findsOneWidget);

      await tikKnop(tester, TekstenReactiesNl.naarMijnKlussen);
      expect(find.byType(MijnKlussenScreen), findsOneWidget);
      await tikTekst(tester, TekstenReactiesNl.tabGereageerd);
      expect(find.byType(ReactieTegel), findsOneWidget);
      expect(find.text(TekstenReactiesNl.standWachtBewoner), findsOneWidget);
    },
  );

  testWidgets('helper onder 18: "Wacht op je ouder", en intrekken kan', (
    tester,
  ) async {
    final reacties = FakeReactieGateway(
      helperId: jongereId,
      helperOnder18: true,
    );
    await pompKlussenApp(
      tester,
      klussenGateway: fakeKlussen(),
      reactieGateway: reacties,
    );
    await tikEersteTegel(tester);
    await tikKnop(tester, TekstenReactiesNl.reageerKnop);
    expect(find.text(TekstenReactiesNl.verstuurdOuderUitleg), findsOneWidget);
    expect(find.text(TekstenReactiesNl.pilOuder), findsOneWidget);

    // Terug gaat naar de lijst; de klus opnieuw openen toont de stand.
    await tikTekst(tester, TekstenNl.terug);
    expect(find.byType(KlussenHomeScreen), findsOneWidget);
    await tikEersteTegel(tester);
    expect(find.text(TekstenReactiesNl.gereageerdKop), findsOneWidget);
    expect(find.text(TekstenReactiesNl.gereageerdOuder), findsOneWidget);
    await tikKnop(tester, TekstenReactiesNl.intrekken);
    await tikTekst(tester, TekstenReactiesNl.intrekkenJa);
    expect(reacties.ingetrokken, hasLength(1));
    expect(find.text(TekstenReactiesNl.ingetrokken), findsOneWidget);
  });

  testWidgets('onder 18 nog dicht: een rustige balk, geen foutmelding', (
    tester,
  ) async {
    final reacties = FakeReactieGateway(helperId: jongereId)
      ..reageerUitkomst = const ReageerGeweigerd(
        'onder18',
        'Fijn dat je wilt helpen! Helpers onder de 18 kunnen nog even niet '
            'reageren.',
      );
    await pompKlussenApp(
      tester,
      klussenGateway: fakeKlussen(),
      reactieGateway: reacties,
    );
    await tikEersteTegel(tester);
    await tikKnop(tester, TekstenReactiesNl.reageerKnop);
    final balk = tester.widget<HhMeldBalk>(find.byType(HhMeldBalk));
    expect(balk.soort, HhMeldSoort.informatie);
    expect(find.textContaining('Fijn dat je wilt helpen'), findsOneWidget);
    expect(find.byType(ReactieVerstuurdScreen), findsNothing);
  });

  testWidgets('een weigering toont de melding van de server', (tester) async {
    final reacties = FakeReactieGateway(helperId: jongereId)
      ..reageerUitkomst = const ReageerGeweigerd(
        'bezet',
        'Deze klus heeft al een helper.',
      );
    await pompKlussenApp(
      tester,
      klussenGateway: fakeKlussen(),
      reactieGateway: reacties,
    );
    await tikEersteTegel(tester);
    await tikKnop(tester, TekstenReactiesNl.reageerKnop);
    expect(find.byType(HhMeldBalk), findsOneWidget);
    expect(find.text('Deze klus heeft al een helper.'), findsOneWidget);
    expect(find.byType(KlusDetailScreen), findsOneWidget);
  });

  testWidgets(
    'eerste klus (10-12 jaar): de server vraagt het vinkje, daarna gaat het mee',
    (tester) async {
      final reacties = FakeReactieGateway(helperId: jongereId)
        ..reageerUitkomst = const ReageerGeweigerd(
          'oudermee',
          'Dit is je eerste klus bij deze bewoner. Zet het vinkje.',
        );
      await pompKlussenApp(
        tester,
        klussenGateway: fakeKlussen(),
        reactieGateway: reacties,
      );
      await tikEersteTegel(tester);
      await tikKnop(tester, TekstenReactiesNl.reageerKnop);
      expect(find.text(TekstenReactiesNl.ouderMeeVinkje), findsOneWidget);

      // Zonder vinkje stuurt de app niets nog eens.
      await tikKnop(tester, TekstenReactiesNl.reageerKnop);
      expect(find.text(TekstenReactiesNl.ouderMeeNodig), findsOneWidget);
      expect(reacties.verstuurd, hasLength(1));

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenReactiesNl.reageerKnop);
      expect(reacties.verstuurd.last.ouderGaatMee, isTrue);
      expect(find.byType(ReactieVerstuurdScreen), findsOneWidget);
    },
  );

  testWidgets('reageren zonder verbinding toont de netwerkmelding', (
    tester,
  ) async {
    final reacties = FakeReactieGateway(helperId: jongereId);
    await pompKlussenApp(
      tester,
      klussenGateway: fakeKlussen(),
      reactieGateway: reacties,
    );
    await tikEersteTegel(tester);

    reacties.isOffline = true;
    await tikKnop(tester, TekstenReactiesNl.reageerKnop);
    expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
    expect(
      find.widgetWithText(HhKnop, TekstenReactiesNl.reageerKnop),
      findsOneWidget,
    );
  });

  testWidgets('kaart toont markers en opent J13', (tester) async {
    final container = await pompKlussenApp(
      tester,
      klussenGateway: fakeKlussen(),
    );
    await tikTekst(tester, TekstenKlussenNl.weergaveKaart);
    expect(find.byType(KlussenKaart), findsOneWidget);
    expect(find.byType(KlusMarker), findsNWidgets(3));
    expect(container.read(kaartTegelsProvider)(), isA<NepTegels>());

    await tester.tap(find.byType(KlusMarker).first);
    await tester.pumpAndSettle();
    expect(find.byType(KlusDetailScreen), findsOneWidget);
  });

  testWidgets(
    'guard: niet-goedgekeurde jongere komt via /jongere/mijn-klussen op J9',
    (tester) async {
      await pompKlussenApp(
        tester,
        klussenGateway: fakeKlussen(),
        profielGateway: fakeJongereKlaarOmInTeDienen(),
      );
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
    },
  );

  testWidgets('uitloggen via de tab Instellingen', (tester) async {
    await pompKlussenApp(tester, klussenGateway: fakeKlussen());
    await tikTekst(tester, TekstenKlussenNl.tabInstellingen);
    await tikKnop(tester, TekstenNl.uitloggen);
    await tester.pumpAndSettle();
    expect(find.byType(KlussenHomeScreen), findsNothing);
    expect(
      find.byType(InloggenScreen).evaluate().isNotEmpty ||
          find.text(TekstenNl.alEenAccount).evaluate().isNotEmpty,
      isTrue,
    );
  });
}

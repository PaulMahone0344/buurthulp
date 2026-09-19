import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/klussen_gateway.dart';
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
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
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

  testWidgets(
    'accepteren slaagt: naam en adres komen tevoorschijn, klus staat bij gepland',
    (tester) async {
      final fake = fakeKlussen();
      await pompKlussenApp(tester, klussenGateway: fake);

      await tikEersteTegel(tester);
      expect(find.byType(KlusDetailScreen), findsOneWidget);
      expect(find.text(TekstenKlussenNl.buurtbewoner), findsOneWidget);

      // M6 (M5 OPEN-PUNT 80): eerst de bevestigingsvraag.
      await tikKnop(tester, TekstenKlussenNl.j13Aannemen);
      expect(find.text(TekstenUitvoerenNl.j13BevestigVraag), findsOneWidget);
      await tikKnop(tester, TekstenUitvoerenNl.j13BevestigJa);

      expect(fake.geaccepteerdeIds, ['k-ochtend']);
      expect(find.text(TekstenKlussenNl.j13Aangenomen), findsOneWidget);
      expect(find.text('Mevrouw de Vries'), findsOneWidget);
      expect(find.textContaining('Prins Bernhardlaan'), findsOneWidget);
      expect(find.text(TekstenKlussenNl.statusGeaccepteerd), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenKlussenNl.j13Aannemen),
        findsNothing,
      );

      await tikKnop(tester, TekstenKlussenNl.j13NaarMijnKlussen);
      expect(find.byType(MijnKlussenScreen), findsOneWidget);
      await tikTekst(tester, TekstenKlussenNl.j14TabGepland);
      expect(find.byType(KlusTegel), findsOneWidget);
      expect(find.text('morgen van 09:00 tot 10:00'), findsOneWidget);

      // Terug naar de klussen: de aangenomen klus staat niet meer in de lijst.
      await tikTekst(tester, TekstenKlussenNl.tabKlussen);
      expect(find.byType(KlusTegel), findsNWidgets(3));
    },
  );

  testWidgets(
    'accepteren met 409 toont de melding van de server en ververst de lijst',
    (tester) async {
      final fake = fakeKlussen();
      await pompKlussenApp(tester, klussenGateway: fake);
      expect(fake.aantalOpenAanvragen, 1);

      await tikEersteTegel(tester);

      // Intussen neemt iemand anders de klus aan; de server antwoordt 409.
      fake.neemAanDoorAnder('k-ochtend');
      fake.accepteerUitkomst = const Geweigerd(
        AccepteerReden.bezet,
        melding: 'Deze klus is net door iemand anders aangenomen.',
      );

      await tikKnop(tester, TekstenKlussenNl.j13Aannemen);
      await tikKnop(tester, TekstenUitvoerenNl.j13BevestigJa);

      expect(fake.geaccepteerdeIds, isEmpty);
      expect(find.byType(HhMeldBalk), findsOneWidget);
      expect(
        find.text('Deze klus is net door iemand anders aangenomen.'),
        findsOneWidget,
      );
      expect(find.byType(KlusDetailScreen), findsOneWidget);
      // M5 OPEN-PUNT 81: na een 409 verdwijnt de knop.
      expect(
        find.widgetWithText(HhKnop, TekstenKlussenNl.j13Aannemen),
        findsNothing,
      );
      // De lijst is opnieuw opgehaald ...
      expect(fake.aantalOpenAanvragen, 2);

      // ... en toont bij terugkeer nog drie klussen.
      // De terugknop staat links; tik op het woord, niet op het midden van
      // de (volle) rij.
      await tikTekst(tester, TekstenNl.terug);
      expect(find.byType(KlussenHomeScreen), findsOneWidget);
      expect(find.byType(KlusTegel), findsNWidgets(3));
    },
  );

  testWidgets('accepteren zonder verbinding toont de netwerkmelding', (
    tester,
  ) async {
    final fake = fakeKlussen();
    await pompKlussenApp(tester, klussenGateway: fake);
    await tikEersteTegel(tester);

    fake.isOffline = true;
    await tikKnop(tester, TekstenKlussenNl.j13Aannemen);
    await tikKnop(tester, TekstenUitvoerenNl.j13BevestigJa);
    expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
    expect(
      find.widgetWithText(HhKnop, TekstenKlussenNl.j13Aannemen),
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

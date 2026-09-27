import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/widget/hulpvraag_tegel.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/screen/klus_uitvoeren_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/klus_tegel.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../support/hh_jongere_wikkel.dart';
import '../support/hh_klussen_wikkel.dart';
import '../support/hh_uitvoeren_wikkel.dart';

Future<void> _vulVeld(WidgetTester tester, String tekst) async {
  final veld = find.byType(TextField).first;
  await tester.ensureVisible(veld);
  await tester.enterText(veld, tekst);
  await tester.pumpAndSettle();
}

void main() {
  group('J15: de hele reeks', () {
    testWidgets('geaccepteerd -> onderweg -> aangekomen -> afgerond', (
      tester,
    ) async {
      final fake = fakeUitvoer(status: HhKlusStatus.geaccepteerd);
      await tester.pumpWidget(
        hhUitvoerenWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenUitvoerenNl.j15KnopOnderweg);
      expect(fake.klusVan('k-uitvoeren')!.status, HhKlusStatus.onderweg);
      expect(find.byType(HhMeldBalk), findsOneWidget);

      await tikKnop(tester, TekstenUitvoerenNl.j15KnopAangekomen);
      expect(fake.klusVan('k-uitvoeren')!.status, HhKlusStatus.bezig);

      await tikKnop(tester, TekstenUitvoerenNl.j15KnopAfgerond);
      expect(fake.klusVan('k-uitvoeren')!.status, HhKlusStatus.afgerond);

      // Drie stappen, drie logregels erbij.
      expect(fake.gezetteStappen, ['onderweg', 'bezig', 'afgerond']);
      expect(
        fake.alleLogregels.where((l) => l.klusId == 'k-uitvoeren').length,
        5,
      );

      // Rustige eindstaat zonder stapknop; beoordelen (M7) test
      // beoordelen_flow_test.
      expect(find.text(TekstenUitvoerenNl.j15Afgerond), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.j15KnopAfgerond),
        findsNothing,
      );
    });

    testWidgets('409 bij onderweg: meldbalk en het scherm laadt opnieuw', (
      tester,
    ) async {
      final fake = fakeUitvoer(status: HhKlusStatus.geaccepteerd);
      await tester.pumpWidget(
        hhUitvoerenWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();

      // Intussen is de klus ergens anders al doorgezet; de server weigert.
      fake.volgendeUitkomst = const UitvoerGeweigerd(
        UitvoerReden.nietMeerMogelijk,
        melding: 'Deze stap kan nu niet meer. Ververs het scherm.',
      );
      await tikKnop(tester, TekstenUitvoerenNl.j15KnopOnderweg);

      expect(find.byType(HhMeldBalk), findsOneWidget);
      expect(
        find.text('Deze stap kan nu niet meer. Ververs het scherm.'),
        findsOneWidget,
      );
      // De status is niet gewijzigd en er kwam geen logregel bij.
      expect(fake.klusVan('k-uitvoeren')!.status, HhKlusStatus.geaccepteerd);
      expect(
        fake.alleLogregels.where((l) => l.klusId == 'k-uitvoeren').length,
        2,
      );
      expect(find.byType(KlusUitvoerenScreen), findsOneWidget);
    });
  });

  group('J15: annuleren door de jongere', () {
    testWidgets('reden verplicht; te kort komt niet bij de server', (
      tester,
    ) async {
      final fake = fakeUitvoer(status: HhKlusStatus.geaccepteerd);
      await tester.pumpWidget(
        hhUitvoerenWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenUitvoerenNl.j15Annuleren);
      await _vulVeld(tester, 'oei');
      await tikKnop(tester, TekstenUitvoerenNl.annuleerBevestigJongere);

      expect(
        find.text(TekstenUitvoerenNl.annuleerRedenTeKort(5)),
        findsOneWidget,
      );
      expect(fake.aantalAnnuleringen, 0);
      expect(fake.klusVan('k-uitvoeren')!.status, HhKlusStatus.geaccepteerd);
    });

    testWidgets(
      'met reden: de klus gaat terug naar open en is niet meer van mij',
      (tester) async {
        final fake = fakeUitvoer(status: HhKlusStatus.onderweg);
        await tester.pumpWidget(
          hhUitvoerenWikkel(
            HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
            uitvoerGateway: fake,
          ),
        );
        await tester.pumpAndSettle();

        await tikKnop(tester, TekstenUitvoerenNl.j15Annuleren);
        await _vulVeld(tester, 'Ik ben ziek geworden.');
        await tikKnop(tester, TekstenUitvoerenNl.annuleerBevestigJongere);

        final klus = fake.klusVan('k-uitvoeren')!;
        expect(klus.status, HhKlusStatus.open);
        expect(klus.toegewezenJongereId, isEmpty);

        // De reden staat in de logregel.
        final laatste = fake.alleLogregels.last;
        expect(laatste.naar, HhKlusStatus.open);
        expect(laatste.toelichting, 'Ik ben ziek geworden.');

        // Het scherm zegt dat de klus niet meer van hem is.
        expect(find.text(TekstenUitvoerenNl.j15Geannuleerd), findsWidgets);
      },
    );
  });

  group('J16: bellen', () {
    testWidgets('zonder nummer een nette melding, geen nummer op het scherm', (
      tester,
    ) async {
      final fake = fakeUitvoer(status: HhKlusStatus.onderweg, nummer: '');
      await tester.pumpWidget(
        hhUitvoerenWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenUitvoerenNl.j15Bellen);
      expect(fake.aantalBelVerzoeken, 1);
      expect(find.text(TekstenUitvoerenNl.belGeenNummer), findsOneWidget);
    });

    testWidgets('met nummer: bevestigregel met de naam, nummer onzichtbaar', (
      tester,
    ) async {
      final fake = fakeUitvoer(status: HhKlusStatus.onderweg);
      await tester.pumpWidget(
        hhUitvoerenWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenUitvoerenNl.j15Bellen);
      expect(
        find.text(TekstenUitvoerenNl.belBevestiging(testOudereNaam)),
        findsOneWidget,
      );
      // Het nummer zelf komt nergens als tekst op het scherm.
      expect(find.textContaining('06-'), findsNothing);
    });
  });

  group('J14 -> J15 in de echte app', () {
    testWidgets('annuleren door de jongere haalt de klus uit Mijn klussen', (
      tester,
    ) async {
      // De klussen-fake (M5) voedt J14; de uitvoer-fake (M6) voedt J15.
      final mijn = [
        uitvoerKlus(
          id: 'm-vandaag',
          status: HhKlusStatus.geaccepteerd,
          wanneerVan: uitvoerNu.add(const Duration(hours: 5)),
        ),
      ];
      final klussen = fakeKlussen(open: const [], mijn: mijn);
      final uitvoer = fakeUitvoer(klussen: mijn);
      await pompKlussenApp(
        tester,
        klussenGateway: klussen,
        uitvoerGateway: uitvoer,
        nu: uitvoerNu,
      );

      await tikTekst(tester, TekstenKlussenNl.tabMijnKlussen);
      expect(find.byType(KlusTegel), findsOneWidget);

      // Tik op de lopende klus: J15.
      await tester.tap(find.byType(KlusTegel).first);
      await tester.pumpAndSettle();
      expect(find.byType(KlusUitvoerenScreen), findsOneWidget);

      // Teruggeven met een reden.
      await tikKnop(tester, TekstenUitvoerenNl.j15Annuleren);
      await _vulVeld(tester, 'Ik ben ziek geworden.');
      await tikKnop(tester, TekstenUitvoerenNl.annuleerBevestigJongere);

      // De M5-lijst is opnieuw opgehaald; de klus is niet meer van hem.
      klussen.zetKlus(
        mijn.first.copyWith(status: HhKlusStatus.open, toegewezenJongereId: ''),
      );
      await tikTekst(tester, TekstenNl.terug);
      await tikTekst(tester, TekstenKlussenNl.j14TabVandaag);
      expect(find.byType(KlusTegel), findsNothing);
      expect(find.text(TekstenKlussenNl.j14LeegVandaag), findsOneWidget);
    });
  });

  group('O7: de oudere volgt zijn hulpvraag', () {
    testWidgets('een realtime-wissel is meteen zichtbaar', (tester) async {
      final fake = fakeUitvoer(
        status: HhKlusStatus.geaccepteerd,
        ikBen: oudereId,
      );
      await tester.pumpWidget(
        hhStatusWikkel(
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sanne komt u helpen.'), findsOneWidget);

      // De jongere zet zijn klus op onderweg; dat komt via realtime binnen.
      fake.zendUit(
        fake.klusVan('k-uitvoeren')!.copyWith(status: HhKlusStatus.onderweg),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sanne is onderweg naar u.'), findsOneWidget);
      expect(find.text('Sanne komt u helpen.'), findsNothing);
    });

    testWidgets('annuleren met een vaste reden, zonder typen', (tester) async {
      final fake = fakeUitvoer(
        status: HhKlusStatus.geaccepteerd,
        ikBen: oudereId,
      );
      await tester.pumpWidget(
        hhStatusWikkel(
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenUitvoerenNl.o7Annuleren);
      await tikKnop(tester, TekstenUitvoerenNl.o7RedenOpgelost);
      await tester.pumpAndSettle();

      expect(fake.klusVan('k-uitvoeren')!.status, HhKlusStatus.geannuleerd);
      expect(
        fake.alleLogregels.last.toelichting,
        TekstenUitvoerenNl.o7RedenOpgelostZin,
      );
      expect(find.text(TekstenUitvoerenNl.o7AnnuleerGelukt), findsOneWidget);
      // Daarna is stoppen niet meer mogelijk.
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Annuleren),
        findsNothing,
      );
    });

    testWidgets('afbreken laat de hulpvraag staan', (tester) async {
      final fake = fakeUitvoer(
        status: HhKlusStatus.geaccepteerd,
        ikBen: oudereId,
      );
      await tester.pumpWidget(
        hhStatusWikkel(
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          uitvoerGateway: fake,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenUitvoerenNl.o7Annuleren);
      await tikKnop(tester, TekstenUitvoerenNl.o7AnnuleerAfbreken);

      expect(fake.aantalAnnuleringen, 0);
      expect(fake.klusVan('k-uitvoeren')!.status, HhKlusStatus.geaccepteerd);
    });
  });

  group('O8: van de lijst naar de hulpvraag en terug', () {
    testWidgets('gepland -> O7 -> terug naar de lijst', (tester) async {
      final fake = fakeUitvoer(
        klussen: [
          uitvoerKlus(id: 'a', status: HhKlusStatus.open, metJongere: false),
          uitvoerKlus(id: 'b', status: HhKlusStatus.onderweg),
        ],
        ikBen: oudereId,
      );
      await tester.pumpWidget(
        hhStatusWikkel(HhPadenStatus.hulpvragen, uitvoerGateway: fake),
      );
      await tester.pumpAndSettle();

      await tikTekst(tester, TekstenUitvoerenNl.o8TabGepland);
      await tester.tap(find.byType(HulpvraagTegel).first);
      await tester.pumpAndSettle();
      expect(find.text('Sanne is onderweg naar u.'), findsOneWidget);

      await tikTekst(tester, TekstenNl.terug);
      expect(find.text(TekstenUitvoerenNl.o8Titel), findsOneWidget);
    });
  });
}

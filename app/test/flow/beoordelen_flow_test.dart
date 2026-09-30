import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/pb/beoordeling_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/hulpvrager/beoordelen/paden_beoordelen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/model/hh_beoordeling.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/paden_reputatie.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/widget/sterren_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/l10n/teksten_beoordelen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../support/hh_beoordelen_wikkel.dart';
import '../support/hh_hulpvrager_wikkel.dart';
import '../support/hh_jongere_wikkel.dart';
import '../support/hh_klussen_wikkel.dart';
import '../support/hh_uitvoeren_wikkel.dart';

Future<void> _tikSter(WidgetTester tester, int ster) async {
  final kiezer = find.byType(SterrenKiezer);
  await tester.ensureVisible(kiezer);
  await tester.tap(
    find.descendant(of: kiezer, matching: find.byType(InkWell)).at(ster - 1),
  );
  await tester.pumpAndSettle();
}

Future<void> _trekOmlaag(WidgetTester tester) async {
  await tester.fling(
    find.byType(SingleChildScrollView).last,
    const Offset(0, 400),
    1000,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('de jongere', () {
    testWidgets('J15 afgerond -> J17 geven -> J15 zegt "wijzigen"', (
      tester,
    ) async {
      final beoordeling = fakeBeoordeling();
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.afgerond),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenBeoordelenNl.j15Beoordelen);
      await _tikSter(tester, 5);
      await vulVeld(tester, 0, 'Lieve mevrouw, koffie gehad.');
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);
      expect(find.text(TekstenBeoordelenNl.j17Gelukt), findsOneWidget);
      expect(beoordeling.alleBeoordelingen.single.sterren, 5);

      // Terug naar J15: de knop is nu "wijzigen".
      await tester.tap(find.text(TekstenNl.terug));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j15BeoordelingWijzigen),
        findsOneWidget,
      );
    });

    testWidgets('dubbel (tweede toestel was eerder) -> melding, daarna '
        'wijzigen', (tester) async {
      final beoordeling = fakeBeoordeling();
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenReputatie.beoordelen('k-uitvoeren'),
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.afgerond),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();

      // Terwijl het scherm openstaat, beoordeelt hetzelfde account op een
      // ander toestel: de server heeft er nu al een.
      await beoordeling.geef(
        klusId: 'k-uitvoeren',
        vanId: jongereId,
        naarId: oudereId,
        sterren: 3,
      );

      await _tikSter(tester, 4);
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);
      expect(find.text(TekstenBeoordelenNl.j17AlGegeven), findsOneWidget);
      expect(beoordeling.alleBeoordelingen, hasLength(1));

      // Het scherm weet nu dat er een is: de knop wordt "opslaan" en dat
      // wijzigt de bestaande, geen tweede.
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j17Opslaan),
        findsOneWidget,
      );
      await _tikSter(tester, 4);
      await tikKnop(tester, TekstenBeoordelenNl.j17Opslaan);
      expect(find.text(TekstenBeoordelenNl.j17Gewijzigd), findsOneWidget);
      expect(beoordeling.alleBeoordelingen.single.sterren, 4);
      expect(beoordeling.aantalGewijzigd, 1);
    });

    testWidgets('J14 "Nog beoordelen" verdwijnt na het beoordelen', (
      tester,
    ) async {
      final beoordeling = fakeBeoordeling(
        klussen: [afgerondeKlus(id: 'm-historie')],
      );
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenKlussen.mijnKlussen,
          uitvoerGateway: fakeUitvoer(
            klussen: [afgerondeKlus(id: 'm-historie')],
          ),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();
      await tikTekst(tester, TekstenKlussenNl.j14TabHistorie);
      await tikKnop(tester, TekstenBeoordelenNl.j14NogBeoordelen);
      await _tikSter(tester, 4);
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);
      await tikKnop(tester, TekstenBeoordelenNl.j17NaarMijnKlussen);
      await tikTekst(tester, TekstenKlussenNl.j14TabHistorie);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j14NogBeoordelen),
        findsNothing,
      );
    });
  });

  group('de oudere', () {
    testWidgets('O7 -> "Hoe ging het?" -> duim -> sterren -> bedankt', (
      tester,
    ) async {
      final beoordeling = fakeBeoordeling(ikBen: oudereId);
      await tester.pumpWidget(
        hhBeoordelenWikkel(
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          uitvoerGateway: fakeUitvoer(
            status: HhKlusStatus.afgerond,
            ikBen: oudereId,
          ),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenBeoordelenNl.o7HoeGingHet);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmhoog);
      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      expect(find.text(TekstenBeoordelenNl.o9Bedankt), findsOneWidget);

      final b = beoordeling.alleBeoordelingen.single;
      expect(b.sterren, 5);
      expect(b.tekst, isEmpty);
      expect(b.vanId, oudereId);
      expect(b.naarId, jongereId);
      // De server (hier de fake) rekent: de jongere staat op 5.
      expect(beoordeling.reputatieVan(jongereId).sterrenGemiddeld, 5.0);

      await tikKnop(tester, TekstenBeoordelenNl.o9NaarHulpvragen);
      expect(find.byType(SterrenKiezer), findsNothing);
    });

    testWidgets('dubbel -> "U heeft al een beoordeling gegeven."', (
      tester,
    ) async {
      final beoordeling = fakeBeoordeling(ikBen: oudereId)
        ..volgendeUitkomst = const BeoordelingGeweigerd(
          BeoordelingReden.alGegeven,
        );
      await tester.pumpWidget(
        hhBeoordelenWikkel(
          '${HhPadenStatus.hulpvraag('k-uitvoeren')}/beoordelen',
          uitvoerGateway: fakeUitvoer(
            status: HhKlusStatus.afgerond,
            ikBen: oudereId,
          ),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmlaag);
      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      expect(find.text('U heeft al een beoordeling gegeven.'), findsOneWidget);
      expect(find.text(TekstenBeoordelenNl.o9Bedankt), findsNothing);
    });

    testWidgets('wijzigen: de sterren van de vorige keer staan er al', (
      tester,
    ) async {
      final beoordeling = fakeBeoordeling(
        ikBen: oudereId,
        beoordelingen: [
          HhBeoordeling(
            id: 'b1',
            klusId: 'k-uitvoeren',
            vanId: oudereId,
            naarId: jongereId,
            sterren: 5,
          ),
        ],
      );
      await tester.pumpWidget(
        hhBeoordelenWikkel(
          '${HhPadenStatus.hulpvraag('k-uitvoeren')}/beoordelen',
          uitvoerGateway: fakeUitvoer(
            status: HhKlusStatus.afgerond,
            ikBen: oudereId,
          ),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenBeoordelenNl.woordHeelGoed), findsOneWidget);
      await _tikSter(tester, 2);
      await tikKnop(tester, TekstenBeoordelenNl.o9Opslaan);
      expect(find.text(TekstenBeoordelenNl.o9Bedankt), findsOneWidget);
      expect(beoordeling.alleBeoordelingen.single.sterren, 2);
      expect(beoordeling.aantalGegeven, 0);
      expect(beoordeling.aantalGewijzigd, 1);
    });
  });

  group('J19 toont de nieuwe stand', () {
    testWidgets('na een nieuwe beoordeling op de server en verversen', (
      tester,
    ) async {
      final beoordeling = fakeBeoordeling(
        klussen: [
          afgerondeKlus(id: 'a'),
          afgerondeKlus(id: 'b'),
        ],
        beoordelingen: [
          HhBeoordeling(
            id: 'b-a',
            klusId: 'a',
            vanId: oudereId,
            naarId: jongereId,
            sterren: 5,
            tekst: 'Top!',
            gemaakt: DateTime.utc(2026, 9, 1),
          ),
        ],
      );
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenKlussen.profiel,
          uitvoerGateway: fakeUitvoer(),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(TekstenBeoordelenNl.j19Gemiddeld('5,0')),
        findsOneWidget,
      );

      // De oudere beoordeelt klus b met 4 sterren en een tekst.
      beoordeling.ikBenId = oudereId;
      await beoordeling.geef(
        klusId: 'b',
        vanId: oudereId,
        naarId: jongereId,
        sterren: 4,
        tekst: 'Goed geholpen met de tuin.',
      );
      beoordeling.ikBenId = jongereId;

      await _trekOmlaag(tester);
      expect(
        find.text(TekstenBeoordelenNl.j19Gemiddeld('4,5')),
        findsOneWidget,
      );
      expect(find.text('Goed geholpen met de tuin.'), findsOneWidget);
      expect(find.text(TekstenBeoordelenNl.j19Klussen(2)), findsOneWidget);
    });
  });

  group('de echte router (met guard) kent de M7-routes', () {
    testWidgets('jongere: J17 onder /jongere/klus/:id/beoordelen', (
      tester,
    ) async {
      final container = await pompKlussenApp(
        tester,
        klussenGateway: fakeKlussen(mijn: testMijnKlussen()),
        uitvoerGateway: fakeUitvoer(status: HhKlusStatus.afgerond),
        beoordelingGateway: fakeBeoordeling(),
      );
      container
          .read(routerProvider)
          .go(HhPadenReputatie.beoordelen('k-uitvoeren'));
      await tester.pumpAndSettle();
      expect(find.text(TekstenBeoordelenNl.j17Titel), findsOneWidget);
      expect(find.byType(SterrenKiezer), findsOneWidget);
    });

    testWidgets('oudere: O9 onder /hulpvrager/hulpvragen/:id/beoordelen', (
      tester,
    ) async {
      final container = await pompHulpvragerApp(
        tester,
        klusGateway: fakeKlusGateway(),
        uitvoerGateway: fakeUitvoer(
          status: HhKlusStatus.afgerond,
          ikBen: oudereId,
        ),
        beoordelingGateway: fakeBeoordeling(ikBen: oudereId),
      );
      container
          .read(routerProvider)
          .go(HhPadenBeoordelen.beoordelen('k-uitvoeren'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.o9DuimOmhoog),
        findsOneWidget,
      );
    });
  });
}

import 'package:heitjehulp_app/l10n/teksten_reacties_nl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/fake_beoordeling_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/features/hulpvrager/beoordelen/paden_beoordelen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/model/hh_beoordeling.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/paden_reputatie.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/widget/sterren_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/l10n/teksten_beoordelen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_jongere_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_beoordelen_wikkel.dart';
import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_uitvoeren_wikkel.dart';

/// Een beoordeling van de oudere naar de jongere (voor J19 en O9 wijzigen).
HhBeoordeling _vanOudere(
  String klusId,
  int sterren, {
  String tekst = '',
  int minuut = 0,
}) => HhBeoordeling(
  id: 'b-$klusId-oudere',
  klusId: klusId,
  vanId: oudereId,
  naarId: jongereId,
  sterren: sterren,
  tekst: tekst,
  gemaakt: DateTime.utc(2026, 9, 10, 8, minuut),
);

/// Een beoordeling van de jongere naar de oudere (voor J17 wijzigen).
HhBeoordeling _vanJongere(String klusId, int sterren, {String tekst = ''}) =>
    HhBeoordeling(
      id: 'b-$klusId-jongere',
      klusId: klusId,
      vanId: jongereId,
      naarId: oudereId,
      sterren: sterren,
      tekst: tekst,
    );

/// Elk M7-scherm in de staat die het nodig heeft.
class _Geval {
  const _Geval(this.naam, this.pad, this.fake, {this.isOudere = false});

  final String naam;
  final String pad;
  final FakeBeoordelingGateway Function() fake;
  final bool isOudere;
}

final _j17 = HhPadenReputatie.beoordelen('k-uitvoeren');
final _o9 = HhPadenBeoordelen.beoordelen('k-uitvoeren');

final _gevallen = [
  _Geval('J17 nieuw', _j17, () => fakeBeoordeling()),
  _Geval(
    'J17 wijzigen',
    _j17,
    () => fakeBeoordeling(
      beoordelingen: [_vanJongere('k-uitvoeren', 4, tekst: 'Aardig.')],
    ),
  ),
  _Geval(
    'J19 met beoordelingen',
    HhPadenKlussen.profiel,
    () => fakeBeoordeling(
      klussen: [
        afgerondeKlus(id: 'a'),
        afgerondeKlus(id: 'b'),
        afgerondeKlus(id: 'c'),
      ],
      beoordelingen: [
        _vanOudere('a', 5, tekst: 'Heel behulpzaam.', minuut: 1),
        _vanOudere('b', 4, minuut: 2),
        _vanOudere('c', 4, tekst: 'Kwam netjes op tijd.', minuut: 3),
      ],
    ),
  ),
  _Geval(
    'J19 nog leeg',
    HhPadenKlussen.profiel,
    () => fakeBeoordeling(klussen: const []),
  ),
  _Geval(
    'O9 duim',
    _o9,
    () => fakeBeoordeling(ikBen: oudereId),
    isOudere: true,
  ),
  _Geval(
    'O9 wijzigen',
    _o9,
    () => fakeBeoordeling(
      ikBen: oudereId,
      beoordelingen: [_vanOudere('k-uitvoeren', 4)],
    ),
    isOudere: true,
  ),
];

Future<FakeBeoordelingGateway> _pomp(
  WidgetTester tester,
  _Geval geval, {
  HhDichtheid? dichtheid,
  double tekstschaal = 1.0,
}) async {
  final fake = geval.fake();
  final uitvoer = fakeUitvoer(
    klussen: [afgerondeKlus()],
    ikBen: geval.isOudere ? oudereId : jongereId,
  );
  await tester.pumpWidget(
    geval.isOudere
        ? hhBeoordelenWikkel(
            geval.pad,
            uitvoerGateway: uitvoer,
            beoordelingGateway: fake,
            dichtheid: dichtheid ?? HhDichtheid.groot,
            tekstschaal: tekstschaal,
          )
        : hhReputatieWikkel(
            geval.pad,
            uitvoerGateway: uitvoer,
            beoordelingGateway: fake,
            dichtheid: dichtheid ?? HhDichtheid.normaal,
            tekstschaal: tekstschaal,
          ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Tikt op ster [ster] (1-5) van de eerste sterrenkiezer.
Future<void> tikSter(WidgetTester tester, int ster) async {
  final kiezer = find.byType(SterrenKiezer);
  await tester.ensureVisible(kiezer);
  final vlakken = find.descendant(of: kiezer, matching: find.byType(InkWell));
  await tester.tap(vlakken.at(ster - 1));
  await tester.pumpAndSettle();
}

/// Het aantal keuzes op het scherm: elke knop, en de sterrenkiezer als één
/// keuze (vijf tikvlakken voor één vraag).
int _keuzes() =>
    find.byType(HhKnop).evaluate().length +
    find.byType(SterrenKiezer).evaluate().length;

void main() {
  group('elk M7-scherm rendert in beide dichtheden met semantiek', () {
    for (final geval in _gevallen) {
      for (final dichtheid in HhDichtheid.values) {
        testWidgets('${geval.naam} (${dichtheid.name})', (tester) async {
          final handle = tester.ensureSemantics();
          await _pomp(tester, geval, dichtheid: dichtheid);
          expect(tester.takeException(), isNull);
          controleerSemantiek(tester);
          handle.dispose();
        });
      }
    }

    for (final geval in _gevallen) {
      testWidgets('${geval.naam} op 200 procent zonder overloop', (
        tester,
      ) async {
        await _pomp(
          tester,
          geval,
          dichtheid: HhDichtheid.groot,
          tekstschaal: 2.0,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('O9 sterren en bedankt op 200 procent zonder overloop', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[4], tekstschaal: 2.0);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmhoog);
      expect(tester.takeException(), isNull);
      await beantwoordGeheim(tester);
      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      expect(find.text(TekstenBeoordelenNl.o9Bedankt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('O9 eerlijk tegen de oudere', () {
    testWidgets('bij het tekstvak: de jongere kan dit lezen, zonder cijfer', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[4]);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmhoog);
      expect(find.text(TekstenBeoordelenNl.o9TekstHulp), findsOneWidget);
      expect(TekstenBeoordelenNl.o9TekstHulp, isNot(contains(RegExp(r'\d'))));
    });
  });

  group('de sterrenkiezer', () {
    testWidgets('elke ster is een tikvlak zo hoog als een knop, met een '
        'label en een gekozen-staat', (tester) async {
      final handle = tester.ensureSemantics();
      await _pomp(tester, _gevallen[0]);
      final vlakken = find.descendant(
        of: find.byType(SterrenKiezer),
        matching: find.byType(InkWell),
      );
      expect(vlakken, findsNWidgets(5));
      for (final vlak in vlakken.evaluate()) {
        final maat = tester.getSize(find.byWidget(vlak.widget));
        expect(maat.height, greaterThanOrEqualTo(48));
      }
      await tikSter(tester, 4);
      expect(
        find.bySemanticsLabel(
          TekstenBeoordelenNl.sterrenSemantiek(
            4,
            TekstenBeoordelenNl.woordGoed,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(TekstenBeoordelenNl.woordGoed), findsOneWidget);
      handle.dispose();
    });
  });

  group('J17 beoordeling geven (jongere)', () {
    testWidgets('sterren en tekst gaan samen naar de server', (tester) async {
      final fake = await _pomp(tester, _gevallen[0]);
      expect(
        find.text(TekstenBeoordelenNl.j17Vraag(testOudereNaam)),
        findsOneWidget,
      );
      await tikSter(tester, 4);
      await vulVeld(tester, 0, 'Gezellig gesprek gehad.');
      await beantwoordGeheim(tester);
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);

      final b = fake.alleBeoordelingen.single;
      expect(b.sterren, 4);
      expect(b.tekst, 'Gezellig gesprek gehad.');
      expect(b.vanId, jongereId);
      expect(b.naarId, oudereId);
      expect(find.text(TekstenBeoordelenNl.j17Gelukt), findsOneWidget);
    });

    // B5 (punt 11): de geheime vraag, alleen voor de meldkamer.
    testWidgets('zonder antwoord op "Voelde je je veilig?" gaat er niets weg', (
      tester,
    ) async {
      final fake = await _pomp(tester, _gevallen[0]);
      expect(find.text(TekstenReactiesNl.geheimVraagHelper), findsOneWidget);
      expect(find.text(TekstenReactiesNl.geheimUitleg), findsOneWidget);
      await tikSter(tester, 4);
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);
      expect(fake.aantalGegeven, 0);
      expect(find.text(TekstenReactiesNl.geheimKies), findsOneWidget);
    });

    testWidgets('"Nee" met uitleg gaat mee naar de server (alleen meldkamer)', (
      tester,
    ) async {
      final fake = await _pomp(tester, _gevallen[0]);
      await tikSter(tester, 3);
      await beantwoordGeheim(tester, ja: false);
      expect(
        find.text(TekstenReactiesNl.geheimToelichtingLabel),
        findsOneWidget,
      );
      await vulVeld(tester, 1, 'Hij werd boos.');
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);
      final g = fake.geheim.single;
      expect(g.allesInOrde, isFalse);
      expect(g.toelichting, 'Hij werd boos.');
      expect(find.text(TekstenReactiesNl.geheimNeeBedankt), findsOneWidget);
    });

    testWidgets('zonder sterren gaat er niets weg', (tester) async {
      final fake = await _pomp(tester, _gevallen[0]);
      await beantwoordGeheim(tester);
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);
      expect(fake.aantalGegeven, 0);
      expect(find.text(TekstenBeoordelenNl.kiesSterren), findsOneWidget);
    });

    testWidgets('meer dan 500 tekens: fout bij het veld, niets verstuurd', (
      tester,
    ) async {
      final fake = await _pomp(tester, _gevallen[0]);
      await tikSter(tester, 5);
      await vulVeld(tester, 0, 'a' * 501);
      await beantwoordGeheim(tester);
      await tikKnop(tester, TekstenBeoordelenNl.j17Versturen);
      expect(fake.aantalGegeven, 0);
      expect(find.text(TekstenBeoordelenNl.tekstTeLang), findsOneWidget);
    });

    testWidgets('een bestaande beoordeling staat al ingevuld', (tester) async {
      await _pomp(tester, _gevallen[1]);
      expect(find.text(TekstenBeoordelenNl.j17BestaandUitleg), findsOneWidget);
      expect(find.text('Aardig.'), findsOneWidget);
      expect(find.text(TekstenBeoordelenNl.woordGoed), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j17Opslaan),
        findsOneWidget,
      );
    });

    testWidgets('een klus die nog loopt kan niet beoordeeld worden', (
      tester,
    ) async {
      final fake = fakeBeoordeling();
      await tester.pumpWidget(
        hhReputatieWikkel(
          _j17,
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.bezig),
          beoordelingGateway: fake,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenBeoordelenNl.nietAfgerond), findsOneWidget);
      expect(find.byType(SterrenKiezer), findsNothing);
    });
  });

  group('J19 mijn profiel en reputatie', () {
    testWidgets('gemiddelde en aantal van de server, laatste teksten eerst', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[2]);
      // 5 + 4 + 4 = 13 / 3 = 4,33 -> de server zet 4,3.
      expect(
        find.text(TekstenBeoordelenNl.j19Gemiddeld('4,3')),
        findsOneWidget,
      );
      expect(find.text(TekstenBeoordelenNl.j19Klussen(3)), findsOneWidget);
      final nieuwste = tester.getTopLeft(find.text('Kwam netjes op tijd.'));
      final oudste = tester.getTopLeft(find.text('Heel behulpzaam.'));
      expect(nieuwste.dy, lessThan(oudste.dy));
    });

    testWidgets('zonder beoordelingen: rustig uitgelegd', (tester) async {
      await _pomp(tester, _gevallen[3]);
      expect(find.text(TekstenBeoordelenNl.j19NogGeenSterren), findsOneWidget);
      expect(find.text(TekstenBeoordelenNl.j19GeenTeksten), findsOneWidget);
      expect(find.text(TekstenBeoordelenNl.j19Klussen(0)), findsOneWidget);
    });

    testWidgets('"Mijn screening" opent J9', (tester) async {
      await _pomp(tester, _gevallen[3]);
      await tikKnop(tester, TekstenBeoordelenNl.j19Screening);
      expect(find.text(TekstenJongereNl.j9Titel), findsOneWidget);
    });

    testWidgets('een laadfout toont de lege staat met opnieuw proberen', (
      tester,
    ) async {
      final fake = fakeBeoordeling()..isOffline = true;
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenKlussen.profiel,
          uitvoerGateway: fakeUitvoer(),
          beoordelingGateway: fake,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenBeoordelenNl.j19LadenMislukt), findsOneWidget);
      fake.isOffline = false;
      await tikKnop(tester, TekstenNl.opnieuwProberen);
      expect(find.text(TekstenBeoordelenNl.j19NogGeenSterren), findsOneWidget);
    });
  });

  group('O9 beoordeling geven (oudere)', () {
    testWidgets('elke stap hoogstens drie keuzes, altijd een terugknop', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[4]);
      expect(_keuzes(), lessThanOrEqualTo(3), reason: 'stap duim');
      expect(find.text(TekstenNl.terug), findsOneWidget);

      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmhoog);
      expect(find.byType(SterrenKiezer), findsOneWidget);
      expect(_keuzes(), lessThanOrEqualTo(3), reason: 'stap sterren');
      expect(find.text(TekstenNl.terug), findsOneWidget);

      await beantwoordGeheim(tester);

      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      expect(_keuzes(), lessThanOrEqualTo(3), reason: 'stap bedankt');
    });

    testWidgets('O9: "Was alles in orde?" nee -> de meldkamer belt', (
      tester,
    ) async {
      final fake = await _pomp(tester, _gevallen[4]);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmlaag);
      expect(find.text(TekstenReactiesNl.geheimVraagBewoner), findsOneWidget);
      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      expect(fake.aantalGegeven, 0, reason: 'eerst Ja of Nee');
      await beantwoordGeheim(tester, ja: false);
      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      expect(fake.geheim.single.allesInOrde, isFalse);
      expect(find.text(TekstenBeoordelenNl.o9Bedankt), findsOneWidget);
      expect(find.text(TekstenReactiesNl.geheimNeeBedankt), findsOneWidget);
    });

    testWidgets('duim omhoog vult vijf sterren voor', (tester) async {
      await _pomp(tester, _gevallen[4]);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmhoog);
      expect(find.text(TekstenBeoordelenNl.woordHeelGoed), findsOneWidget);
    });

    testWidgets('duim omlaag vult twee sterren voor', (tester) async {
      await _pomp(tester, _gevallen[4]);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmlaag);
      expect(find.text(TekstenBeoordelenNl.woordNietGoed), findsOneWidget);
    });

    testWidgets('terug vanaf de sterren gaat naar de duim', (tester) async {
      await _pomp(tester, _gevallen[4]);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmlaag);
      await tester.tap(find.text(TekstenNl.terug));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.o9DuimOmhoog),
        findsOneWidget,
      );
    });

    testWidgets('nergens een cijfer, gemiddelde of aantal', (tester) async {
      await _pomp(tester, _gevallen[4]);
      final cijfer = find.textContaining(RegExp(r'\d'));
      expect(cijfer, findsNothing, reason: 'stap duim');
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmhoog);
      expect(cijfer, findsNothing, reason: 'stap sterren');
      await beantwoordGeheim(tester);
      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      expect(cijfer, findsNothing, reason: 'stap bedankt');
    });

    testWidgets('opgeslagen wordt alleen sterren en tekst', (tester) async {
      final fake = await _pomp(tester, _gevallen[4]);
      await tikKnop(tester, TekstenBeoordelenNl.o9DuimOmlaag);
      await tikSter(tester, 3);
      await vulVeld(tester, 0, 'Kwam wat laat.');
      await beantwoordGeheim(tester);
      await tikKnop(tester, TekstenBeoordelenNl.o9Versturen);
      final b = fake.alleBeoordelingen.single;
      expect(b.sterren, 3);
      expect(b.tekst, 'Kwam wat laat.');
      expect(b.naarId, jongereId);
    });

    testWidgets('een bestaande beoordeling: meteen de sterren, ingevuld', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[5]);
      expect(find.text(TekstenBeoordelenNl.o9BestaandUitleg), findsOneWidget);
      expect(find.byType(SterrenKiezer), findsOneWidget);
      expect(find.text(TekstenBeoordelenNl.woordGoed), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.o9Opslaan),
        findsOneWidget,
      );
    });
  });

  group('aanhaakpunten', () {
    testWidgets('J15 afgerond: "Beoordeling geven" opent J17', (tester) async {
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.afgerond),
          beoordelingGateway: fakeBeoordeling(),
        ),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenBeoordelenNl.j15Beoordelen);
      expect(find.text(TekstenBeoordelenNl.j17Titel), findsOneWidget);
    });

    testWidgets('J15 na beoordelen: "Beoordeling wijzigen"', (tester) async {
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.afgerond),
          beoordelingGateway: fakeBeoordeling(
            beoordelingen: [_vanJongere('k-uitvoeren', 5)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j15Beoordelen),
        findsNothing,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j15BeoordelingWijzigen),
        findsOneWidget,
      );
    });

    testWidgets('J14 historie: "Nog beoordelen" bij een afgeronde klus', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenKlussen.mijnKlussen,
          uitvoerGateway: fakeUitvoer(
            klussen: [afgerondeKlus(id: 'm-historie')],
          ),
          beoordelingGateway: fakeBeoordeling(
            klussen: [afgerondeKlus(id: 'm-historie')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tikTekst(tester, TekstenReactiesNl.tabKlaar);
      await tikKnop(tester, TekstenBeoordelenNl.j14NogBeoordelen);
      expect(find.text(TekstenBeoordelenNl.j17Titel), findsOneWidget);
    });

    testWidgets('J14 historie: geen "Nog beoordelen" als het al gedaan is', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenKlussen.mijnKlussen,
          uitvoerGateway: fakeUitvoer(),
          beoordelingGateway: fakeBeoordeling(
            beoordelingen: [_vanJongere('m-historie', 4)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tikTekst(tester, TekstenReactiesNl.tabKlaar);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j14NogBeoordelen),
        findsNothing,
      );
    });

    testWidgets('O7 afgerond: "Hoe ging het?" opent O9, nog steeds hooguit '
        'drie acties', (tester) async {
      await tester.pumpWidget(
        hhBeoordelenWikkel(
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          uitvoerGateway: fakeUitvoer(
            status: HhKlusStatus.afgerond,
            ikBen: oudereId,
          ),
          beoordelingGateway: fakeBeoordeling(ikBen: oudereId),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HhKnop).evaluate().length, lessThanOrEqualTo(3));
      // Geen sterren van de jongere op O7 (ouderenregel). Een bedrag als
      // "€ 10,00" in het overzicht (feedbackronde 1 punt C) mag wel; een
      // ster-cijfer is één cijfer, komma, één cijfer.
      expect(find.textContaining(RegExp(r'\b\d,\d\b')), findsNothing);
      await tikKnop(tester, TekstenBeoordelenNl.o7HoeGingHet);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.o9DuimOmhoog),
        findsOneWidget,
      );
    });

    testWidgets('O8 afgerond: "Hoe ging het?" alleen zolang het nog niet '
        'gezegd is', (tester) async {
      final beoordeling = fakeBeoordeling(
        ikBen: oudereId,
        klussen: [
          afgerondeKlus(id: 'a'),
          afgerondeKlus(id: 'b'),
        ],
        beoordelingen: [_vanOudere('b', 5)],
      );
      await tester.pumpWidget(
        hhBeoordelenWikkel(
          HhPadenStatus.hulpvragen,
          uitvoerGateway: fakeUitvoer(
            klussen: [
              afgerondeKlus(id: 'a'),
              afgerondeKlus(id: 'b'),
            ],
            ikBen: oudereId,
          ),
          beoordelingGateway: beoordeling,
        ),
      );
      await tester.pumpAndSettle();
      await tikTekst(tester, TekstenUitvoerenNl.o8TabAfgerond);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.o7HoeGingHet),
        findsOneWidget,
      );
      await tikKnop(tester, TekstenBeoordelenNl.o7HoeGingHet);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.o9DuimOmhoog),
        findsOneWidget,
      );
    });

    testWidgets('laadt de beoordelingenlijst niet, dan blijft J15 werken', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.afgerond),
          beoordelingGateway: fakeBeoordeling()..isOffline = true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HhMeldBalk), findsNothing);
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j15Beoordelen),
        findsOneWidget,
      );
    });
  });
}

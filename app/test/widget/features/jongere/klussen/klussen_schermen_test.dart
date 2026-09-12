import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_klussen_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_lege_staat.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/klus_detail_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/klussen_home_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/mijn_klussen_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/jongere_tabbalk.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/klus_status_pil.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/klus_tegel.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/klussen_kaart.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_overzicht_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../../support/hh_jongere_wikkel.dart';
import '../../../../support/hh_klussen_wikkel.dart';
import '../../../../support/hh_wikkel.dart';

/// Elk M5-scherm in de staat die het nodig heeft.
class _Geval {
  const _Geval(this.naam, this.pad, this.fake);

  final String naam;
  final String pad;
  final FakeKlussenGateway Function() fake;
}

final _gevallen = [
  const _Geval('J11 lijst met klussen', HhPaden.jongere, fakeKlussen),
  _Geval('J11 lijst leeg', HhPaden.jongere, () => fakeKlussen(open: const [])),
  _Geval(
    'J11 lijst laadfout',
    HhPaden.jongere,
    () => fakeKlussen()..isOffline = true,
  ),
  _Geval('J13 open klus', HhPadenKlussen.klusDetail('k-middag'), fakeKlussen),
  _Geval(
    'J13 eigen klus',
    HhPadenKlussen.klusDetail('m-vandaag'),
    () => fakeKlussen(mijn: testMijnKlussen()),
  ),
  _Geval(
    'J14 mijn klussen',
    HhPadenKlussen.mijnKlussen,
    () => fakeKlussen(mijn: testMijnKlussen()),
  ),
  const _Geval('J14 leeg', HhPadenKlussen.mijnKlussen, fakeKlussen),
  const _Geval('tab profiel (J9)', HhPadenKlussen.profiel, fakeKlussen),
  const _Geval(
    'tab instellingen (G7)',
    HhPadenKlussen.instellingen,
    fakeKlussen,
  ),
];

Future<FakeKlussenGateway> _pomp(
  WidgetTester tester,
  _Geval geval, {
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) async {
  final fake = geval.fake();
  await tester.pumpWidget(
    hhKlussenWikkel(
      geval.pad,
      klussenGateway: fake,
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Naar de kaart op J11.
Future<void> _naarKaart(WidgetTester tester) async {
  await tikTekst(tester, TekstenKlussenNl.weergaveKaart);
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

    testWidgets('J12 kaart in beide dichtheden en op 200 procent', (
      tester,
    ) async {
      for (final dichtheid in HhDichtheid.values) {
        await _pomp(tester, _gevallen[0], dichtheid: dichtheid);
        await _naarKaart(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(KlussenKaart), findsOneWidget);
        controleerSemantiek(tester);
      }
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _pomp(tester, _gevallen[0], tekstschaal: hhMaxTekstschaal);
      await _naarKaart(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('tabbalk', () {
    testWidgets('vier tabbladen, de actieve is geselecteerd voor de lezer', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[0]);
      final balk = find.byType(JongereTabbalk);
      expect(balk, findsOneWidget);
      for (final tab in JongereTab.values) {
        expect(
          find.descendant(of: balk, matching: find.text(tab.label)),
          findsOneWidget,
        );
      }
      final actief = tester.getSemantics(
        find.descendant(
          of: balk,
          matching: find.bySemanticsLabel(TekstenKlussenNl.tabKlussen),
        ),
      );
      expect(
        actief.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      final ander = tester.getSemantics(
        find.descendant(
          of: balk,
          matching: find.bySemanticsLabel(TekstenKlussenNl.tabMijnKlussen),
        ),
      );
      expect(
        ander.getSemanticsData().flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );
    });

    testWidgets('tik op een tab wisselt van scherm', (tester) async {
      await _pomp(tester, _gevallen[0]);
      expect(find.byType(KlussenHomeScreen), findsOneWidget);

      await tikTekst(tester, TekstenKlussenNl.tabMijnKlussen);
      expect(find.byType(MijnKlussenScreen), findsOneWidget);

      await tikTekst(tester, TekstenKlussenNl.tabProfiel);
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(find.byType(JongereTabbalk), findsOneWidget);

      await tikTekst(tester, TekstenKlussenNl.tabInstellingen);
      expect(find.byType(InstellingenScreen), findsOneWidget);
      expect(find.byType(JongereTabbalk), findsOneWidget);

      await tikTekst(tester, TekstenKlussenNl.tabKlussen);
      expect(find.byType(KlussenHomeScreen), findsOneWidget);
    });
  });

  group('J11 lijst', () {
    testWidgets(
      'toont elke open klus met soort, wanneer, afstand en vergoeding',
      (tester) async {
        await _pomp(tester, _gevallen[0]);

        expect(find.text(TekstenKlussenNl.j11Titel), findsOneWidget);
        expect(find.byType(KlusTegel), findsNWidgets(4));
        expect(find.text(TekstenKlussenNl.j11Aantal(4)), findsOneWidget);
        expect(find.text('Boodschappen'), findsWidgets);
        expect(find.text('Tuin'), findsWidgets);
        expect(find.text('morgen van 09:00 tot 10:00'), findsOneWidget);
        expect(
          find.text('donderdag 17 september van 18:30 tot 19:30'),
          findsOneWidget,
        );
        expect(find.textContaining('ca. '), findsNWidgets(3));
        expect(find.text(TekstenKlussenNl.zonderLocatie), findsOneWidget);
        expect(
          find.text(TekstenKlussenNl.vergoeding('€ 15,00')),
          findsNWidgets(2),
        );
        expect(
          find.text(TekstenKlussenNl.vergoeding('€ 10,00')),
          findsNWidgets(2),
        );
        // Geen statuspil in de lijst met open klussen.
        expect(find.byType(KlusStatusPil), findsNothing);
      },
    );

    testWidgets('lege staat zonder klussen', (tester) async {
      await _pomp(tester, _gevallen[1]);
      expect(find.text(TekstenKlussenNl.j11Leeg), findsOneWidget);
      expect(find.byType(KlusTegel), findsNothing);
    });

    testWidgets('laadfout met opnieuw proberen', (tester) async {
      final fake = await _pomp(tester, _gevallen[2]);
      expect(find.text(TekstenKlussenNl.j11LadenMislukt), findsOneWidget);
      fake.isOffline = false;
      await tikKnop(tester, 'Opnieuw proberen');
      expect(find.byType(KlusTegel), findsNWidgets(4));
    });

    testWidgets('pull-to-refresh haalt de lijst opnieuw op', (tester) async {
      final fake = await _pomp(tester, _gevallen[0]);
      expect(fake.aantalOpenAanvragen, 1);
      fake.voorVolgendeLading = (f) => f.neemAanDoorAnder('k-ochtend');

      await tester.fling(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(fake.aantalOpenAanvragen, 2);
      expect(find.byType(KlusTegel), findsNWidgets(3));
    });

    testWidgets('straal uit het profiel filtert klussen buiten de straal', (
      tester,
    ) async {
      // Profiel goedgekeurd heeft straal 3 km; een klus op 8 km valt eruit.
      final fake = fakeKlussen(
        open: [
          ...testOpenKlussen(),
          testKlus(id: 'k-ver', afstandKm: 8),
        ],
      );
      await tester.pumpWidget(
        hhKlussenWikkel(HhPaden.jongere, klussenGateway: fake),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KlusTegel), findsNWidgets(4));
      expect(find.text(TekstenKlussenNl.j11BuitenStraal(1, 3)), findsOneWidget);
    });
  });

  group('J12 kaart', () {
    testWidgets('markers voor klussen met locatie en badge voor de rest', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[0]);
      await _naarKaart(tester);

      expect(find.byType(KlussenKaart), findsOneWidget);
      expect(find.byType(KlusMarker), findsNWidgets(3));
      expect(find.text(TekstenKlussenNl.j12ZonderLocatie(1)), findsOneWidget);

      await tikKnop(tester, TekstenKlussenNl.j12ZonderLocatie(1));
      expect(find.byType(KlussenKaart), findsNothing);
      expect(find.byType(KlusTegel), findsNWidgets(4));
    });

    testWidgets('zonder locaties een lege staat met terug naar de lijst', (
      tester,
    ) async {
      final fake = fakeKlussen(open: [testKlus(id: 'a', afstandKm: null)]);
      await tester.pumpWidget(
        hhKlussenWikkel(HhPaden.jongere, klussenGateway: fake),
      );
      await tester.pumpAndSettle();
      await _naarKaart(tester);
      expect(find.text(TekstenKlussenNl.j12Leeg), findsOneWidget);
      expect(find.byType(KlussenKaart), findsNothing);
    });

    testWidgets('tik op een marker opent J13', (tester) async {
      await _pomp(tester, _gevallen[0]);
      await _naarKaart(tester);
      await tester.tap(find.byType(KlusMarker).first);
      await tester.pumpAndSettle();
      expect(find.byType(KlusDetailScreen), findsOneWidget);
    });
  });

  group('J13 klusdetail', () {
    testWidgets(
      'open klus: wijk en afstand, geen adres of naam, knop aannemen',
      (tester) async {
        await _pomp(tester, _gevallen[3]);

        expect(find.text('Tuin'), findsOneWidget);
        expect(find.text('morgen van 14:00 tot 15:00'), findsOneWidget);
        expect(
          find.text(TekstenKlussenNl.j13Wijk('Tiel-West')),
          findsOneWidget,
        );
        expect(
          find.text(TekstenKlussenNl.j13AdresNaAccepteren),
          findsOneWidget,
        );
        expect(find.text(TekstenKlussenNl.buurtbewoner), findsOneWidget);
        expect(find.text(TekstenKlussenNl.j13NaamNaAccepteren), findsOneWidget);
        expect(find.text('Heg knippen aan de voorkant'), findsOneWidget);
        expect(
          find.text(TekstenKlussenNl.vergoeding('€ 15,00')),
          findsOneWidget,
        );
        expect(find.textContaining('Prins Bernhardlaan'), findsNothing);
        expect(
          find.widgetWithText(HhKnop, TekstenKlussenNl.j13Aannemen),
          findsOneWidget,
        );
        expect(find.byType(KlusStatusPil), findsNothing);
      },
    );

    testWidgets('eigen klus: adres, naam, statuspil en naar mijn klussen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[4]);

      expect(find.textContaining('Prins Bernhardlaan'), findsOneWidget);
      expect(find.text('Mevrouw de Vries'), findsOneWidget);
      expect(find.byType(KlusStatusPil), findsOneWidget);
      expect(find.text(TekstenKlussenNl.statusGeaccepteerd), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenKlussenNl.j13NaarMijnKlussen),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenKlussenNl.j13Aannemen),
        findsNothing,
      );
    });

    testWidgets('onbekende klus toont de laadfout', (tester) async {
      await tester.pumpWidget(
        hhKlussenWikkel(
          HhPadenKlussen.klusDetail('bestaat-niet'),
          klussenGateway: fakeKlussen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenKlussenNl.j13LadenMislukt), findsOneWidget);
      expect(find.byType(HhLegeStaat), findsOneWidget);
    });
  });

  group('J14 mijn klussen', () {
    testWidgets('drie tabbladen: vandaag, gepland, historie', (tester) async {
      await _pomp(tester, _gevallen[5]);

      expect(find.byType(KlusTegel), findsOneWidget);
      expect(find.text('vandaag van 15:00 tot 16:00'), findsOneWidget);
      expect(find.byType(KlusStatusPil), findsOneWidget);

      await tikTekst(tester, TekstenKlussenNl.j14TabGepland);
      expect(find.byType(KlusTegel), findsOneWidget);
      expect(find.text('Tuin'), findsOneWidget);

      await tikTekst(tester, TekstenKlussenNl.j14TabHistorie);
      expect(find.byType(KlusTegel), findsOneWidget);
      expect(find.text(TekstenKlussenNl.statusAfgerond), findsOneWidget);
    });

    testWidgets('lege staten per tabblad', (tester) async {
      await _pomp(tester, _gevallen[6]);
      expect(find.text(TekstenKlussenNl.j14LeegVandaag), findsOneWidget);
      await tikTekst(tester, TekstenKlussenNl.j14TabGepland);
      expect(find.text(TekstenKlussenNl.j14LeegGepland), findsOneWidget);
      await tikTekst(tester, TekstenKlussenNl.j14TabHistorie);
      expect(find.text(TekstenKlussenNl.j14LeegHistorie), findsOneWidget);
    });

    testWidgets('tik op een klus opent J13 met de statuspil', (tester) async {
      await _pomp(tester, _gevallen[5]);
      await tester.ensureVisible(find.byType(KlusTegel));
      await tester.tap(find.byType(KlusTegel));
      await tester.pumpAndSettle();
      expect(find.byType(KlusDetailScreen), findsOneWidget);
      expect(find.byType(KlusStatusPil), findsOneWidget);
      expect(find.byType(HhMeldBalk), findsNothing);
    });
  });

  group('statuspil', () {
    testWidgets('elke status heeft een naam en de stijl uit theme.dart', (
      tester,
    ) async {
      for (final status in HhKlusStatus.values) {
        await tester.pumpWidget(hhWikkel(KlusStatusPil(status: status)));
        expect(find.text(KlusStatusPil.naamVan(status)), findsOneWidget);
        final semantiek = tester.getSemantics(find.byType(KlusStatusPil));
        expect(
          semantiek.label,
          TekstenKlussenNl.statusSemantiek(KlusStatusPil.naamVan(status)),
        );
        expect(hhStatusStijlen[status], isNotNull);
      }
    });
  });
}

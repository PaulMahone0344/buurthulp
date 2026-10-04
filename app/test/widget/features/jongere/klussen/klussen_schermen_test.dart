import 'package:heitjehulp_app/l10n/teksten_reacties_nl.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
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
import 'package:heitjehulp_app/features/jongere/reputatie/screen/mijn_reputatie_screen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/screen/klus_uitvoeren_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_klus_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:heitjehulp_app/l10n/teksten_start_nl.dart';
import 'package:heitjehulp_app/features/jongere/start/helper_start_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

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
  const _Geval('J11 lijst met klussen', HhPadenKlussen.lijst, fakeKlussen),
  _Geval(
    'J11 lijst leeg',
    HhPadenKlussen.lijst,
    () => fakeKlussen(open: const []),
  ),
  _Geval(
    'J11 lijst laadfout',
    HhPadenKlussen.lijst,
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
  FakeUitvoerGateway? uitvoerGateway,
}) async {
  final fake = geval.fake();
  await tester.pumpWidget(
    hhKlussenWikkel(
      geval.pad,
      klussenGateway: fake,
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
      uitvoerGateway: uitvoerGateway,
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

      // M7: de tab Profiel is J19 (mijn profiel en reputatie).
      await tikTekst(tester, TekstenKlussenNl.tabProfiel);
      expect(find.byType(MijnReputatieScreen), findsOneWidget);
      expect(find.byType(JongereTabbalk), findsOneWidget);

      // B10: Instellingen is een knop op het Profiel, geen tab meer.
      await tikKnop(tester, TekstenStartNl.instellingen);
      expect(find.byType(InstellingenScreen), findsOneWidget);
      await tikTekst(tester, TekstenNl.terug);

      await tikTekst(tester, TekstenKlussenNl.tabKlussen);
      expect(find.byType(KlussenHomeScreen), findsOneWidget);

      // B10: Start is de eerste tab.
      await tikTekst(tester, TekstenKlussenNl.tabStart);
      expect(find.byType(HelperStartScreen), findsOneWidget);
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
        hhKlussenWikkel(HhPadenKlussen.lijst, klussenGateway: fake),
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
        hhKlussenWikkel(HhPadenKlussen.lijst, klussenGateway: fake),
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
    testWidgets('vergoeding 0: "Vergoeding volgt" in de lijst', (tester) async {
      await _pomp(
        tester,
        _Geval(
          'J11 vergoeding 0',
          HhPaden.jongere,
          () => fakeKlussen(open: [testKlus(id: 'k-nul', vergoedingCenten: 0)]),
        ),
      );
      expect(find.text(TekstenKlussenNl.vergoedingVolgt), findsOneWidget);
      expect(find.textContaining('€ 0,00'), findsNothing);
    });

    testWidgets('vergoeding 0: "Vergoeding volgt" in het klusdetail', (
      tester,
    ) async {
      await _pomp(
        tester,
        _Geval(
          'J13 vergoeding 0',
          HhPadenKlussen.klusDetail('k-nul'),
          () => fakeKlussen(open: [testKlus(id: 'k-nul', vergoedingCenten: 0)]),
        ),
      );
      expect(find.byType(KlusDetailScreen), findsOneWidget);
      expect(find.text(TekstenKlussenNl.vergoedingVolgt), findsOneWidget);
      expect(find.textContaining('€ 0,00'), findsNothing);
    });

    testWidgets('B4: de foto van de bewoner staat bij de klus', (tester) async {
      await _pomp(
        tester,
        _Geval(
          'J13 met foto',
          HhPadenKlussen.klusDetail('k-foto'),
          () => fakeKlussen(
            open: [
              testKlus(
                id: 'k-foto',
                klusFotoUrl:
                    'https://nep.test/api/files/x/k-foto/a.jpg?token=t',
              ),
            ],
          ),
        ),
      );

      expect(find.text(TekstenKlusNl.helperFotoKop), findsOneWidget);
      // De url met het bestandstoken gaat ongewijzigd naar het plaatje.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is NetworkImage &&
              (w.image as NetworkImage).url.endsWith('a.jpg?token=t'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('B4: zonder foto geen fotokaart', (tester) async {
      await _pomp(tester, _gevallen[3]);
      expect(find.text(TekstenKlusNl.helperFotoKop), findsNothing);
    });

    testWidgets(
      'open klus: wijk en afstand, geen adres of naam, knop "Ik wil helpen"',
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
        // B5: niet meer aannemen, maar reageren; de bewoner kiest.
        expect(
          find.widgetWithText(HhKnop, TekstenReactiesNl.reageerKnop),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(HhKnop, TekstenKlussenNl.j13Aannemen),
          findsNothing,
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
        find.widgetWithText(HhKnop, TekstenReactiesNl.reageerKnop),
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
    // B5: Gereageerd / Gepland / Klaar (mockup HMijnKlussen), Gepland eerst.
    testWidgets('drie tabbladen: gereageerd, gepland, klaar', (tester) async {
      await _pomp(tester, _gevallen[5]);

      // Gepland: vandaag en later, oplopend.
      expect(find.byType(KlusTegel), findsNWidgets(2));
      expect(find.text('vandaag van 15:00 tot 16:00'), findsOneWidget);
      expect(find.text('Tuin'), findsOneWidget);

      await tikTekst(tester, TekstenReactiesNl.tabKlaar);
      expect(find.byType(KlusTegel), findsOneWidget);
      expect(find.text(TekstenKlussenNl.statusAfgerond), findsOneWidget);

      await tikTekst(tester, TekstenReactiesNl.tabGereageerd);
      expect(find.byType(KlusTegel), findsNothing);
      expect(find.text(TekstenReactiesNl.leegGereageerd), findsOneWidget);
    });

    testWidgets('lege staten per tabblad', (tester) async {
      await _pomp(tester, _gevallen[6]);
      expect(find.text(TekstenReactiesNl.leegGepland), findsOneWidget);
      await tikTekst(tester, TekstenReactiesNl.tabGereageerd);
      expect(find.text(TekstenReactiesNl.leegGereageerd), findsOneWidget);
      await tikTekst(tester, TekstenReactiesNl.tabKlaar);
      expect(find.text(TekstenReactiesNl.leegKlaar), findsOneWidget);
    });

    // M6: een klus die loopt (geaccepteerd/onderweg/bezig) opent J15; een
    // afgeronde klus blijft het detail (J13) openen.
    testWidgets('tik op een lopende klus opent J15', (tester) async {
      await _pomp(tester, _gevallen[5]);
      await tester.ensureVisible(find.byType(KlusTegel).first);
      await tester.tap(find.byType(KlusTegel).first);
      await tester.pumpAndSettle();
      expect(find.byType(KlusUitvoerenScreen), findsOneWidget);
    });

    testWidgets('tik op een afgeronde klus opent J13 met de statuspil', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[5]);
      await tikTekst(tester, TekstenReactiesNl.tabKlaar);
      await tester.ensureVisible(find.byType(KlusTegel).first);
      await tester.tap(find.byType(KlusTegel).first);
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

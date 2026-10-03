import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/design/components/hh_stapbalk.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/screen/hulpvraag_status_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/screen/hulpvragen_lijst_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/widget/hulpvraag_tegel.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/l10n/teksten_beoordelen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../../support/hh_jongere_wikkel.dart';
import '../../../../support/hh_uitvoeren_wikkel.dart';
import 'package:heitjehulp_app/l10n/teksten_klus_nl.dart';

/// Elk M6-scherm in de staat die het nodig heeft.
class _Geval {
  const _Geval(this.naam, this.pad, this.fake, {this.isOudere = false});

  final String naam;
  final String pad;
  final FakeUitvoerGateway Function() fake;
  final bool isOudere;
}

final _gevallen = [
  _Geval(
    'J15 net aangenomen',
    HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
    () => fakeUitvoer(status: HhKlusStatus.geaccepteerd),
  ),
  _Geval(
    'J15 onderweg',
    HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
    () => fakeUitvoer(status: HhKlusStatus.onderweg),
  ),
  _Geval(
    'J15 bezig',
    HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
    () => fakeUitvoer(status: HhKlusStatus.bezig),
  ),
  _Geval(
    'J15 afgerond',
    HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
    () => fakeUitvoer(status: HhKlusStatus.afgerond),
  ),
  _Geval(
    'J15 laadfout',
    HhPadenUitvoeren.uitvoeren('bestaat-niet'),
    () => fakeUitvoer(status: HhKlusStatus.geaccepteerd),
  ),
  _Geval(
    'O7 nog geen jongere',
    HhPadenStatus.hulpvraag('k-uitvoeren'),
    () => fakeUitvoer(
      klussen: [uitvoerKlus(status: HhKlusStatus.open, metJongere: false)],
      ikBen: oudereId,
    ),
    isOudere: true,
  ),
  _Geval(
    'O7 onderweg',
    HhPadenStatus.hulpvraag('k-uitvoeren'),
    () => fakeUitvoer(status: HhKlusStatus.onderweg, ikBen: oudereId),
    isOudere: true,
  ),
  _Geval(
    'O7 afgerond',
    HhPadenStatus.hulpvraag('k-uitvoeren'),
    () => fakeUitvoer(status: HhKlusStatus.afgerond, ikBen: oudereId),
    isOudere: true,
  ),
  _Geval(
    'O8 lijst',
    HhPadenStatus.hulpvragen,
    () => fakeUitvoer(
      klussen: [
        uitvoerKlus(id: 'a', status: HhKlusStatus.open, metJongere: false),
        uitvoerKlus(id: 'b', status: HhKlusStatus.onderweg),
        uitvoerKlus(id: 'c', status: HhKlusStatus.afgerond),
      ],
      ikBen: oudereId,
    ),
    isOudere: true,
  ),
  _Geval(
    'O8 leeg',
    HhPadenStatus.hulpvragen,
    () => fakeUitvoer(klussen: const [], ikBen: oudereId),
    isOudere: true,
  ),
];

Future<FakeUitvoerGateway> _pomp(
  WidgetTester tester,
  _Geval geval, {
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) async {
  final fake = geval.fake();
  await tester.pumpWidget(
    geval.isOudere
        ? hhStatusWikkel(
            geval.pad,
            uitvoerGateway: fake,
            dichtheid: dichtheid,
            tekstschaal: tekstschaal,
          )
        : hhUitvoerenWikkel(
            geval.pad,
            uitvoerGateway: fake,
            dichtheid: dichtheid,
            tekstschaal: tekstschaal,
          ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('elk M6-scherm rendert in beide dichtheden met semantiek', () {
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
  });

  group('J15 klus uitvoeren', () {
    testWidgets('toont de stappenbalk met de tijd per gezette stap', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]); // onderweg
      expect(find.byType(HhStapbalk), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.j15StapOnderweg), findsWidgets);
      // De logregels leveren de tijd: 10:00, 10:15, 10:30.
      expect(find.text('10:30'), findsOneWidget);
    });

    // Elke staat in een eigen test: twee containers in één test laten een
    // Riverpod-timer achter.
    for (final (index, label) in <(int, String)>[
      (0, TekstenUitvoerenNl.j15KnopOnderweg),
      (1, TekstenUitvoerenNl.j15KnopAangekomen),
      (2, TekstenUitvoerenNl.j15KnopAfgerond),
    ]) {
      testWidgets('de knop van ${_gevallen[index].naam} is "$label"', (
        tester,
      ) async {
        await _pomp(tester, _gevallen[index]);
        expect(find.widgetWithText(HhKnop, label), findsOneWidget);
      });
    }

    testWidgets('adres en contactpersoon staan op het scherm', (tester) async {
      await _pomp(tester, _gevallen[0]);
      expect(find.textContaining('Prins Bernhardlaan'), findsOneWidget);
      expect(find.textContaining('Dochter Jansen'), findsOneWidget);
      expect(find.text(testOudereNaam), findsOneWidget);
    });

    testWidgets('bij geaccepteerd staat er "Ik kan toch niet"', (tester) async {
      await _pomp(tester, _gevallen[0]);
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.j15Annuleren),
        findsOneWidget,
      );
    });

    testWidgets('bij bezig verdwijnt de knop "Ik kan toch niet"', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[2]);
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.j15Annuleren),
        findsNothing,
      );
    });

    testWidgets('na afgerond een rustige eindstaat, geen stapknop meer', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[3]);
      expect(find.text(TekstenUitvoerenNl.j15Afgerond), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.j15KnopAfgerond),
        findsNothing,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.j15NaarMijnKlussen),
        findsOneWidget,
      );
      // M7: de weg naar J17.
      expect(
        find.widgetWithText(HhKnop, TekstenBeoordelenNl.j15Beoordelen),
        findsOneWidget,
      );
    });

    testWidgets('een klus die niet kon laden toont de lege staat', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[4]);
      expect(find.text(TekstenUitvoerenNl.j15LadenMislukt), findsOneWidget);
    });
  });

  group('O7 status hulpvraag (ouderenregel)', () {
    for (final index in [5, 6, 7]) {
      testWidgets(
        '${_gevallen[index].naam}: hoogstens drie acties, plus de terugknop',
        (tester) async {
          await _pomp(tester, _gevallen[index], dichtheid: HhDichtheid.groot);
          final knoppen = find.byType(HhKnop).evaluate().length;
          expect(
            knoppen,
            lessThanOrEqualTo(3),
            reason: '${_gevallen[index].naam} heeft $knoppen knoppen',
          );
          expect(find.text(TekstenNl.terug), findsOneWidget);
        },
      );
    }

    testWidgets('zegt in gewone taal waar de klus staat', (tester) async {
      await _pomp(tester, _gevallen[6], dichtheid: HhDichtheid.groot);
      expect(find.text('Sanne is onderweg naar je.'), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o7Helper), findsOneWidget);
    });

    testWidgets('zonder jongere: we zoeken iemand voor u', (tester) async {
      await _pomp(tester, _gevallen[5], dichtheid: HhDichtheid.groot);
      expect(find.text(TekstenUitvoerenNl.o7GeenJongere), findsOneWidget);
      // Bellen kan nog niet; stoppen wel.
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Bellen),
        findsNothing,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Annuleren),
        findsOneWidget,
      );
    });

    // B4: de meldkamer keurt elke klus eerst.
    testWidgets('ongekeurd: "wordt nagekeken" met gele balk, stoppen kan', (
      tester,
    ) async {
      await _pomp(
        tester,
        _Geval(
          'O7 nagekeken',
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          () => fakeUitvoer(
            klussen: [
              uitvoerKlus(
                status: HhKlusStatus.open,
                metJongere: false,
                wordtNagekeken: true,
              ),
            ],
            ikBen: oudereId,
          ),
          isOudere: true,
        ),
        dichtheid: HhDichtheid.groot,
      );
      expect(find.text(TekstenKlusNl.wordtNagekeken), findsOneWidget);
      final balk = tester.widget<HhMeldBalk>(
        find.widgetWithText(HhMeldBalk, TekstenKlusNl.wordtNagekekenUitleg),
      );
      expect(balk.soort, HhMeldSoort.waarschuwing);
      expect(find.text(TekstenUitvoerenNl.o7GeenJongere), findsNothing);
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Annuleren),
        findsOneWidget,
      );
    });

    testWidgets('afgekeurd: de reden van de meldkamer staat erbij', (
      tester,
    ) async {
      await _pomp(
        tester,
        _Geval(
          'O7 afgekeurd',
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          () => fakeUitvoer(
            klussen: [
              uitvoerKlus(
                status: HhKlusStatus.geannuleerd,
                metJongere: false,
                afkeurReden: 'Sigaretten kan niet.',
              ),
            ],
            ikBen: oudereId,
          ),
          isOudere: true,
        ),
        dichtheid: HhDichtheid.groot,
      );
      expect(find.text(TekstenKlusNl.afgekeurd), findsOneWidget);
      expect(
        find.text(TekstenKlusNl.afgekeurdReden('Sigaretten kan niet.')),
        findsOneWidget,
      );
    });

    testWidgets('na afloop geen knop bellen en geen knop stoppen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[7], dichtheid: HhDichtheid.groot);
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Bellen),
        findsNothing,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Annuleren),
        findsNothing,
      );
    });

    testWidgets('de annuleer-dialoog vraagt niet om typen', (tester) async {
      await _pomp(tester, _gevallen[6], dichtheid: HhDichtheid.groot);
      await tikKnop(tester, TekstenUitvoerenNl.o7Annuleren);
      expect(find.text(TekstenUitvoerenNl.o7AnnuleerTitel), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o7RedenOpgelost), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o7RedenAndereDag), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o7RedenNietThuis), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      // Wie toch wil typen, kan dat alsnog.
      await tikKnop(tester, TekstenUitvoerenNl.o7RedenAnders);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('O8 mijn hulpvragen', () {
    testWidgets('drie tabbladen; open toont de open hulpvraag', (tester) async {
      await _pomp(tester, _gevallen[8], dichtheid: HhDichtheid.groot);
      expect(find.text(TekstenUitvoerenNl.o8TabOpen), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o8TabGepland), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o8TabAfgerond), findsOneWidget);
      expect(find.byType(HulpvraagTegel), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o8NogNiemand), findsOneWidget);
    });

    testWidgets('gepland toont de lopende hulpvraag met de naam', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[8], dichtheid: HhDichtheid.groot);
      await tikTekst(tester, TekstenUitvoerenNl.o8TabGepland);
      expect(find.byType(HulpvraagTegel), findsOneWidget);
      expect(find.text('Sanne is onderweg naar je.'), findsOneWidget);
    });

    testWidgets('afgerond toont de afgeronde hulpvraag', (tester) async {
      await _pomp(tester, _gevallen[8], dichtheid: HhDichtheid.groot);
      await tikTekst(tester, TekstenUitvoerenNl.o8TabAfgerond);
      expect(find.byType(HulpvraagTegel), findsOneWidget);
      expect(find.text('Sanne heeft de klus gedaan.'), findsOneWidget);
    });

    testWidgets('B4: een ongekeurde klus zegt "wordt nagekeken" op de tegel', (
      tester,
    ) async {
      await _pomp(
        tester,
        _Geval(
          'O8 nagekeken',
          HhPadenStatus.hulpvragen,
          () => fakeUitvoer(
            klussen: [
              uitvoerKlus(
                status: HhKlusStatus.open,
                metJongere: false,
                wordtNagekeken: true,
              ),
            ],
            ikBen: oudereId,
          ),
          isOudere: true,
        ),
        dichtheid: HhDichtheid.groot,
      );
      expect(find.text(TekstenKlusNl.wordtNagekeken), findsOneWidget);
      expect(find.text(TekstenUitvoerenNl.o8NogNiemand), findsNothing);
    });

    testWidgets('tik op een tegel opent O7', (tester) async {
      await _pomp(tester, _gevallen[8], dichtheid: HhDichtheid.groot);
      await tester.tap(find.byType(HulpvraagTegel).first);
      await tester.pumpAndSettle();
      expect(find.byType(HulpvraagStatusScreen), findsOneWidget);
    });

    testWidgets('leeg toont de lege staat per tabblad', (tester) async {
      await _pomp(tester, _gevallen[9], dichtheid: HhDichtheid.groot);
      expect(find.text(TekstenUitvoerenNl.o8LeegOpen), findsOneWidget);
      await tikTekst(tester, TekstenUitvoerenNl.o8TabGepland);
      expect(find.text(TekstenUitvoerenNl.o8LeegGepland), findsOneWidget);
      await tikTekst(tester, TekstenUitvoerenNl.o8TabAfgerond);
      expect(find.text(TekstenUitvoerenNl.o8LeegAfgerond), findsOneWidget);
    });

    testWidgets('het lijstscherm staat op zijn eigen route', (tester) async {
      await _pomp(tester, _gevallen[9], dichtheid: HhDichtheid.groot);
      expect(find.byType(HulpvragenLijstScreen), findsOneWidget);
      expect(find.byType(HhMeldBalk), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/jongere_tabbalk.dart';
import 'package:heitjehulp_app/features/jongere/widget/hh_screening_pil.dart';
import 'package:heitjehulp_app/l10n/teksten_jongere_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_wikkel.dart';

/// Elk J-scherm en de landing, in de staat die het scherm nodig heeft.
class _Geval {
  const _Geval(this.naam, this.pad, this.fake);

  final String naam;
  final String pad;
  final FakeProfielGateway Function() fake;
}

final _gevallen = [
  const _Geval('J1 profiel leeg', HhPadenJongere.profiel, fakeNieuweJongere),
  const _Geval(
    'J1 profiel gevuld',
    HhPadenJongere.profiel,
    fakeJongereKlaarOmInTeDienen,
  ),
  const _Geval(
    'J2 identiteit leeg',
    HhPadenJongere.identiteit,
    fakeNieuweJongere,
  ),
  const _Geval(
    'J2 identiteit gevuld',
    HhPadenJongere.identiteit,
    fakeJongereKlaarOmInTeDienen,
  ),
  const _Geval('J3 selfie leeg', HhPadenJongere.selfie, fakeNieuweJongere),
  const _Geval('J4 vog leeg', HhPadenJongere.vog, fakeNieuweJongere),
  const _Geval(
    'J4 vog aangevraagd',
    HhPadenJongere.vog,
    fakeJongereKlaarOmInTeDienen,
  ),
  const _Geval('J5 iban leeg', HhPadenJongere.iban, fakeNieuweJongere),
  const _Geval(
    'J5 iban gevuld',
    HhPadenJongere.iban,
    fakeJongereKlaarOmInTeDienen,
  ),
  const _Geval('J6 werkgebied', HhPadenJongere.werkgebied, fakeNieuweJongere),
  const _Geval(
    'J7 beschikbaarheid',
    HhPadenJongere.beschikbaarheid,
    fakeNieuweJongere,
  ),
  const _Geval('J8 klussoorten', HhPadenJongere.klussoorten, fakeNieuweJongere),
  const _Geval(
    'J9 overzicht leeg',
    HhPadenJongere.overzicht,
    fakeNieuweJongere,
  ),
  const _Geval(
    'J9 overzicht klaar om in te dienen',
    HhPadenJongere.overzicht,
    fakeJongereKlaarOmInTeDienen,
  ),
  _Geval(
    'J9 overzicht in behandeling',
    HhPadenJongere.overzicht,
    () => fakeJongereMetStatus(HhScreeningStatus.inBehandeling),
  ),
  _Geval(
    'J9 overzicht afgewezen',
    HhPadenJongere.overzicht,
    () => fakeJongereMetStatus(HhScreeningStatus.afgewezen),
  ),
  _Geval(
    'J9 overzicht goedgekeurd',
    HhPadenJongere.overzicht,
    () => fakeJongereMetStatus(HhScreeningStatus.goedgekeurd),
  ),
  _Geval(
    'landing jongere goedgekeurd',
    HhPaden.jongere,
    () => fakeJongereMetStatus(HhScreeningStatus.goedgekeurd),
  ),
  _Geval(
    'landing jongere laadfout',
    HhPaden.jongere,
    () => fakeNieuweJongere()..isOffline = true,
  ),
];

Future<void> _pomp(
  WidgetTester tester,
  _Geval geval, {
  required HhDichtheid dichtheid,
  double tekstschaal = 1.0,
}) async {
  await tester.pumpWidget(
    hhJongereWikkel(
      geval.pad,
      profielGateway: geval.fake(),
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final geval in _gevallen) {
    group(geval.naam, () {
      for (final dichtheid in HhDichtheid.values) {
        testWidgets('rendert in dichtheid $dichtheid met semantiek', (
          tester,
        ) async {
          await _pomp(tester, geval, dichtheid: dichtheid);

          expect(tester.takeException(), isNull);
          expect(find.byType(Scaffold), findsWidgets);
          controleerSemantiek(tester);
        });
      }

      testWidgets('200 procent tekst op een smal scherm zonder overloop', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pomp(
          tester,
          geval,
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        );

        expect(tester.takeException(), isNull);
      });
    });
  }

  group('inhoud', () {
    testWidgets(
      'J9 leeg: acht open stappen, knop indienen uit, geen terugknop',
      (tester) async {
        await _pomp(tester, _gevallen[12], dichtheid: HhDichtheid.normaal);

        final indienen = find.widgetWithText(
          HhKnop,
          TekstenJongereNl.j9Indienen,
        );
        expect(indienen, findsOneWidget);
        expect(tester.widget<HhKnop>(indienen).isActief, isFalse);
        expect(find.byType(HhTerugKnop), findsNothing);
        expect(find.text(TekstenJongereNl.j9IndienenHulp), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(8));
        expect(find.byType(HhScreeningPil), findsNWidgets(2));
      },
    );

    testWidgets('J9 klaar: acht afgevinkte stappen, knop indienen aan', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[13], dichtheid: HhDichtheid.normaal);

      final indienen = find.widgetWithText(HhKnop, TekstenJongereNl.j9Indienen);
      expect(tester.widget<HhKnop>(indienen).isActief, isTrue);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(8));
    });

    testWidgets('J9 in behandeling: wachttekst, geen knop indienen', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[14], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenJongereNl.j9WachtTekst), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.j9Indienen),
        findsNothing,
      );
      expect(find.text(TekstenJongereNl.statusInBehandeling), findsOneWidget);
    });

    testWidgets('J9 afgewezen: tekst en Bel ons', (tester) async {
      await _pomp(tester, _gevallen[15], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenJongereNl.j9AfgewezenTekst), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.j9BelOns),
        findsOneWidget,
      );
    });

    testWidgets('J9 goedgekeurd: Naar klussen en een terugknop', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[16], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenJongereNl.j9GoedgekeurdTekst), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.j9NaarKlussen),
        findsOneWidget,
      );
      expect(find.byType(HhTerugKnop), findsOneWidget);
    });

    testWidgets('landing (M5: J11) toont de klussen en de tabbalk', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[17], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenKlussenNl.j11Titel), findsOneWidget);
      expect(find.byType(JongereTabbalk), findsOneWidget);
      expect(find.text(TekstenKlussenNl.tabProfiel), findsOneWidget);
    });

    testWidgets('J3 heeft alleen een cameraknop, geen galerij', (tester) async {
      await _pomp(tester, _gevallen[4], dichtheid: HhDichtheid.normaal);

      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.j3Knop),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.fotoKiezen),
        findsNothing,
      );
    });

    testWidgets('J2 legt uit wat wel en niet zichtbaar mag zijn', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[2], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenJongereNl.j2WelZichtbaar), findsOneWidget);
      expect(find.text(TekstenJongereNl.j2NietZichtbaar), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.fotoKiezen),
        findsOneWidget,
      );
    });

    testWidgets('J7 toont zeven dagen met drie dagdelen', (tester) async {
      await _pomp(tester, _gevallen[10], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenJongereNl.dagMa), findsOneWidget);
      expect(find.text(TekstenJongereNl.dagZo), findsOneWidget);
      expect(find.text(TekstenJongereNl.dagdeelOchtend), findsNWidgets(7));
    });

    testWidgets('J8 toont de zes klussoorten uit de fake', (tester) async {
      await _pomp(tester, _gevallen[11], dichtheid: HhDichtheid.normaal);

      for (final type in FakeProfielGateway.standaardKlustypes) {
        expect(find.text(type.naam), findsOneWidget, reason: type.naam);
      }
    });
  });
}

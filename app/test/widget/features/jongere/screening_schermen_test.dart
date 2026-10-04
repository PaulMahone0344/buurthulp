import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/features/jongere/klussen/widget/jongere_tabbalk.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/widget/helper_wacht_start.dart';
import 'package:heitjehulp_app/features/jongere/widget/hh_screening_pil.dart';
import 'package:heitjehulp_app/features/toegang/domein/werkgebied.dart';
import 'package:heitjehulp_app/features/toegang/widget/aanmeld_stappen.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_jongere_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:heitjehulp_app/l10n/teksten_start_nl.dart';

import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_wikkel.dart';

/// Elk aanmeldscherm van de helper en Start, in de staat die het nodig heeft.
class _Geval {
  const _Geval(this.naam, this.pad, this.fake);

  final String naam;
  final String pad;
  final FakeProfielGateway Function() fake;
}

final _gevallen = <String, _Geval>{
  'id leeg': const _Geval(
    'ID-foto leeg',
    HhPadenJongere.identiteit,
    fakeNieuweJongere,
  ),
  'id gevuld': const _Geval(
    'ID-foto gevuld',
    HhPadenJongere.identiteit,
    fakeJongereKlaarOmInTeDienen,
  ),
  'id gecontroleerd': _Geval(
    'ID gecontroleerd',
    HhPadenJongere.identiteit,
    () => fakeJongereMetStatus(HhScreeningStatus.goedgekeurd),
  ),
  'vog leeg': const _Geval('VOG leeg', HhPadenJongere.vog, fakeNieuweJongere),
  'vog gezien': _Geval(
    'VOG gezien',
    HhPadenJongere.vog,
    () => fakeJongereMetStatus(HhScreeningStatus.goedgekeurd),
  ),
  'over mij': const _Geval(
    'Over mij',
    HhPadenJongere.overMij,
    fakeJongereKlaarOmInTeDienen,
  ),
  'j9 leeg': const _Geval(
    'J9 leeg (18+)',
    HhPadenJongere.overzicht,
    fakeNieuweJongere,
  ),
  'j9 leeg jong': _Geval(
    'J9 leeg (onder 18)',
    HhPadenJongere.overzicht,
    () => fakeNieuweJongere(isMinderjarig: true),
  ),
  'j9 klaar': const _Geval(
    'J9 klaar om te versturen',
    HhPadenJongere.overzicht,
    fakeJongereKlaarOmInTeDienen,
  ),
  'j9 behandeling': _Geval(
    'J9 in behandeling',
    HhPadenJongere.overzicht,
    () => fakeJongereMetStatus(HhScreeningStatus.inBehandeling),
  ),
  'j9 afgewezen': _Geval(
    'J9 afgewezen',
    HhPadenJongere.overzicht,
    () => fakeJongereMetStatus(HhScreeningStatus.afgewezen),
  ),
  'binnen': const _Geval(
    'Aanmelding binnen',
    HhPadenJongere.binnen,
    fakeJongereKlaarOmInTeDienen,
  ),
  'start klaar': _Geval(
    'Start: alles rond',
    HhPaden.jongere,
    () => fakeJongereMetStatus(HhScreeningStatus.goedgekeurd),
  ),
  'start nagekeken': _Geval(
    'Start: nagekeken',
    HhPaden.jongere,
    () => fakeJongereMetStatus(HhScreeningStatus.inBehandeling),
  ),
  'start ouder': _Geval(
    'Start: wacht op ouder',
    HhPaden.jongere,
    () => fakeJongereGoedgekeurdWachtend(isMinderjarig: true),
  ),
  'start vog': const _Geval(
    'Start: wacht op VOG',
    HhPaden.jongere,
    fakeJongereGoedgekeurdWachtend,
  ),
  'start buiten': _Geval(
    'Start: buiten het werkgebied',
    HhPaden.jongere,
    () => fakeJongereBuitenGebied(),
  ),
  'start adres onbekend': _Geval(
    'Start: adres niet gevonden',
    HhPaden.jongere,
    () => fakeJongereBuitenGebied(werkgebied: HhWerkgebiedStatus.onbekend),
  ),
  'start laadfout': _Geval(
    'Start: laadfout',
    HhPaden.jongere,
    () => fakeNieuweJongere()..isOffline = true,
  ),
};

Future<void> _pomp(
  WidgetTester tester,
  String sleutel, {
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) async {
  await tester.pumpWidget(
    hhJongereWikkel(
      _gevallen[sleutel]!.pad,
      profielGateway: _gevallen[sleutel]!.fake(),
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _knop(String label) => find.widgetWithText(HhKnop, label);

void main() {
  for (final MapEntry(key: sleutel, value: geval) in _gevallen.entries) {
    group(geval.naam, () {
      for (final dichtheid in HhDichtheid.values) {
        testWidgets('rendert in dichtheid $dichtheid met semantiek', (
          tester,
        ) async {
          await _pomp(tester, sleutel, dichtheid: dichtheid);

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
          sleutel,
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        );

        expect(tester.takeException(), isNull);
      });
    });
  }

  group('inhoud J9', () {
    testWidgets('18+ leeg: ID, VOG en over mij open, versturen uit', (
      tester,
    ) async {
      await _pomp(tester, 'j9 leeg');

      expect(find.text(TekstenAanmeldenNl.overzichtUitlegVog), findsOneWidget);
      for (final titel in [
        TekstenJongereNl.j2Titel,
        TekstenJongereNl.j4Titel,
        TekstenAanmeldenNl.overMijNietVerplicht,
      ]) {
        expect(_knop(titel), findsOneWidget, reason: titel);
      }
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
      final versturen = _knop(TekstenAanmeldenNl.overzichtVersturen);
      expect(tester.widget<HhKnop>(versturen).isActief, isFalse);
      expect(find.byType(HhTerugKnop), findsNothing);
      expect(find.byType(HhScreeningPil), findsOneWidget);
    });

    testWidgets('onder 18: geen VOG-stap, wel de stap Ouder in het balkje', (
      tester,
    ) async {
      await _pomp(tester, 'j9 leeg jong');

      expect(_knop(TekstenJongereNl.j4Titel), findsNothing);
      expect(find.text(TekstenAanmeldenNl.overzichtUitleg), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.stapOuder), findsOneWidget);
    });

    testWidgets('18+: geen stap Ouder in het balkje', (tester) async {
      await _pomp(tester, 'j9 leeg');

      expect(find.byType(AanmeldStappen), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.stapOuder), findsNothing);
      expect(find.text(TekstenAanmeldenNl.stapJij), findsOneWidget);
    });

    testWidgets('met ID-foto: versturen aan (VOG en over mij hoeven niet)', (
      tester,
    ) async {
      await _pomp(tester, 'j9 klaar');

      final versturen = _knop(TekstenAanmeldenNl.overzichtVersturen);
      expect(tester.widget<HhKnop>(versturen).isActief, isTrue);
    });

    testWidgets('in behandeling: wachttekst, Naar de start, niet versturen', (
      tester,
    ) async {
      await _pomp(tester, 'j9 behandeling');

      expect(find.text(TekstenJongereNl.j9WachtTekst), findsOneWidget);
      expect(_knop(TekstenAanmeldenNl.naarStart), findsOneWidget);
      expect(_knop(TekstenAanmeldenNl.overzichtVersturen), findsNothing);
    });

    testWidgets('afgewezen: tekst en Bel ons', (tester) async {
      await _pomp(tester, 'j9 afgewezen');

      expect(find.text(TekstenJongereNl.j9AfgewezenTekst), findsOneWidget);
      expect(_knop(TekstenJongereNl.j9BelOns), findsOneWidget);
    });
  });

  group('inhoud stappen', () {
    testWidgets('ID: BSN afdekken, tip KopieID, camera en galerij', (
      tester,
    ) async {
      await _pomp(tester, 'id leeg');

      expect(find.text(TekstenJongereNl.j2NietZichtbaar), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.idTipKopieId), findsOneWidget);
      expect(_knop(TekstenJongereNl.fotoMaken), findsOneWidget);
      expect(_knop(TekstenJongereNl.fotoKiezen), findsOneWidget);
    });

    testWidgets('ID gecontroleerd: geen upload meer, wel de uitleg', (
      tester,
    ) async {
      await _pomp(tester, 'id gecontroleerd');

      expect(find.text(TekstenAanmeldenNl.idNaGoedkeuring), findsOneWidget);
      expect(_knop(TekstenJongereNl.fotoMaken), findsNothing);
      expect(_knop(TekstenJongereNl.fotoKiezen), findsNothing);
    });

    testWidgets('VOG: uitleg Justis en meldkamer, nog niet gezien', (
      tester,
    ) async {
      await _pomp(tester, 'vog leeg');

      expect(find.text(TekstenAanmeldenNl.vogUitleg), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.vogNogNietGezien), findsOneWidget);
      expect(_knop(TekstenJongereNl.j4Aanvragen), findsOneWidget);
      expect(_knop(TekstenJongereNl.j4HebAangevraagd), findsOneWidget);
    });

    testWidgets('VOG gezien: datum, geen knoppen meer', (tester) async {
      await _pomp(tester, 'vog gezien');

      expect(
        find.text(TekstenAanmeldenNl.vogGezienOp('20-09-2026')),
        findsOneWidget,
      );
      expect(_knop(TekstenJongereNl.j4Aanvragen), findsNothing);
    });

    testWidgets('Aanmelding binnen: stap Klaar en Naar de start', (
      tester,
    ) async {
      await _pomp(tester, 'binnen');

      expect(find.text(TekstenAanmeldenNl.binnenKop), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.binnenUitleg), findsOneWidget);
      expect(_knop(TekstenAanmeldenNl.naarStart), findsOneWidget);
    });
  });

  group('Start van de helper (gele balk)', () {
    testWidgets('alles rond: klussen en de tabbalk, geen balk', (tester) async {
      await _pomp(tester, 'start klaar');

      // B10: de Start toont "Klussen bij jou in de buurt".
      expect(find.text(TekstenStartNl.inDeBuurtKop), findsOneWidget);
      expect(find.byType(JongereTabbalk), findsOneWidget);
      expect(find.byType(WachtBalk), findsNothing);
    });

    for (final (sleutel, kop) in [
      ('start buiten', TekstenAanmeldenNl.nietInBuurtKop),
      ('start adres onbekend', TekstenAanmeldenNl.adresOnbekendKop),
      ('start nagekeken', TekstenAanmeldenNl.wachtNagekeken),
      ('start ouder', TekstenAanmeldenNl.wachtOuder),
      ('start vog', TekstenAanmeldenNl.wachtVog),
    ]) {
      testWidgets('$sleutel: balk "$kop" en geen klussen', (tester) async {
        await _pomp(tester, sleutel);

        expect(find.byType(WachtBalk), findsOneWidget);
        expect(find.text(kop), findsOneWidget);
        expect(find.text(TekstenAanmeldenNl.wachtGeenKlussen), findsOneWidget);
        expect(find.byType(JongereTabbalk), findsOneWidget);
        expect(find.text(TekstenKlussenNl.weergaveLijst), findsNothing);
      });
    }

    testWidgets('wacht op VOG: knop naar de uitleg', (tester) async {
      await _pomp(tester, 'start vog');

      await tikKnop(tester, TekstenAanmeldenNl.wachtVogKnop);
      expect(find.text(TekstenAanmeldenNl.vogUitleg), findsOneWidget);
    });
  });
}

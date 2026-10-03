import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/screen/aanmelding_binnen_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_overzicht_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_jongere_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../../../support/hh_jongere_wikkel.dart';

Future<void> _pomp(
  WidgetTester tester,
  String pad, {
  required FakeProfielGateway fake,
  FakeFotoKiezer? fotoKiezer,
  bool urlOpenerLukt = true,
}) async {
  await tester.pumpWidget(
    hhJongereWikkel(
      pad,
      profielGateway: fake,
      fotoKiezer: fotoKiezer,
      urlOpenerLukt: urlOpenerLukt,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ID-foto', () {
    testWidgets(
      'foto uit de galerij gaat naar document_foto; profiel ontstaat',
      (tester) async {
        final fake = fakeNieuweJongere();
        final kiezer = FakeFotoKiezer(volgende: testFoto('id.png'));
        await _pomp(
          tester,
          HhPadenJongere.identiteit,
          fake: fake,
          fotoKiezer: kiezer,
        );
        final verder = find.widgetWithText(HhKnop, TekstenNl.verder);
        expect(tester.widget<HhKnop>(verder).isActief, isFalse);

        await tikKnop(tester, TekstenJongereNl.fotoKiezen);

        expect(kiezer.aanroepen, [HhFotoBron.galerij]);
        expect(fake.uploads.single.veld, 'document_foto');
        expect(fake.uploads.single.bestandsnaam, 'id.png');
        expect(fake.profielVan(jongereId)!.heeftDocumentFoto, isTrue);
        expect(find.text(TekstenJongereNl.opgeslagen), findsOneWidget);
        expect(tester.widget<HhKnop>(verder).isActief, isTrue);

        await tikKnop(tester, TekstenNl.verder);
        expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      },
    );

    testWidgets('annuleren doet niets; camera-fout geeft een waarschuwing', (
      tester,
    ) async {
      final fake = fakeNieuweJongere();
      final kiezer = FakeFotoKiezer();
      await _pomp(
        tester,
        HhPadenJongere.identiteit,
        fake: fake,
        fotoKiezer: kiezer,
      );

      await tikKnop(tester, TekstenJongereNl.fotoKiezen);
      expect(fake.uploads, isEmpty);

      kiezer.volgendeFout = const HhFout(HhFoutSoort.onbekend);
      await tikKnop(tester, TekstenJongereNl.fotoMaken);
      expect(kiezer.aanroepen.last, HhFotoBron.camera);
      expect(find.text(TekstenJongereNl.fotoCameraLuktNiet), findsOneWidget);
      expect(fake.uploads, isEmpty);
    });

    testWidgets('een mislukte upload toont de melding van de server', (
      tester,
    ) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      final kiezer = FakeFotoKiezer(volgende: testFoto());
      await _pomp(
        tester,
        HhPadenJongere.identiteit,
        fake: fake,
        fotoKiezer: kiezer,
      );

      fake.volgendeFout = const HhFout(HhFoutSoort.geenVerbinding);
      await tikKnop(tester, TekstenJongereNl.fotoMaken);

      expect(
        find.text(const HhFout(HhFoutSoort.geenVerbinding).melding),
        findsOneWidget,
      );
    });

    testWidgets('na goedkeuring weigert de fake (zoals de server) een nieuwe', (
      tester,
    ) async {
      final fake = fakeJongereMetStatus(HhScreeningStatus.goedgekeurd);
      final upload = await fake.uploadIdFoto(
        profielId: fake.profielVan(jongereId)!.id,
        bytes: testFotoBytes,
        bestandsnaam: 'x.png',
      );
      expect(upload, isA<Err<HhProfiel>>());
      expect(fake.uploads, isEmpty);
    });
  });

  group('VOG', () {
    testWidgets('Ik heb aangevraagd zet vog_aangevraagd_op', (tester) async {
      final fake = fakeNieuweJongere();
      await _pomp(tester, HhPadenJongere.vog, fake: fake);

      await tikKnop(tester, TekstenJongereNl.j4HebAangevraagd);

      expect(fake.laatsteProfielBody!.keys, ['vog_aangevraagd_op']);
      expect(fake.profielVan(jongereId)!.vogAangevraagdOp, isNotNull);
      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.j4HebAangevraagd),
        findsNothing,
      );
    });

    testWidgets('VOG aanvragen zonder browser geeft een waarschuwing', (
      tester,
    ) async {
      await _pomp(
        tester,
        HhPadenJongere.vog,
        fake: fakeNieuweJongere(),
        urlOpenerLukt: false,
      );

      await tikKnop(tester, TekstenJongereNl.j4Aanvragen);

      expect(find.text(TekstenJongereNl.j4AanvragenLuktNiet), findsOneWidget);
    });
  });

  group('Over mij', () {
    testWidgets('opslaan stuurt alleen over_mij en gaat terug naar J9', (
      tester,
    ) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      await _pomp(tester, HhPadenJongere.overMij, fake: fake);

      await vulVeld(tester, 0, 'Ik help graag in de tuin.');
      await tikKnop(tester, TekstenAanmeldenNl.opslaan);

      expect(fake.laatsteProfielBody, {
        'over_mij': 'Ik help graag in de tuin.',
      });
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
    });

    testWidgets('leeg laten mag: geen verzoek, wel terug', (tester) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      await _pomp(tester, HhPadenJongere.overMij, fake: fake);

      await tikKnop(tester, TekstenAanmeldenNl.opslaan);

      expect(fake.laatsteProfielBody, isNull);
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
    });

    testWidgets('meer dan 500 tekens wordt geweigerd', (tester) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      await _pomp(tester, HhPadenJongere.overMij, fake: fake);

      await vulVeld(tester, 0, 'a' * 501);
      await tikKnop(tester, TekstenAanmeldenNl.opslaan);

      expect(
        find.text(TekstenAanmeldenNl.validatieOverMijTeLang),
        findsOneWidget,
      );
      expect(fake.laatsteProfielBody, isNull);
    });
  });

  group('J9 versturen', () {
    testWidgets('stuurt alleen verificatiestatus en toont Aanmelding binnen', (
      tester,
    ) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      await _pomp(tester, HhPadenJongere.overzicht, fake: fake);

      await tikKnop(tester, TekstenAanmeldenNl.overzichtVersturen);

      expect(fake.laatsteProfielBody, {'verificatiestatus': 'in_behandeling'});
      expect(
        fake.profielVan(jongereId)!.verificatiestatus,
        HhScreeningStatus.inBehandeling,
      );
      expect(find.byType(AanmeldingBinnenScreen), findsOneWidget);
    });

    testWidgets('een fout blijft op J9 met de melding', (tester) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      await _pomp(tester, HhPadenJongere.overzicht, fake: fake);

      fake.volgendeFout = const HhFout(HhFoutSoort.geenVerbinding);
      await tikKnop(tester, TekstenAanmeldenNl.overzichtVersturen);

      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(
        find.text(const HhFout(HhFoutSoort.geenVerbinding).melding),
        findsOneWidget,
      );
    });

    testWidgets('afgewezen: Bel ons zonder telefoon geeft een waarschuwing', (
      tester,
    ) async {
      await _pomp(
        tester,
        HhPadenJongere.overzicht,
        fake: fakeJongereMetStatus(HhScreeningStatus.afgewezen),
        urlOpenerLukt: false,
      );

      await tikKnop(tester, TekstenJongereNl.j9BelOns);

      expect(find.textContaining('0800'), findsWidgets);
    });
  });
}

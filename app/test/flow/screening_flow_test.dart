import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/screen/mijn_reputatie_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/aanmelding_binnen_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_foto_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_overzicht_screen.dart';
import 'package:heitjehulp_app/features/jongere/widget/helper_wacht_start.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_beoordelen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_jongere_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../support/hh_jongere_wikkel.dart';
import '../support/hh_toegang_wikkel.dart';

const _tokenSleutel = 'hh_auth_token';

GeheugenKeyValueStore _ingelogdAls(HhRol rol) =>
    GeheugenKeyValueStore({_tokenSleutel: testToken(rol)});

/// De klussenlijst (en dus de schakelaar lijst/kaart) staat op Start.
Finder get _klussenLijst => find.text(TekstenKlussenNl.weergaveLijst);

void main() {
  testWidgets(
    'nieuwe helper 18+: inloggen -> J9 -> ID-foto -> versturen -> binnen -> '
    'Start met "nagekeken" -> goedgekeurd: "Regel je VOG" -> VOG gezien: klussen',
    (tester) async {
      final fake = fakeNieuweJongere();
      final kiezer = FakeFotoKiezer(volgende: testFoto());
      await pompJongereApp(tester, profielGateway: fake, fotoKiezer: kiezer);

      // Inloggen als helper landt door de guard op J9, niet op Start.
      await tikKnop(tester, TekstenNl.alEenAccount);
      await vulVeld(tester, 0, testGebruiker(HhRol.jongere).email);
      await vulVeld(tester, 1, testWachtwoord);
      await tikKnop(tester, TekstenNl.inloggenKnop);
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(find.byType(JongereStubScreen), findsNothing);
      final versturen = find.widgetWithText(
        HhKnop,
        TekstenAanmeldenNl.overzichtVersturen,
      );
      expect(tester.widget<HhKnop>(versturen).isActief, isFalse);

      // ID-foto
      await tikKnop(tester, TekstenJongereNl.j2Titel);
      expect(find.byType(ScreeningIdentiteitScreen), findsOneWidget);
      await tikKnop(tester, TekstenJongereNl.fotoKiezen);
      await tikKnop(tester, TekstenNl.verder);

      // Versturen -> Aanmelding binnen -> Start met de gele balk.
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      await tikKnop(tester, TekstenAanmeldenNl.overzichtVersturen);
      expect(find.byType(AanmeldingBinnenScreen), findsOneWidget);
      await tikKnop(tester, TekstenAanmeldenNl.naarStart);
      expect(find.byType(JongereStubScreen), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.wachtNagekeken), findsOneWidget);
      expect(_klussenLijst, findsNothing);

      // De meldkamer keurt goed (ID-foto gewist), maar zag de VOG nog niet.
      fake.zetStatus(
        jongereId,
        verificatiestatus: HhScreeningStatus.goedgekeurd,
      );
      expect(fake.profielVan(jongereId)!.heeftDocumentFoto, isFalse);
      await tikKnop(tester, TekstenAanmeldenNl.wachtVernieuwen);
      expect(find.text(TekstenAanmeldenNl.wachtVog), findsOneWidget);
      expect(_klussenLijst, findsNothing);

      // De meldkamer zet "VOG gezien op".
      fake.zetVogGezien(jongereId, DateTime.utc(2026, 10, 3));
      await tikKnop(tester, TekstenAanmeldenNl.wachtVernieuwen);
      expect(find.byType(WachtBalk), findsNothing);
      expect(_klussenLijst, findsOneWidget);
    },
  );

  testWidgets(
    'helper onder 18: geen VOG-stap; na goedkeuring wacht hij op zijn ouder',
    (tester) async {
      final fake = fakeNieuweJongere(isMinderjarig: true);
      await pompJongereApp(
        tester,
        profielGateway: fake,
        fotoKiezer: FakeFotoKiezer(volgende: testFoto()),
        opslag: _ingelogdAls(HhRol.jongere),
      );
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenJongereNl.j4Titel),
        findsNothing,
      );
      expect(find.text(TekstenAanmeldenNl.stapOuder), findsOneWidget);

      await tikKnop(tester, TekstenJongereNl.j2Titel);
      await tikKnop(tester, TekstenJongereNl.fotoKiezen);
      await tikKnop(tester, TekstenNl.verder);
      await tikKnop(tester, TekstenAanmeldenNl.overzichtVersturen);
      await tikKnop(tester, TekstenAanmeldenNl.naarStart);

      fake.zetStatus(
        jongereId,
        verificatiestatus: HhScreeningStatus.goedgekeurd,
      );
      await tikKnop(tester, TekstenAanmeldenNl.wachtVernieuwen);
      expect(find.text(TekstenAanmeldenNl.wachtOuder), findsOneWidget);
      expect(_klussenLijst, findsNothing);

      // De ouder geeft toestemming (B3: met een code; nu de meldkamer).
      fake.zetAccount(
        jongereId,
        HhAccountGegevens(
          geboortedatum: jongGeboren,
          wijkId: 'wijk-west',
          ouderToestemmingOp: DateTime.utc(2026, 10, 3),
        ),
      );
      await tikKnop(tester, TekstenAanmeldenNl.wachtVernieuwen);
      expect(_klussenLijst, findsOneWidget);
    },
  );

  testWidgets('wachtend: een klus openen gaat terug naar Start', (
    tester,
  ) async {
    final container = await pompJongereApp(
      tester,
      profielGateway: fakeJongereGoedgekeurdWachtend(),
      opslag: _ingelogdAls(HhRol.jongere),
    );
    expect(find.text(TekstenAanmeldenNl.wachtVog), findsOneWidget);

    container.read(routerProvider).go(HhPadenKlussen.klusDetail('k1'));
    await tester.pumpAndSettle();
    expect(find.byType(JongereStubScreen), findsOneWidget);
    expect(find.text(TekstenAanmeldenNl.wachtVog), findsOneWidget);

    // De tabs blijven bereikbaar.
    container.read(routerProvider).go(HhPadenKlussen.instellingen);
    await tester.pumpAndSettle();
    expect(find.text(TekstenNl.instellingenTitel), findsWidgets);
    expect(find.byType(JongereStubScreen), findsNothing);
  });

  testWidgets(
    'helper die rond is landt op Start (klussen) en bereikt J9 via Profiel',
    (tester) async {
      await pompJongereApp(
        tester,
        profielGateway: fakeJongereMetStatus(HhScreeningStatus.goedgekeurd),
        opslag: _ingelogdAls(HhRol.jongere),
      );

      expect(find.byType(JongereStubScreen), findsOneWidget);
      expect(_klussenLijst, findsOneWidget);

      await tikTekst(tester, TekstenKlussenNl.tabProfiel);
      expect(find.byType(MijnReputatieScreen), findsOneWidget);
      await tikKnop(tester, TekstenBeoordelenNl.j19Screening);
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(find.text(TekstenJongereNl.statusGoedgekeurd), findsWidgets);

      await tikKnop(tester, TekstenAanmeldenNl.naarStart);
      expect(find.byType(JongereStubScreen), findsOneWidget);
    },
  );

  for (final status in [HhScreeningStatus.nieuw, HhScreeningStatus.afgewezen]) {
    testWidgets('guard: helper met status ${status.code} gaat naar J9', (
      tester,
    ) async {
      final container = await pompJongereApp(
        tester,
        profielGateway: fakeJongereMetStatus(status),
        opslag: _ingelogdAls(HhRol.jongere),
      );

      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      container.read(routerProvider).go(HhPaden.jongere);
      await tester.pumpAndSettle();
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      if (status == HhScreeningStatus.afgewezen) {
        expect(
          find.widgetWithText(HhKnop, TekstenJongereNl.j9BelOns),
          findsOneWidget,
        );
      }
    });
  }

  testWidgets(
    'guard: een bewoner op een aanmeldpad gaat naar de eigen landing',
    (tester) async {
      final container = await pompJongereApp(
        tester,
        profielGateway: fakeNieuweJongere(),
        opslag: _ingelogdAls(HhRol.hulpvrager),
      );
      expect(find.byType(HulpvragerStubScreen), findsOneWidget);

      container.read(routerProvider).go(HhPadenJongere.overzicht);
      await tester.pumpAndSettle();
      expect(find.byType(ScreeningOverzichtScreen), findsNothing);
      expect(find.byType(HulpvragerStubScreen), findsOneWidget);
    },
  );

  testWidgets('uitgelogd: een aanmeldpad gaat naar welkom', (tester) async {
    final container = await pompJongereApp(
      tester,
      profielGateway: fakeNieuweJongere(),
    );

    container.read(routerProvider).go(HhPadenJongere.identiteit);
    await tester.pumpAndSettle();
    expect(find.byType(ScreeningIdentiteitScreen), findsNothing);
    expect(find.text(TekstenNl.welkomTitel), findsOneWidget);
  });
}

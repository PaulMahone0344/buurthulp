import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/screen/mijn_reputatie_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_beschikbaarheid_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_foto_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_iban_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_klussoorten_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_overzicht_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_profiel_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_vog_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_werkgebied_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_beoordelen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_jongere_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../support/hh_jongere_wikkel.dart';
import '../support/hh_toegang_wikkel.dart';

const _tokenSleutel = 'hh_auth_token';

GeheugenKeyValueStore _ingelogdAls(HhRol rol) =>
    GeheugenKeyValueStore({_tokenSleutel: testToken(rol)});

void main() {
  testWidgets(
    'nieuwe jongere: inloggen -> J9 -> J1 t/m J8 -> indienen -> in behandeling',
    (tester) async {
      final fake = fakeNieuweJongere();
      final kiezer = FakeFotoKiezer(volgende: testFoto());
      await pompJongereApp(tester, profielGateway: fake, fotoKiezer: kiezer);

      // Inloggen als jongere landt door de guard op het overzicht, niet op /jongere.
      await tikKnop(tester, TekstenNl.alEenAccount);
      await vulVeld(tester, 0, testGebruiker(HhRol.jongere).email);
      await vulVeld(tester, 1, testWachtwoord);
      await tikKnop(tester, TekstenNl.inloggenKnop);
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(find.byType(JongereStubScreen), findsNothing);
      expect(
        tester
            .widget<HhKnop>(
              find.widgetWithText(HhKnop, TekstenJongereNl.j9Indienen),
            )
            .isActief,
        isFalse,
      );

      // J1
      await tikKnop(tester, '1. ${TekstenJongereNl.j1Titel}');
      expect(find.byType(ScreeningProfielScreen), findsOneWidget);
      await tikKnop(tester, TekstenJongereNl.fotoKiezen);
      await vulVeld(tester, 0, '14-05-2008');
      await vulVeld(tester, 1, 'Ik help graag met boodschappen.');
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      // J2
      expect(find.byType(ScreeningIdentiteitScreen), findsOneWidget);
      await tikKnop(tester, TekstenJongereNl.fotoKiezen);
      await tikKnop(tester, TekstenNl.verder);

      // J3
      expect(find.byType(ScreeningSelfieScreen), findsOneWidget);
      await tikKnop(tester, TekstenJongereNl.j3Knop);
      await tikKnop(tester, TekstenNl.verder);

      // J4
      expect(find.byType(ScreeningVogScreen), findsOneWidget);
      await tikKnop(tester, TekstenJongereNl.j4HebAangevraagd);
      await tikKnop(tester, TekstenNl.verder);

      // J5
      expect(find.byType(ScreeningIbanScreen), findsOneWidget);
      await vulVeld(tester, 0, 'NL91 ABNA 0417 1643 00');
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      // J6
      expect(find.byType(ScreeningWerkgebiedScreen), findsOneWidget);
      await tikTekst(tester, 'Tiel-West');
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      // J7
      expect(find.byType(ScreeningBeschikbaarheidScreen), findsOneWidget);
      await tikTekst(tester, TekstenJongereNl.dagdeelMiddag);
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      // J8
      expect(find.byType(ScreeningKlussoortenScreen), findsOneWidget);
      await tikTekst(tester, 'boodschappen');
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      // J9: alles af, indienen.
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      final indienen = find.widgetWithText(HhKnop, TekstenJongereNl.j9Indienen);
      expect(tester.widget<HhKnop>(indienen).isActief, isTrue);
      await tikKnop(tester, TekstenJongereNl.j9Indienen);

      expect(find.text(TekstenJongereNl.j9WachtTekst), findsOneWidget);
      expect(fake.laatsteProfielBody, {'verificatiestatus': 'in_behandeling'});
      final profiel = fake.profielVan(jongereId)!;
      expect(profiel.verificatiestatus, HhScreeningStatus.inBehandeling);
      expect(profiel.iban, 'NL91ABNA0417164300');
      expect(profiel.klustypeIds, {'type-boodschappen'});
      expect(profiel.straalKm, ScreeningWerkgebiedScreen.standaardStraal);
      expect(fake.accountVan(jongereId).wijkId, 'wijk-west');
      expect(fake.uploads.map((u) => u.veld), [
        'foto',
        'document_foto',
        'selfie',
      ]);
      expect(kiezer.aanroepen.map((a) => a.isSelfie), [false, false, true]);
    },
  );

  testWidgets(
    'guard: goedgekeurde jongere landt op /jongere (J11) en bereikt J9 via de tab Profiel',
    (tester) async {
      await pompJongereApp(
        tester,
        profielGateway: fakeJongereMetStatus(HhScreeningStatus.goedgekeurd),
        opslag: _ingelogdAls(HhRol.jongere),
      );

      expect(find.byType(JongereStubScreen), findsOneWidget);
      expect(find.text(TekstenKlussenNl.j11Titel), findsOneWidget);

      // M7: de tab Profiel is J19; J9 zit onder "Mijn screening".
      await tikTekst(tester, TekstenKlussenNl.tabProfiel);
      expect(find.byType(MijnReputatieScreen), findsOneWidget);
      await tikKnop(tester, TekstenBeoordelenNl.j19Screening);
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(find.text(TekstenJongereNl.statusGoedgekeurd), findsWidgets);

      await tikKnop(tester, TekstenJongereNl.j9NaarKlussen);
      expect(find.byType(JongereStubScreen), findsOneWidget);
    },
  );

  for (final status in [
    HhScreeningStatus.nieuw,
    HhScreeningStatus.inBehandeling,
    HhScreeningStatus.afgewezen,
  ]) {
    testWidgets(
      'guard: jongere met status ${status.code} gaat van /jongere naar J9',
      (tester) async {
        final container = await pompJongereApp(
          tester,
          profielGateway: fakeJongereMetStatus(status),
          opslag: _ingelogdAls(HhRol.jongere),
        );

        expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
        expect(find.byType(JongereStubScreen), findsNothing);
        expect(find.text(status.naam), findsOneWidget);
        if (status == HhScreeningStatus.afgewezen) {
          expect(
            find.widgetWithText(HhKnop, TekstenJongereNl.j9BelOns),
            findsOneWidget,
          );
        }

        // Ook een directe sprong naar /jongere komt terug op J9.
        container.read(routerProvider).go(HhPaden.jongere);
        await tester.pumpAndSettle();
        expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);

        // Instellingen blijven bereikbaar; uitloggen werkt.
        container.read(routerProvider).go(HhPaden.instellingen);
        await tester.pumpAndSettle();
        expect(find.text(TekstenNl.instellingenTitel), findsOneWidget);
      },
    );
  }

  testWidgets(
    'J9: na goedkeuring door de meldkamer brengt Status vernieuwen naar /jongere',
    (tester) async {
      final fake = fakeJongereMetStatus(HhScreeningStatus.inBehandeling);
      await pompJongereApp(
        tester,
        profielGateway: fake,
        opslag: _ingelogdAls(HhRol.jongere),
      );
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(find.text(TekstenJongereNl.j9WachtTekst), findsOneWidget);

      // De meldkamer keurt goed, buiten de app om.
      fake.zetStatus(
        jongereId,
        verificatiestatus: HhScreeningStatus.goedgekeurd,
      );
      await tikKnop(tester, TekstenJongereNl.j9Vernieuwen);

      expect(find.text(TekstenJongereNl.j9GoedgekeurdTekst), findsOneWidget);
      await tikKnop(tester, TekstenJongereNl.j9NaarKlussen);
      expect(find.byType(JongereStubScreen), findsOneWidget);
    },
  );

  testWidgets(
    'guard: een hulpvrager op een screeningpad gaat naar de eigen landing',
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

  testWidgets('uitgelogd: een screeningpad gaat naar welkom', (tester) async {
    final container = await pompJongereApp(
      tester,
      profielGateway: fakeNieuweJongere(),
    );

    container.read(routerProvider).go(HhPadenJongere.profiel);
    await tester.pumpAndSettle();
    expect(find.byType(ScreeningProfielScreen), findsNothing);
    expect(find.text(TekstenNl.welkomTitel), findsOneWidget);
  });
}

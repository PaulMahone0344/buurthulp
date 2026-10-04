import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_auth_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_stub_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/adres/domein/adres_invoer.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/screen/bevestig_email_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/inloggen_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/registreren_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/splash_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/welkom_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_adres_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:heitjehulp_app/l10n/teksten_start_nl.dart';

import '../support/hh_toegang_wikkel.dart';

const _tokenSleutel = 'hh_auth_token';

Type _landingVan(HhRol rol) => switch (rol) {
  HhRol.hulpvrager => HulpvragerStubScreen,
  HhRol.jongere => JongereStubScreen,
  HhRol.coordinator => CoordinatorStubScreen,
};

HhDichtheid _dichtheid(WidgetTester tester) =>
    tester.widget<HhDichtheidScope>(find.byType(HhDichtheidScope)).dichtheid;

Future<void> _tik(WidgetTester tester, String label) async {
  final knop = find.widgetWithText(HhKnop, label);
  await tester.ensureVisible(knop);
  await tester.tap(knop);
  await tester.pumpAndSettle();
}

Future<void> _vul(WidgetTester tester, int index, String tekst) async {
  final veld = find.byType(TextField).at(index);
  await tester.ensureVisible(veld);
  await tester.enterText(veld, tekst);
}

/// ADRES: na postcode + huisnummer zoekt het formulier (nep-PDOK) na de
/// wachttijd het adres op.
Future<void> _wachtOpAdres(WidgetTester tester) async {
  await tester.pump(adresZoekWachttijd);
  await tester.pumpAndSettle();
}

Future<void> _vinkAkkoord(WidgetTester tester) async {
  final vinkje = find.byType(Checkbox);
  await tester.ensureVisible(vinkje);
  await tester.pumpAndSettle();
  await tester.tap(vinkje);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('zonder token: splash gaat naar welkom', (tester) async {
    await pompApp(tester, gateway: fakeMetAlleRollen());

    expect(find.byType(WelkomScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(_dichtheid(tester), HhDichtheid.normaal);
  });

  testWidgets(
    'registreren als bewoner: G2 -> G4 -> G5 -> /hulpvrager, letters normaal',
    (tester) async {
      final gateway = fakeMetAlleRollen();
      await pompApp(tester, gateway: gateway);

      await _tik(tester, TekstenNl.keuzeZoekHulp);
      expect(find.byType(RegistrerenScreen), findsOneWidget);
      // Sinds 3 okt geen verschil per rol: grote letters is een schakelaar.
      expect(_dichtheid(tester), HhDichtheid.normaal);
      expect(find.text(TekstenAanmeldenNl.adresUitleg), findsOneWidget);

      // ADRES: geen straat- of plaatsveld meer; die komen van PDOK.
      expect(find.text('Straat'), findsNothing);
      await _vul(tester, 0, 'Mevrouw Jansen');
      await _vul(tester, 1, 'jansen@voorbeeld.nl');
      await _vul(tester, 2, '4001ma');
      await _vul(tester, 3, '1');
      await _wachtOpAdres(tester);
      expect(find.text('Kerkstraat 1, 4001 MA Tiel'), findsOneWidget);
      await _vul(tester, 5, 'wachtwoord1');
      await _vinkAkkoord(tester);
      await _tik(tester, TekstenNl.registrerenKnop);

      expect(find.byType(BevestigEmailScreen), findsOneWidget);
      expect(gateway.laatsteRegistratieBody, {
        'postcode': '4001 MA',
        'huisnummer': '1',
        'toevoeging': '',
        'adres': 'Kerkstraat 1',
        'plaats': 'Tiel',
        'naam': 'Mevrouw Jansen',
        'email': 'jansen@voorbeeld.nl',
        'rol': 'hulpvrager',
        'taal': 'nl',
      });

      await _tik(tester, TekstenNl.verder);

      expect(find.byType(HulpvragerStubScreen), findsOneWidget);
      expect(_dichtheid(tester), HhDichtheid.normaal);
      expect(
        find.text(TekstenNl.landingWelkom('Mevrouw Jansen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'bewoner buiten het werkgebied: aanmelden lukt, maar geen klus plaatsen',
    (tester) async {
      final gateway = fakeMetAlleRollen();
      await pompApp(tester, gateway: gateway);
      await _tik(tester, TekstenNl.keuzeZoekHulp);

      await _vul(tester, 0, 'Meneer Amsterdam');
      await _vul(tester, 1, 'adam@voorbeeld.nl');
      await _vul(tester, 2, '1012 JS');
      await _vul(tester, 3, '1');
      await _wachtOpAdres(tester);
      // Meteen na het opzoeken: nog niet in jouw buurt (aanmelden mag wel).
      expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsOneWidget);
      await _vul(tester, 5, 'wachtwoord1');
      await _vinkAkkoord(tester);
      await _tik(tester, TekstenNl.registrerenKnop);
      expect(find.byType(BevestigEmailScreen), findsOneWidget);
      await _tik(tester, TekstenNl.verder);

      expect(find.byType(HulpvragerStubScreen), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsOneWidget);
      expect(find.text(TekstenHulpvragerNl.homeHulpVragen), findsNothing);
    },
  );

  testWidgets(
    'bewoner: lege velden en geen vinkje geven fouten, geen verzoek',
    (tester) async {
      final gateway = fakeMetAlleRollen();
      await pompApp(tester, gateway: gateway);
      await _tik(tester, TekstenNl.keuzeZoekHulp);

      await _tik(tester, TekstenNl.registrerenKnop);

      for (final fout in [
        TekstenNl.validatieNaamVerplicht,
        TekstenNl.validatieEmailVerplicht,
        TekstenAdresNl.validatieVerplicht,
        TekstenNl.validatieWachtwoordTeKort,
        TekstenAanmeldenNl.validatieAkkoord,
      ]) {
        expect(find.text(fout), findsOneWidget, reason: fout);
      }
      expect(gateway.laatsteRegistratieBody, isNull);
      expect(find.byType(RegistrerenScreen), findsOneWidget);
    },
  );

  group('registreren als strijder', () {
    Future<void> naarHelper(
      WidgetTester tester,
      FakeAuthGateway gateway,
    ) async {
      await pompApp(tester, gateway: gateway);
      await _tik(tester, TekstenNl.keuzeWilHelpen);
      expect(find.byType(RegistrerenScreen), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.stapJij), findsOneWidget);
    }

    Future<void> vulBasis(WidgetTester tester, String geboortedatum) async {
      await _vul(tester, 0, 'Daan');
      await _vul(tester, 1, geboortedatum);
      await tester.pump();
      await _vul(tester, 2, 'daan@voorbeeld.nl');
      await _vul(tester, 3, '4001 MA');
      await _vul(tester, 4, '1');
      await _wachtOpAdres(tester);
    }

    testWidgets('18+: geen ouderveld, stuurt geboortedatum en postcode mee', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await naarHelper(tester, gateway);

      await vulBasis(tester, '01-01-1990');
      expect(
        find.textContaining(TekstenAanmeldenNl.veldOuder, findRichText: true),
        findsNothing,
      );
      expect(find.text(TekstenAanmeldenNl.stapOuder), findsNothing);
      await _vul(tester, 6, 'wachtwoord1');
      await _vinkAkkoord(tester);
      await _tik(tester, TekstenNl.registrerenKnop);

      expect(find.byType(BevestigEmailScreen), findsOneWidget);
      expect(gateway.laatsteRegistratieBody, {
        'geboortedatum': '1990-01-01T00:00:00.000Z',
        'postcode': '4001 MA',
        'huisnummer': '1',
        'toevoeging': '',
        'adres': 'Kerkstraat 1',
        'plaats': 'Tiel',
        'naam': 'Daan',
        'email': 'daan@voorbeeld.nl',
        'rol': 'jongere',
        'taal': 'nl',
      });
    });

    testWidgets(
      'onder 18: alleen het e-mailadres van de ouder (geen 06 meer)',
      (tester) async {
        final gateway = fakeMetAlleRollen();
        await naarHelper(tester, gateway);

        await vulBasis(tester, '01-01-2012');
        expect(
          find.textContaining(TekstenAanmeldenNl.veldOuder, findRichText: true),
          findsOneWidget,
        );
        expect(find.text(TekstenAanmeldenNl.stapOuder), findsOneWidget);
        await _vul(tester, 7, 'wachtwoord1');
        await _vinkAkkoord(tester);
        await _tik(tester, TekstenNl.registrerenKnop);

        expect(
          find.text(TekstenAanmeldenNl.validatieOuderVerplicht),
          findsOneWidget,
        );
        expect(gateway.laatsteRegistratieBody, isNull);

        await _vul(tester, 6, 'mama');
        await _tik(tester, TekstenNl.registrerenKnop);
        expect(
          find.text(TekstenAanmeldenNl.validatieOuderOngeldig),
          findsOneWidget,
        );
        expect(gateway.laatsteRegistratieBody, isNull);

        await _vul(tester, 6, '06 12 34 56 78');
        await _tik(tester, TekstenNl.registrerenKnop);
        expect(
          find.text(TekstenAanmeldenNl.validatieOuderOngeldig),
          findsOneWidget,
        );
        expect(gateway.laatsteRegistratieBody, isNull);

        await _vul(tester, 6, 'mama@voorbeeld.nl');
        await _tik(tester, TekstenNl.registrerenKnop);
        expect(find.byType(BevestigEmailScreen), findsOneWidget);
        expect(
          gateway.laatsteRegistratieBody?['ouder_email'],
          'mama@voorbeeld.nl',
        );
        expect(
          gateway.laatsteRegistratieBody?.containsKey('ouder_telefoon'),
          isFalse,
        );
      },
    );

    testWidgets('onder de 10: geweigerd met uitleg, geen verzoek', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await naarHelper(tester, gateway);

      await vulBasis(tester, '01-01-2020');
      await _vul(tester, 6, 'wachtwoord1');
      await _vinkAkkoord(tester);
      await _tik(tester, TekstenNl.registrerenKnop);

      expect(find.text(TekstenAanmeldenNl.validatieTeJong), findsOneWidget);
      expect(gateway.laatsteRegistratieBody, isNull);
      expect(find.byType(RegistrerenScreen), findsOneWidget);
    });

    testWidgets('lege velden en een rare postcode geven fouten', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await naarHelper(tester, gateway);

      // De formatter maakt er "0401 MA" van; een 0 vooraan kan niet.
      await _vul(tester, 3, '0401ma');
      await _tik(tester, TekstenNl.registrerenKnop);

      for (final fout in [
        TekstenAanmeldenNl.validatieVoornaamVerplicht,
        TekstenAanmeldenNl.validatieGeboortedatumVerplicht,
        TekstenNl.validatieEmailVerplicht,
        TekstenAdresNl.validatiePostcode,
        TekstenAdresNl.validatieVerplicht,
        TekstenNl.validatieWachtwoordTeKort,
        TekstenAanmeldenNl.validatieAkkoord,
      ]) {
        expect(find.text(fout), findsOneWidget, reason: fout);
      }
      expect(gateway.laatsteRegistratieBody, isNull);
    });
  });

  for (final rol in HhRol.values) {
    testWidgets('inloggen als ${rol.code} landt op ${rol.pad}', (tester) async {
      final opslag = GeheugenKeyValueStore();
      await pompApp(tester, gateway: fakeMetAlleRollen(), opslag: opslag);

      await _tik(tester, TekstenNl.alEenAccount);
      expect(find.byType(InloggenScreen), findsOneWidget);

      await _vul(tester, 0, testGebruiker(rol).email);
      await _vul(tester, 1, testWachtwoord);
      await _tik(tester, TekstenNl.inloggenKnop);

      expect(find.byType(_landingVan(rol)), findsOneWidget);
      expect(_dichtheid(tester), HhDichtheid.normaal);
      expect(opslag.waarden[_tokenSleutel], testToken(rol));
    });
  }

  testWidgets('bewaard token: direct naar de rolroute; uitloggen -> G2', (
    tester,
  ) async {
    final opslag = GeheugenKeyValueStore({
      _tokenSleutel: testToken(HhRol.jongere),
    });
    await pompApp(tester, gateway: fakeMetAlleRollen(), opslag: opslag);

    expect(find.byType(JongereStubScreen), findsOneWidget);

    // B10: de landing van de jongere is de Start met een tabbalk; uitloggen
    // zit onder Profiel > Instellingen (G7).
    await tester.tap(find.text(TekstenKlussenNl.tabProfiel));
    await tester.pumpAndSettle();
    await _tik(tester, TekstenStartNl.instellingen);
    await _tik(tester, TekstenNl.uitloggen);

    expect(find.byType(WelkomScreen), findsOneWidget);
    expect(opslag.waarden.containsKey(_tokenSleutel), isFalse);
  });

  testWidgets('401 bij het opstarten: G3 met melding, token gewist', (
    tester,
  ) async {
    final opslag = GeheugenKeyValueStore({_tokenSleutel: 'verlopen-token'});
    final gateway = fakeMetAlleRollen()..tokenIsVerlopen = true;
    await pompApp(tester, gateway: gateway, opslag: opslag);

    expect(find.byType(InloggenScreen), findsOneWidget);
    expect(find.text(TekstenNl.foutSessieVerlopen), findsOneWidget);
    expect(opslag.waarden.containsKey(_tokenSleutel), isFalse);
  });

  testWidgets('offline bij het opstarten: splash met meldbalk en opnieuw', (
    tester,
  ) async {
    final opslag = GeheugenKeyValueStore({
      _tokenSleutel: testToken(HhRol.coordinator),
    });
    final gateway = fakeMetAlleRollen()..isOffline = true;
    await pompApp(tester, gateway: gateway, opslag: opslag);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
    expect(opslag.waarden[_tokenSleutel], testToken(HhRol.coordinator));

    gateway.isOffline = false;
    await _tik(tester, TekstenNl.opnieuwProberen);

    expect(find.byType(CoordinatorStubScreen), findsOneWidget);
  });

  testWidgets('offline bij inloggen: meldbalk, knop bruikbaar, daarna door', (
    tester,
  ) async {
    final gateway = fakeMetAlleRollen();
    await pompApp(tester, gateway: gateway);

    await _tik(tester, TekstenNl.alEenAccount);
    await _vul(tester, 0, testGebruiker(HhRol.coordinator).email);
    await _vul(tester, 1, testWachtwoord);
    gateway.isOffline = true;
    await _tik(tester, TekstenNl.inloggenKnop);

    expect(find.byType(InloggenScreen), findsOneWidget);
    expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);

    gateway.isOffline = false;
    await _tik(tester, TekstenNl.inloggenKnop);

    expect(find.byType(CoordinatorStubScreen), findsOneWidget);
  });

  testWidgets('verkeerde rolroute gaat naar de eigen rolroute', (tester) async {
    final opslag = GeheugenKeyValueStore({
      _tokenSleutel: testToken(HhRol.coordinator),
    });
    final container = await pompApp(
      tester,
      gateway: fakeMetAlleRollen(),
      opslag: opslag,
    );
    expect(find.byType(CoordinatorStubScreen), findsOneWidget);

    container.read(routerProvider).go(HhPaden.jongere);
    await tester.pumpAndSettle();
    expect(find.byType(JongereStubScreen), findsNothing);
    expect(find.byType(CoordinatorStubScreen), findsOneWidget);
  });
}

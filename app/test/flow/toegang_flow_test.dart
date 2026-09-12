import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_stub_screen.dart';
import 'package:heitjehulp_app/features/familie/screen/familie_stub_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/screen/bevestig_email_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/inloggen_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/registreren_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/splash_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/welkom_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../support/hh_toegang_wikkel.dart';

const _tokenSleutel = 'hh_auth_token';

Type _landingVan(HhRol rol) => switch (rol) {
  HhRol.hulpvrager => HulpvragerStubScreen,
  HhRol.jongere => JongereStubScreen,
  HhRol.familie => FamilieStubScreen,
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

Future<void> _vul(WidgetTester tester, int index, String tekst) =>
    tester.enterText(find.byType(TextField).at(index), tekst);

void main() {
  testWidgets('zonder token: splash gaat naar welkom', (tester) async {
    await pompApp(tester, gateway: fakeMetAlleRollen());

    expect(find.byType(WelkomScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(_dichtheid(tester), HhDichtheid.normaal);
  });

  testWidgets(
    'registreren als hulpvrager: G2 -> G4 groot -> G5 -> /hulpvrager groot',
    (tester) async {
      final gateway = fakeMetAlleRollen();
      await pompApp(tester, gateway: gateway);

      await _tik(tester, TekstenNl.keuzeZoekHulp);
      expect(find.byType(RegistrerenScreen), findsOneWidget);
      expect(_dichtheid(tester), HhDichtheid.groot);

      await _vul(tester, 0, 'Mevrouw Jansen');
      await _vul(tester, 1, 'jansen@voorbeeld.nl');
      await _vul(tester, 3, 'wachtwoord1');
      await _tik(tester, TekstenNl.registrerenKnop);

      expect(find.byType(BevestigEmailScreen), findsOneWidget);
      expect(gateway.laatsteRegistratieBody?['rol'], 'hulpvrager');
      expect(gateway.laatsteRegistratieBody?['taal'], 'nl');

      await _tik(tester, TekstenNl.verder);

      expect(find.byType(HulpvragerStubScreen), findsOneWidget);
      expect(_dichtheid(tester), HhDichtheid.groot);
      expect(
        find.text(TekstenNl.landingWelkom('Mevrouw Jansen')),
        findsOneWidget,
      );
    },
  );

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
      expect(_dichtheid(tester), rol.dichtheid);
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

    // M5: de landing van de jongere is J11 met een tabbalk; uitloggen zit
    // onder de tab Instellingen (G7).
    await tester.tap(find.text(TekstenKlussenNl.tabInstellingen));
    await tester.pumpAndSettle();
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
      _tokenSleutel: testToken(HhRol.familie),
    });
    final gateway = fakeMetAlleRollen()..isOffline = true;
    await pompApp(tester, gateway: gateway, opslag: opslag);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
    expect(opslag.waarden[_tokenSleutel], testToken(HhRol.familie));

    gateway.isOffline = false;
    await _tik(tester, TekstenNl.opnieuwProberen);

    expect(find.byType(FamilieStubScreen), findsOneWidget);
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
      _tokenSleutel: testToken(HhRol.familie),
    });
    final container = await pompApp(
      tester,
      gateway: fakeMetAlleRollen(),
      opslag: opslag,
    );
    expect(find.byType(FamilieStubScreen), findsOneWidget);

    container.read(routerProvider).go(HhPaden.jongere);
    await tester.pumpAndSettle();
    expect(find.byType(JongereStubScreen), findsNothing);
    expect(find.byType(FamilieStubScreen), findsOneWidget);

    // Instellingen is wel bereikbaar, en de terugknop brengt je terug.
    await _tik(tester, TekstenNl.landingInstellingen);
    expect(find.text(TekstenNl.instellingenTitel), findsOneWidget);
    await tester.tap(find.text(TekstenNl.terug));
    await tester.pumpAndSettle();
    expect(find.byType(FamilieStubScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_adres_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_auth_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/features/adres/domein/adres_invoer.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/mijn_gegevens_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/mijn_adres_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';
import 'package:heitjehulp_app/l10n/teksten_adres_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../support/hh_hulpvrager_wikkel.dart';
import '../support/hh_toegang_wikkel.dart';

/// Een account met een onvolledig adres (zoals testaccount "jan": postcode
/// "4001" zonder letters, geen huisnummer).
FakeAuthGateway _metOnvolledigAdres(HhRol rol) => FakeAuthGateway(
  accounts: [
    FakeAccount(
      gebruiker: testGebruiker(rol, postcode: '4001', huisnummer: ''),
      wachtwoord: testWachtwoord,
      token: testToken(rol),
    ),
  ],
);

Future<void> _tik(WidgetTester tester, String label) async {
  final knop = find.widgetWithText(HhKnop, label);
  await tester.ensureVisible(knop);
  await tester.tap(knop);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bewoner met een onvolledig adres: gele balk -> Mijn gegevens', (
    tester,
  ) async {
    final container = hulpvragerContainer(
      klusGateway: fakeKlusGateway(),
      authGateway: _metOnvolledigAdres(HhRol.hulpvrager),
      opslag: GeheugenKeyValueStore({
        'hh_auth_token': testToken(HhRol.hulpvrager),
      }),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeitjeHulpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(TekstenAdresNl.aanvullenKop), findsOneWidget);
    await _tik(tester, TekstenAdresNl.aanvullenKnop);
    expect(find.byType(MijnGegevensScreen), findsOneWidget);
  });

  testWidgets('bewoner met een volledig adres: geen balk', (tester) async {
    await pompHulpvragerApp(tester, klusGateway: fakeKlusGateway());
    expect(find.text(TekstenAdresNl.aanvullenKop), findsNothing);
  });

  testWidgets(
    'helper met een onvolledig adres: balk -> Mijn adres -> opslaan -> balk weg',
    (tester) async {
      final auth = _metOnvolledigAdres(HhRol.jongere);
      final adres = FakeAdresGateway();
      final container = await pompApp(
        tester,
        gateway: auth,
        opslag: GeheugenKeyValueStore({
          'hh_auth_token': testToken(HhRol.jongere),
        }),
        adresGateway: adres,
      );

      expect(find.text(TekstenAdresNl.aanvullenKop), findsOneWidget);
      await _tik(tester, TekstenAdresNl.aanvullenKnop);
      expect(find.byType(MijnAdresScreen), findsOneWidget);
      expect(adres.verzoeken, isEmpty, reason: '"4001" is geen postcode');

      await tester.enterText(find.byType(TextField).at(0), '4001ma');
      await tester.enterText(find.byType(TextField).at(1), '1');
      await tester.pump(adresZoekWachttijd);
      await tester.pumpAndSettle();
      expect(find.text('Kerkstraat 1, 4001 MA Tiel'), findsOneWidget);

      await _tik(tester, TekstenNl.opslaan);
      expect(auth.laatsteUpdateBody, {
        'postcode': '4001 MA',
        'huisnummer': '1',
        'toevoeging': '',
        'adres': 'Kerkstraat 1',
        'plaats': 'Tiel',
      });
      expect(find.text(TekstenAdresNl.opgeslagen), findsOneWidget);

      final terug = find.descendant(
        of: find.byType(HhTerugKnop),
        matching: find.text(TekstenNl.terug),
      );
      await tester.ensureVisible(terug);
      await tester.tap(terug);
      await tester.pumpAndSettle();
      // Pas nu (scherm weg) komt de nieuwe gebruiker in de sessie.
      expect(
        container.read(huidigeGebruikerProvider)?.heeftVolledigAdres,
        isTrue,
      );
      expect(find.text(TekstenAdresNl.aanvullenKop), findsNothing);
    },
  );

  testWidgets('Mijn adres: niet bestaand adres kan niet opgeslagen worden', (
    tester,
  ) async {
    final auth = _metOnvolledigAdres(HhRol.jongere);
    await pompApp(
      tester,
      gateway: auth,
      opslag: GeheugenKeyValueStore({
        'hh_auth_token': testToken(HhRol.jongere),
      }),
    );
    await _tik(tester, TekstenAdresNl.aanvullenKnop);
    await tester.enterText(find.byType(TextField).at(0), '4001 MA');
    await tester.enterText(find.byType(TextField).at(1), '999');
    await tester.pump(adresZoekWachttijd);
    await tester.pumpAndSettle();
    expect(find.text(TekstenAdresNl.nietGevonden), findsOneWidget);

    await _tik(tester, TekstenNl.opslaan);
    expect(find.text(TekstenAdresNl.validatieNietBevestigd), findsOneWidget);
    expect(auth.laatsteUpdateBody, isNull);
  });

  testWidgets('aanmelden: weigert de server het adres, dan zijn melding', (
    tester,
  ) async {
    final gateway = fakeMetAlleRollen();
    await pompApp(tester, gateway: gateway);
    await _tik(tester, TekstenNl.keuzeZoekHulp);
    await tester.enterText(find.byType(TextField).at(0), 'Ans');
    await tester.enterText(find.byType(TextField).at(1), 'ans@voorbeeld.nl');
    await tester.enterText(find.byType(TextField).at(2), '4001 MA');
    await tester.enterText(find.byType(TextField).at(3), '1');
    await tester.pump(adresZoekWachttijd);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(5), 'wachtwoord1');
    final vinkje = find.byType(Checkbox);
    await tester.ensureVisible(vinkje);
    await tester.tap(vinkje);
    await tester.pumpAndSettle();
    gateway.volgendeFout = const HhFout(
      HhFoutSoort.adresOngeldig,
      serverMelding:
          'We vinden dit adres niet. Klopt de postcode en het huisnummer?',
    );
    await _tik(tester, TekstenNl.registrerenKnop);
    expect(
      find.text(
        'We vinden dit adres niet. Klopt de postcode en het huisnummer?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('helper: Profiel -> Mijn adres (verhuizen kan altijd zelf)', (
    tester,
  ) async {
    await pompApp(
      tester,
      gateway: fakeMetAlleRollen(),
      opslag: GeheugenKeyValueStore({
        'hh_auth_token': testToken(HhRol.jongere),
      }),
    );
    expect(find.text(TekstenAdresNl.aanvullenKop), findsNothing);
    await tester.tap(find.text(TekstenKlussenNl.tabProfiel).last);
    await tester.pumpAndSettle();
    await _tik(tester, TekstenAdresNl.mijnAdresTitel);
    expect(find.byType(MijnAdresScreen), findsOneWidget);
    // Het bewaarde adres wordt meteen opgezocht en als kaartje getoond.
    await tester.pumpAndSettle();
    expect(find.text('Kerkstraat 1, 4001 MA Tiel'), findsOneWidget);
  });
}

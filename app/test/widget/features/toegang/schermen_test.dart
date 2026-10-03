import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_stub_screen.dart';
import 'package:heitjehulp_app/features/rol_landing_scherm.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/screen/bevestig_email_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/hulp_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/inloggen_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/registreren_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/splash_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/wachtwoord_vergeten_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/welkom_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_toegang_wikkel.dart';
import '../../../support/hh_wikkel.dart';

/// Elk G-scherm plus de vier landings, met de sessie die het nodig heeft.
class _Geval {
  const _Geval(this.naam, this.scherm, this.sessie, {this.gekozenRol});

  final String naam;
  final Widget scherm;
  final SessieState sessie;
  final HhRol? gekozenRol;
}

const _uit = SessieUitgelogd();

final _gevallen = [
  const _Geval('G1 splash', SplashScreen(), SessieOnbekend()),
  const _Geval(
    'G1 splash offline',
    SplashScreen(),
    SessieOnbekend(fout: HhFout(HhFoutSoort.geenVerbinding)),
  ),
  const _Geval('G2 welkom', WelkomScreen(), _uit),
  const _Geval('G3 inloggen', InloggenScreen(), _uit),
  const _Geval(
    'G3 inloggen na verlopen sessie',
    InloggenScreen(),
    SessieUitgelogd(reden: UitlogReden.sessieVerlopen),
  ),
  const _Geval(
    'G4 registreren hulpvrager',
    RegistrerenScreen(),
    _uit,
    gekozenRol: HhRol.hulpvrager,
  ),
  const _Geval('G4 registreren zonder rol', RegistrerenScreen(), _uit),
  _Geval(
    'G5 bevestig e-mail',
    const BevestigEmailScreen(),
    SessieIngelogd(testGebruiker(HhRol.jongere, isBevestigd: false)),
  ),
  const _Geval('G6 wachtwoord vergeten', WachtwoordVergetenScreen(), _uit),
  _Geval(
    'G7 instellingen',
    const InstellingenScreen(),
    SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
  ),
  const _Geval('G8 hulp zonder rol', HulpScreen(), _uit),
  _Geval(
    'G8 hulp als familie',
    const HulpScreen(),
    SessieIngelogd(testGebruiker(HhRol.familie)),
  ),
  // M4: de hulpvrager-landing is O1 geworden (test/widget/features/
  // hulpvrager); hier de familie-landing als niet-bevestigd voorbeeld.
  _Geval(
    'landing familie (niet bevestigd)',
    // M9: /familie is nu F1; het algemene landingsscherm blijft getest.
    const RolLandingScherm(rol: HhRol.familie, icoon: Icons.family_restroom),
    SessieIngelogd(testGebruiker(HhRol.familie, isBevestigd: false)),
  ),
  _Geval(
    'landing jongere',
    const JongereStubScreen(),
    SessieIngelogd(testGebruiker(HhRol.jongere)),
  ),
  _Geval(
    'landing familie',
    // M9: /familie is nu F1; het algemene landingsscherm blijft getest.
    const RolLandingScherm(rol: HhRol.familie, icoon: Icons.family_restroom),
    SessieIngelogd(testGebruiker(HhRol.familie)),
  ),
  _Geval(
    'landing coordinator',
    const CoordinatorStubScreen(),
    SessieIngelogd(testGebruiker(HhRol.coordinator)),
  ),
];

Future<void> _pomp(
  WidgetTester tester,
  _Geval geval, {
  required HhDichtheid dichtheid,
  double tekstschaal = 1.0,
}) async {
  await tester.pumpWidget(
    hhToegangWikkel(
      geval.scherm,
      gateway: fakeMetAlleRollen(),
      sessie: geval.sessie,
      gekozenRol: geval.gekozenRol,
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pump();
}

/// Elke knop heeft een label en is een knop; elk invoerveld heeft een
/// label voor de schermlezer.
void _controleerSemantiek(WidgetTester tester) {
  for (final knop in find.byType(HhKnop).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(knop.widget));
    expect(semantiek.label, isNotEmpty, reason: 'knop zonder label');
    expect(
      semantiek.getSemanticsData().flagsCollection.isButton,
      isTrue,
      reason: 'knop ${semantiek.label} is geen knop voor de schermlezer',
    );
  }
  for (final terug in find.byType(HhTerugKnop).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(terug.widget));
    expect(semantiek.label, TekstenNl.terug);
  }
  for (final veld in find.byType(TextField).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(veld.widget));
    expect(semantiek.label, isNotEmpty, reason: 'invoerveld zonder label');
  }
  for (final schakelaar in find.byType(Switch).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(schakelaar.widget));
    expect(semantiek.label, isNotEmpty, reason: 'schakelaar zonder label');
  }
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
          _controleerSemantiek(tester);
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

  group('teksten', () {
    testWidgets('G2 toont twee ingangen en de inlog-link, geen familie', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[2], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenNl.keuzeZoekHulp), findsOneWidget);
      expect(find.text(TekstenNl.keuzeWilHelpen), findsOneWidget);
      expect(find.text(TekstenNl.keuzeHelpFamilielid), findsNothing);
      expect(find.text(TekstenNl.alEenAccount), findsOneWidget);
    });

    testWidgets('G5 heet "Bevestig je e-mailadres" en noemt het adres', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[7], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenNl.bevestigEmailTitel), findsOneWidget);
      expect(
        find.textContaining(testGebruiker(HhRol.jongere).email),
        findsOneWidget,
      );
    });

    testWidgets('G8 zonder rol toont alle vier blokken, met rol een', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[10], dichtheid: HhDichtheid.normaal);
      for (final rol in HhRol.values) {
        expect(find.text(rol.naam), findsOneWidget, reason: rol.code);
      }

      await _pomp(tester, _gevallen[11], dichtheid: HhDichtheid.normaal);
      expect(find.text(TekstenNl.hulpVeelgesteld), findsOneWidget);
      expect(
        find.text(TekstenNl.hulpVragenFamilie.first.vraag),
        findsOneWidget,
      );
      expect(find.text(TekstenNl.hulpVragenJongere.first.vraag), findsNothing);
    });

    testWidgets('landing toont naam, rol, uitloggen en bevestig-banner', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[12], dichtheid: HhDichtheid.groot);
      final gebruiker = testGebruiker(HhRol.familie);

      expect(
        find.text(TekstenNl.landingWelkom(gebruiker.naam)),
        findsOneWidget,
      );
      expect(
        find.text(TekstenNl.landingRol(HhRol.familie.naam)),
        findsOneWidget,
      );
      expect(find.text(TekstenNl.uitloggen), findsOneWidget);
      expect(find.text(TekstenNl.bevestigEmailBanner), findsOneWidget);
    });

    testWidgets('landing verbergt de banner als het adres bevestigd is', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[13], dichtheid: HhDichtheid.normaal);

      expect(find.text(TekstenNl.bevestigEmailBanner), findsNothing);
    });
  });

  group('ouderenregel', () {
    testWidgets('G4 voor de hulpvrager heeft een terugknop en een hoofdknop', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[5], dichtheid: HhDichtheid.groot);

      expect(find.byType(HhTerugKnop), findsOneWidget);
      expect(find.byType(HhKnop), findsOneWidget);
    });
  });
}

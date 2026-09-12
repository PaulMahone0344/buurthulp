import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/config.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_auth_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/meldingen_voorkeur.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';
import 'package:heitjehulp_app/features/toegang/screen/bevestig_email_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/hulp_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/inloggen_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/wachtwoord_vergeten_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_toegang_wikkel.dart';

Future<void> _pomp(
  WidgetTester tester,
  Widget scherm, {
  required FakeAuthGateway gateway,
  SessieState? sessie,
  GeheugenKeyValueStore? opslag,
  bool urlOpenerLukt = true,
}) async {
  await tester.pumpWidget(
    hhToegangWikkel(
      scherm,
      gateway: gateway,
      sessie: sessie,
      opslag: opslag,
      urlOpenerLukt: urlOpenerLukt,
    ),
  );
  await tester.pump();
}

Future<void> _vul(WidgetTester tester, int index, String tekst) =>
    tester.enterText(find.byType(TextField).at(index), tekst);

/// Scrolt de knop in beeld en tikt erop; lange schermen passen niet op
/// het testoppervlak.
Future<void> _tik(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('G3 inloggen', () {
    testWidgets('lege velden geven veldfouten, geen serververzoek', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await _pomp(tester, const InloggenScreen(), gateway: gateway);

      await tester.tap(find.widgetWithText(HhKnop, TekstenNl.inloggenKnop));
      await tester.pump();

      expect(find.text(TekstenNl.validatieEmailVerplicht), findsOneWidget);
      expect(gateway.ingelogd, isNull);
    });

    testWidgets('fout wachtwoord toont een Nederlandse melding', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await _pomp(tester, const InloggenScreen(), gateway: gateway);

      await _vul(tester, 0, testGebruiker(HhRol.jongere).email);
      await _vul(tester, 1, 'verkeerd');
      await _tik(tester, find.widgetWithText(HhKnop, TekstenNl.inloggenKnop));

      expect(find.text(TekstenNl.foutOngeldigeInlog), findsOneWidget);
    });

    testWidgets('offline: meldbalk en de knop blijft bruikbaar', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen()..isOffline = true;
      await _pomp(tester, const InloggenScreen(), gateway: gateway);

      await _vul(tester, 0, testGebruiker(HhRol.jongere).email);
      await _vul(tester, 1, testWachtwoord);
      await _tik(tester, find.widgetWithText(HhKnop, TekstenNl.inloggenKnop));

      expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
      final knop = tester.widget<HhKnop>(
        find.widgetWithText(HhKnop, TekstenNl.inloggenKnop),
      );
      expect(knop.isActief, isTrue);

      gateway.isOffline = false;
      await _tik(tester, find.widgetWithText(HhKnop, TekstenNl.inloggenKnop));
      expect(gateway.ingelogd?.rol, HhRol.jongere);
    });

    testWidgets('na een verlopen sessie staat er een waarschuwing', (
      tester,
    ) async {
      await _pomp(
        tester,
        const InloggenScreen(),
        gateway: fakeMetAlleRollen(),
        sessie: const SessieUitgelogd(reden: UitlogReden.sessieVerlopen),
      );

      expect(find.text(TekstenNl.foutSessieVerlopen), findsOneWidget);
    });
  });

  group('G5 bevestig e-mail', () {
    testWidgets('opnieuw sturen vraagt de mail aan en meldt dat', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await _pomp(
        tester,
        const BevestigEmailScreen(),
        gateway: gateway,
        sessie: SessieIngelogd(
          testGebruiker(HhRol.familie, isBevestigd: false),
        ),
      );

      await _tik(
        tester,
        find.widgetWithText(HhKnop, TekstenNl.bevestigEmailOpnieuw),
      );

      expect(gateway.aantalVerificatieAanvragen, 1);
      expect(find.text(TekstenNl.bevestigEmailVerstuurd), findsOneWidget);
    });
  });

  group('G6 wachtwoord vergeten', () {
    testWidgets('geslaagd: neutrale bevestiging', (tester) async {
      final gateway = fakeMetAlleRollen();
      await _pomp(tester, const WachtwoordVergetenScreen(), gateway: gateway);

      await _vul(tester, 0, 'iemand@voorbeeld.nl');
      await _tik(
        tester,
        find.widgetWithText(HhKnop, TekstenNl.wachtwoordVergetenKnop),
      );

      expect(gateway.wachtwoordResets, 1);
      expect(find.text(TekstenNl.wachtwoordVergetenVerstuurd), findsOneWidget);
    });

    testWidgets('serverfout: Nederlandse melding', (tester) async {
      final gateway = fakeMetAlleRollen()
        ..volgendeFout = const HhFout(HhFoutSoort.server);
      await _pomp(tester, const WachtwoordVergetenScreen(), gateway: gateway);

      await _vul(tester, 0, 'iemand@voorbeeld.nl');
      await _tik(
        tester,
        find.widgetWithText(HhKnop, TekstenNl.wachtwoordVergetenKnop),
      );

      expect(find.text(TekstenNl.foutServer), findsOneWidget);
    });
  });

  group('G7 instellingen', () {
    testWidgets('taal kiezen stuurt alleen taal naar de server', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await _pomp(
        tester,
        const InstellingenScreen(),
        gateway: gateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.jongere)),
      );
      // De fake kent de ingelogde gebruiker via inloggen; zet hem gelijk.
      gateway.ingelogd = testGebruiker(HhRol.jongere);

      await _tik(tester, find.text(TekstenNl.taalTurks));

      expect(gateway.laatsteUpdateBody, {'taal': 'tr'});
      expect(gateway.laatsteUpdateBody?.containsKey('rol'), isFalse);
      expect(find.text(TekstenNl.instellingenOpgeslagen), findsOneWidget);
    });

    testWidgets('meldingen-schakelaar bewaart lokaal', (tester) async {
      final opslag = GeheugenKeyValueStore();
      await _pomp(
        tester,
        const InstellingenScreen(),
        gateway: fakeMetAlleRollen(),
        sessie: SessieIngelogd(testGebruiker(HhRol.familie)),
        opslag: opslag,
      );

      await _tik(tester, find.byType(Switch));

      expect(opslag.waarden['hh_meldingen_aan'], 'false');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InstellingenScreen)),
      );
      expect(container.read(meldingenVoorkeurProvider), isFalse);
    });

    testWidgets('account wissen vraagt bevestiging; annuleren doet niets', (
      tester,
    ) async {
      final gateway = fakeMetAlleRollen();
      await _pomp(
        tester,
        const InstellingenScreen(),
        gateway: gateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.familie)),
      );
      gateway.ingelogd = testGebruiker(HhRol.familie);

      await _tik(tester, find.widgetWithText(HhKnop, TekstenNl.accountWissen));
      expect(find.text(TekstenNl.accountWissenVraag), findsOneWidget);

      await _tik(tester, find.widgetWithText(HhKnop, TekstenNl.annuleren));
      expect(gateway.gewisteAccounts, isEmpty);

      await _tik(tester, find.widgetWithText(HhKnop, TekstenNl.accountWissen));
      await _tik(
        tester,
        find.widgetWithText(HhKnop, TekstenNl.accountWissenBevestig),
      );
      expect(gateway.gewisteAccounts, [testGebruiker(HhRol.familie).id]);
    });

    testWidgets('uitloggen zet de sessie op uitgelogd', (tester) async {
      final gateway = fakeMetAlleRollen();
      await _pomp(
        tester,
        const InstellingenScreen(),
        gateway: gateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.coordinator)),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InstellingenScreen)),
      );

      await _tik(tester, find.widgetWithText(HhKnop, TekstenNl.uitloggen));

      expect(container.read(sessieControllerProvider), isA<SessieUitgelogd>());
    });
  });

  group('G8 hulp', () {
    testWidgets('bellen lukt niet: meldbalk met het nummer, geen exception', (
      tester,
    ) async {
      await _pomp(
        tester,
        const HulpScreen(),
        gateway: fakeMetAlleRollen(),
        urlOpenerLukt: false,
      );

      await _tik(
        tester,
        find.widgetWithText(HhKnop, TekstenNl.hulpBelMeldkamer),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(HhMeldBalk), findsOneWidget);
      expect(
        find.text(TekstenNl.hulpBellenLuktNiet(HhConfig.meldkamerTelefoon)),
        findsOneWidget,
      );
    });

    testWidgets('bellen lukt: geen meldbalk', (tester) async {
      await _pomp(tester, const HulpScreen(), gateway: fakeMetAlleRollen());

      await _tik(
        tester,
        find.widgetWithText(HhKnop, TekstenNl.hulpBelMeldkamer),
      );

      expect(find.byType(HhMeldBalk), findsNothing);
    });

    testWidgets('dichtheid groot maakt de belknop 60 hoog', (tester) async {
      await tester.pumpWidget(
        hhToegangWikkel(
          const HulpScreen(),
          gateway: fakeMetAlleRollen(),
          dichtheid: HhDichtheid.groot,
        ),
      );
      await tester.pump();

      final hoogte = tester
          .getSize(find.widgetWithText(HhKnop, TekstenNl.hulpBelMeldkamer))
          .height;
      expect(
        hoogte,
        greaterThanOrEqualTo(HhMaten.knopHoogte(HhDichtheid.groot)),
      );
    });
  });
}

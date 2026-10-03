// B3: ouder-toestemming in de helper-app. De ouder zelf werkt op de
// website (website/src/ouder); hier alleen wat de helper ziet en doet. Er
// gaat nooit iets naar een server: FakeOuderGateway doet wat de hook doet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_ouder_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/core/pb/ouder_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/ouder/model/hh_ouder_stand.dart';
import 'package:heitjehulp_app/features/jongere/ouder/screen/ouder_screen.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_overzicht_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_ouder_nl.dart';

import '../support/hh_jongere_wikkel.dart';
import '../support/hh_toegang_wikkel.dart';

const _tokenSleutel = 'hh_auth_token';

GeheugenKeyValueStore _ingelogd() =>
    GeheugenKeyValueStore({_tokenSleutel: testToken(HhRol.jongere)});

Finder get _klussenLijst => find.text(TekstenKlussenNl.weergaveLijst);

FakeOuderGateway _ouder(
  HhOuderStatus status, {
  String email = 'mama@voorbeeld.nl',
  int nog = 3,
  bool geblokkeerd = false,
}) => FakeOuderGateway(
  stand: HhOuderStand(
    status: status,
    ouderEmail: email,
    nogTeSturen: nog,
    isGeblokkeerd: geblokkeerd,
  ),
);

/// Goedgekeurde helper van 13 zonder ouder-toestemming.
FakeProfielGateway _goedgekeurdJong() =>
    fakeJongereGoedgekeurdWachtend(isMinderjarig: true);

Future<void> _pompScherm(WidgetTester tester, FakeOuderGateway ouder) async {
  await tester.pumpWidget(
    hhJongereWikkel(
      HhPadenOuder.ouder,
      profielGateway: fakeNieuweJongere(isMinderjarig: true),
      ouderGateway: ouder,
    ),
  );
  await tester.pumpAndSettle();
}

String _tekstVanMeldBalken(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  group('stap "Ouder" (helper onder 18)', () {
    testWidgets(
      'nog niets verstuurd: de mail gaat bij openen meteen (1 keer)',
      (tester) async {
        final ouder = _ouder(HhOuderStatus.geen);
        await _pompScherm(tester, ouder);

        expect(ouder.verstuurd, hasLength(1));
        final tekst = _tekstVanMeldBalken(tester);
        expect(tekst, contains(TekstenOuderNl.verstuurdKop));
        expect(tekst, contains(TekstenOuderNl.naarAdres('mama@voorbeeld.nl')));
        expect(find.text(TekstenOuderNl.nogVandaag(2)), findsOneWidget);
        expect(find.widgetWithText(HhKnop, TekstenOuderNl.opnieuw), findsOne);
        // Geen code-vakjes in de app: de ouder vult de code in (K2).
        expect(find.textContaining('code van 6'), findsNothing);

        await tester.pumpAndSettle();
        expect(ouder.verstuurd, hasLength(1));
      },
    );

    testWidgets('stuur opnieuw tot de limiet van vandaag', (tester) async {
      final ouder = _ouder(HhOuderStatus.verstuurd, nog: 2);
      await _pompScherm(tester, ouder);
      expect(ouder.verstuurd, isEmpty);

      await tikKnop(tester, TekstenOuderNl.opnieuw);
      expect(ouder.verstuurd, hasLength(1));
      expect(find.text(TekstenOuderNl.gelukt), findsOneWidget);
      await tikKnop(tester, TekstenOuderNl.opnieuw);
      expect(find.text(TekstenOuderNl.geenMeerVandaag), findsOneWidget);
      final knop = find.widgetWithText(HhKnop, TekstenOuderNl.opnieuw);
      expect(tester.widget<HhKnop>(knop).isActief, isFalse);
    });

    testWidgets('K1: alleen een telefoonnummer -> eerst het e-mailadres', (
      tester,
    ) async {
      final ouder = _ouder(HhOuderStatus.geen, email: '');
      await _pompScherm(tester, ouder);

      expect(ouder.verstuurd, isEmpty);
      expect(
        _tekstVanMeldBalken(tester),
        contains(TekstenOuderNl.alleenTelefoonKop),
      );
      await vulVeld(tester, 0, 'geen-adres');
      await tikKnop(tester, TekstenOuderNl.stuur);
      expect(find.text(TekstenOuderNl.emailOngeldig), findsOneWidget);
      expect(ouder.verstuurd, isEmpty);

      await vulVeld(tester, 0, 'papa@voorbeeld.nl');
      await tikKnop(tester, TekstenOuderNl.stuur);
      expect(ouder.verstuurd, ['papa@voorbeeld.nl']);
      expect(
        _tekstVanMeldBalken(tester),
        contains(TekstenOuderNl.naarAdres('papa@voorbeeld.nl')),
      );
    });

    testWidgets('e-mailadres wijzigen stuurt naar het nieuwe adres', (
      tester,
    ) async {
      final ouder = _ouder(HhOuderStatus.verstuurd);
      await _pompScherm(tester, ouder);

      await tikKnop(tester, TekstenOuderNl.wijzig);
      await vulVeld(tester, 0, 'oma@voorbeeld.nl');
      await tikKnop(tester, TekstenOuderNl.stuurNaarNieuw);
      expect(ouder.verstuurd, ['oma@voorbeeld.nl']);
      expect(
        _tekstVanMeldBalken(tester),
        contains(TekstenOuderNl.naarAdres('oma@voorbeeld.nl')),
      );
    });

    testWidgets('weigering van de server: zijn melding', (tester) async {
      const melding =
          'Vul het e-mailadres van je ouder in, niet je eigen adres.';
      final ouder = _ouder(HhOuderStatus.verstuurd)
        ..weigerMet = const OuderGeweigerd('eigenadres', melding);
      await _pompScherm(tester, ouder);
      await tikKnop(tester, TekstenOuderNl.opnieuw);
      expect(find.text(melding), findsOneWidget);
      expect(ouder.verstuurd, isEmpty);
    });

    testWidgets('limiet op: wijzigen en opnieuw sturen staan uit', (
      tester,
    ) async {
      await _pompScherm(tester, _ouder(HhOuderStatus.verstuurd, nog: 0));
      for (final label in [TekstenOuderNl.opnieuw, TekstenOuderNl.wijzig]) {
        final knop = find.widgetWithText(HhKnop, label);
        expect(tester.widget<HhKnop>(knop).isActief, isFalse, reason: label);
      }
      expect(find.text(TekstenOuderNl.geenMeerVandaag), findsOneWidget);
    });

    testWidgets('verlopen of geblokkeerd: "De code werkt niet meer"', (
      tester,
    ) async {
      await _pompScherm(
        tester,
        _ouder(HhOuderStatus.verstuurd, geblokkeerd: true),
      );
      expect(_tekstVanMeldBalken(tester), contains(TekstenOuderNl.verlopenKop));
    });

    testWidgets('ingetrokken: duidelijke melding en opnieuw vragen kan', (
      tester,
    ) async {
      final ouder = _ouder(HhOuderStatus.ingetrokken);
      await _pompScherm(tester, ouder);
      expect(
        _tekstVanMeldBalken(tester),
        contains(TekstenOuderNl.ingetrokkenKop),
      );
      await tikKnop(tester, TekstenOuderNl.opnieuw);
      expect(ouder.verstuurd, hasLength(1));
    });

    testWidgets('gegeven: geen "Stuur opnieuw" meer', (tester) async {
      await _pompScherm(tester, _ouder(HhOuderStatus.gegeven));
      expect(_tekstVanMeldBalken(tester), contains(TekstenOuderNl.gegevenKop));
      expect(find.widgetWithText(HhKnop, TekstenOuderNl.opnieuw), findsNothing);
    });

    testWidgets('geen verbinding: nette melding, niets kapot', (tester) async {
      final ouder = _ouder(HhOuderStatus.verstuurd)..faalt = false;
      await _pompScherm(tester, ouder);
      ouder.faalt = true;
      await tikKnop(tester, TekstenOuderNl.opnieuw);
      expect(find.byType(OuderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('in de app', () {
    testWidgets(
      'net aangemeld onder 18: eerst "Ouder" (mail gaat), dan "Je aanmelding"',
      (tester) async {
        final ouder = _ouder(HhOuderStatus.geen);
        await pompJongereApp(
          tester,
          profielGateway: fakeNieuweJongere(isMinderjarig: true),
          ouderGateway: ouder,
          opslag: _ingelogd(),
        );
        expect(find.byType(OuderScreen), findsOneWidget);
        expect(ouder.verstuurd, hasLength(1));

        await tikKnop(tester, TekstenOuderNl.verderAanmelding);
        expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      },
    );

    testWidgets('18+ gaat nooit langs "Ouder"', (tester) async {
      final ouder = _ouder(HhOuderStatus.geen);
      await pompJongereApp(
        tester,
        profielGateway: fakeNieuweJongere(),
        ouderGateway: ouder,
        opslag: _ingelogd(),
      );
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
      expect(ouder.verstuurd, isEmpty);
    });

    testWidgets('route nog niet op de server: gewoon "Je aanmelding" (B2)', (
      tester,
    ) async {
      final ouder = _ouder(HhOuderStatus.geen)..faalt = true;
      await pompJongereApp(
        tester,
        profielGateway: fakeNieuweJongere(isMinderjarig: true),
        ouderGateway: ouder,
        opslag: _ingelogd(),
      );
      expect(find.byType(ScreeningOverzichtScreen), findsOneWidget);
    });

    testWidgets(
      'Start: gele balk ouder met knop; na toestemming weg en klussen',
      (tester) async {
        final profiel = _goedgekeurdJong();
        final ouder = _ouder(HhOuderStatus.verstuurd);
        await pompJongereApp(
          tester,
          profielGateway: profiel,
          ouderGateway: ouder,
          opslag: _ingelogd(),
        );
        expect(find.text(TekstenAanmeldenNl.wachtOuder), findsOneWidget);
        expect(_klussenLijst, findsNothing);

        await tikKnop(tester, TekstenOuderNl.balkKnop);
        expect(find.byType(OuderScreen), findsOneWidget);
        await tikKnop(tester, TekstenOuderNl.naarStart);

        // De ouder gaf toestemming op de website.
        ouder.zetStand(const HhOuderStand(status: HhOuderStatus.gegeven));
        profiel.zetAccount(
          jongereId,
          HhAccountGegevens(
            geboortedatum: jongGeboren,
            wijkId: 'wijk-west',
            ouderToestemmingOp: DateTime.utc(2026, 10, 4),
          ),
        );
        await tikKnop(tester, TekstenAanmeldenNl.wachtVernieuwen);
        expect(find.text(TekstenAanmeldenNl.wachtOuder), findsNothing);
        expect(_klussenLijst, findsOneWidget);
      },
    );

    testWidgets('ingetrokken: "Je ouder heeft de toestemming ingetrokken."', (
      tester,
    ) async {
      await pompJongereApp(
        tester,
        profielGateway: _goedgekeurdJong(),
        ouderGateway: _ouder(HhOuderStatus.ingetrokken),
        opslag: _ingelogd(),
      );
      expect(find.text(TekstenOuderNl.ingetrokkenKop), findsOneWidget);
      expect(_klussenLijst, findsNothing);
      expect(find.text(TekstenOuderNl.balkKnop), findsOneWidget);
    });

    testWidgets('onder 18 in behandeling: eerst de ouder-balk', (tester) async {
      final profiel = _goedgekeurdJong();
      profiel.zetStatus(
        jongereId,
        verificatiestatus: HhScreeningStatus.inBehandeling,
      );
      await pompJongereApp(
        tester,
        profielGateway: profiel,
        ouderGateway: _ouder(HhOuderStatus.verstuurd),
        opslag: _ingelogd(),
      );
      expect(find.text(TekstenAanmeldenNl.wachtOuder), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.wachtNagekeken), findsNothing);
    });
  });
}

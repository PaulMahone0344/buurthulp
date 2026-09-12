import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_foto_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_iban_screen.dart';
import 'package:heitjehulp_app/features/jongere/screen/screening_werkgebied_screen.dart';
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
  group('J1 profiel', () {
    testWidgets('lege velden geven veldfouten, geen serververzoek', (
      tester,
    ) async {
      final fake = fakeNieuweJongere();
      await _pomp(tester, HhPadenJongere.profiel, fake: fake);

      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      expect(
        find.text(TekstenJongereNl.validatieGeboortedatumOngeldig),
        findsOneWidget,
      );
      expect(
        find.text(TekstenJongereNl.validatieOverMijVerplicht),
        findsOneWidget,
      );
      expect(fake.laatsteProfielBody, isNull);
      expect(fake.laatsteAccountBody, isNull);
    });

    testWidgets('geboortedatum in de toekomst wordt geweigerd', (tester) async {
      await _pomp(tester, HhPadenJongere.profiel, fake: fakeNieuweJongere());

      await vulVeld(tester, 0, '01-01-2999');
      await vulVeld(tester, 1, 'Hoi');
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      expect(
        find.text(TekstenJongereNl.validatieGeboortedatumToekomst),
        findsOneWidget,
      );
    });

    testWidgets(
      'opslaan maakt het profiel aan met alleen over_mij en zet de datum op het account',
      (tester) async {
        final fake = fakeNieuweJongere();
        await _pomp(tester, HhPadenJongere.profiel, fake: fake);

        await vulVeld(tester, 0, '14-05-2008');
        await vulVeld(tester, 1, 'Ik help graag.');
        await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

        expect(fake.laatsteAccountBody, {
          'geboortedatum': '2008-05-14T00:00:00.000Z',
        });
        expect(fake.laatsteProfielBody, {'over_mij': 'Ik help graag.'});
        expect(fake.profielVan(jongereId)?.overMij, 'Ik help graag.');
        expect(
          fake.accountVan(jongereId).geboortedatum,
          DateTime.utc(2008, 5, 14),
        );
        // Verder naar J2.
        expect(find.byType(ScreeningIdentiteitScreen), findsOneWidget);
      },
    );

    testWidgets('ongewijzigde velden gaan niet naar de server', (tester) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      await _pomp(tester, HhPadenJongere.profiel, fake: fake);

      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      expect(fake.laatsteAccountBody, isNull);
      expect(fake.laatsteProfielBody, isNull);
      expect(find.byType(ScreeningIdentiteitScreen), findsOneWidget);
    });

    testWidgets('foto uit de galerij wordt geupload naar hh_users.foto', (
      tester,
    ) async {
      final fake = fakeNieuweJongere();
      final kiezer = FakeFotoKiezer(volgende: testFoto('profiel.png'));
      await _pomp(
        tester,
        HhPadenJongere.profiel,
        fake: fake,
        fotoKiezer: kiezer,
      );

      await tikKnop(tester, TekstenJongereNl.fotoKiezen);

      expect(kiezer.aanroepen, [(bron: HhFotoBron.galerij, isSelfie: false)]);
      expect(fake.uploads.single.collectie, 'hh_users');
      expect(fake.uploads.single.veld, 'foto');
      expect(fake.uploads.single.bestandsnaam, 'profiel.png');
      expect(fake.accountVan(jongereId).heeftFoto, isTrue);
      expect(find.text(TekstenJongereNl.opgeslagen), findsOneWidget);
    });

    testWidgets(
      'annuleren in de kiezer doet niets; camera-fout geeft een waarschuwing',
      (tester) async {
        final fake = fakeNieuweJongere();
        final kiezer = FakeFotoKiezer();
        await _pomp(
          tester,
          HhPadenJongere.profiel,
          fake: fake,
          fotoKiezer: kiezer,
        );

        await tikKnop(tester, TekstenJongereNl.fotoMaken);
        expect(fake.uploads, isEmpty);
        expect(find.text(TekstenJongereNl.fotoCameraLuktNiet), findsNothing);

        kiezer.volgendeFout = const HhFout(HhFoutSoort.onbekend);
        await tikKnop(tester, TekstenJongereNl.fotoMaken);
        expect(find.text(TekstenJongereNl.fotoCameraLuktNiet), findsOneWidget);
        expect(fake.uploads, isEmpty);
      },
    );

    testWidgets('offline: Nederlandse melding, knop blijft bruikbaar', (
      tester,
    ) async {
      final fake = fakeNieuweJongere();
      await _pomp(tester, HhPadenJongere.profiel, fake: fake);
      await vulVeld(tester, 0, '14-05-2008');
      await vulVeld(tester, 1, 'Hoi');
      fake.isOffline = true;

      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
      expect(
        tester
            .widget<HhKnop>(
              find.widgetWithText(HhKnop, TekstenJongereNl.opslaanEnVerder),
            )
            .isActief,
        isTrue,
      );
    });
  });

  group('J2 en J3 foto', () {
    testWidgets(
      'J2: Verder is uit tot de documentfoto op de server staat; profiel wordt zo nodig aangemaakt',
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

        await tikKnop(tester, TekstenJongereNl.fotoMaken);

        expect(kiezer.aanroepen.single.isSelfie, isFalse);
        expect(fake.uploads.single.veld, 'document_foto');
        expect(fake.profielVan(jongereId)?.heeftDocumentFoto, isTrue);
        expect(tester.widget<HhKnop>(verder).isActief, isTrue);
      },
    );

    testWidgets('J3: alleen camera, aan de voorkant, naar het veld selfie', (
      tester,
    ) async {
      final fake = fakeNieuweJongere();
      final kiezer = FakeFotoKiezer(volgende: testFoto('selfie.png'));
      await _pomp(
        tester,
        HhPadenJongere.selfie,
        fake: fake,
        fotoKiezer: kiezer,
      );

      await tikKnop(tester, TekstenJongereNl.j3Knop);

      expect(kiezer.aanroepen.single, (
        bron: HhFotoBron.camera,
        isSelfie: true,
      ));
      expect(fake.uploads.single.veld, 'selfie');
      expect(fake.profielVan(jongereId)?.heeftSelfie, isTrue);
    });
  });

  group('J4 vog', () {
    testWidgets(
      'VOG aanvragen opent Justis; lukt dat niet, dan een waarschuwing',
      (tester) async {
        await _pomp(
          tester,
          HhPadenJongere.vog,
          fake: fakeNieuweJongere(),
          urlOpenerLukt: false,
        );

        await tikKnop(tester, TekstenJongereNl.j4Aanvragen);

        expect(find.text(TekstenJongereNl.j4AanvragenLuktNiet), findsOneWidget);
      },
    );

    testWidgets(
      'Ik heb aangevraagd zet alleen vog_aangevraagd_op en verbergt de knop',
      (tester) async {
        final fake = fakeNieuweJongere();
        await _pomp(tester, HhPadenJongere.vog, fake: fake);

        await tikKnop(tester, TekstenJongereNl.j4HebAangevraagd);

        expect(fake.laatsteProfielBody?.keys, ['vog_aangevraagd_op']);
        expect(fake.profielVan(jongereId)?.vogAangevraagdOp, isNotNull);
        expect(
          find.widgetWithText(HhKnop, TekstenJongereNl.j4HebAangevraagd),
          findsNothing,
        );
        expect(find.textContaining('Aangevraagd op'), findsOneWidget);
        expect(find.text(TekstenJongereNl.statusNieuw), findsOneWidget);
      },
    );
  });

  group('J5 iban', () {
    testWidgets('ongeldige IBAN geeft een veldfout, geen verzoek', (
      tester,
    ) async {
      final fake = fakeNieuweJongere();
      await _pomp(tester, HhPadenJongere.iban, fake: fake);

      await vulVeld(tester, 0, 'NL92ABNA0417164300');
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      expect(find.text(TekstenJongereNl.validatieIbanOngeldig), findsOneWidget);
      expect(fake.laatsteProfielBody, isNull);
      expect(find.byType(ScreeningIbanScreen), findsOneWidget);
    });

    testWidgets('geldige IBAN wordt genormaliseerd opgeslagen', (tester) async {
      final fake = fakeNieuweJongere();
      await _pomp(tester, HhPadenJongere.iban, fake: fake);

      await vulVeld(tester, 0, 'nl91 abna 0417 1643 00');
      await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

      expect(fake.laatsteProfielBody, {'iban': 'NL91ABNA0417164300'});
      expect(find.byType(ScreeningWerkgebiedScreen), findsOneWidget);
    });

    testWidgets('gecontroleerde rekening wordt gemeld', (tester) async {
      await _pomp(
        tester,
        HhPadenJongere.iban,
        fake: FakeProfielGateway.goedgekeurd(jongereId),
      );

      expect(find.text(TekstenJongereNl.j5Geverifieerd), findsOneWidget);
    });
  });

  group('J6 werkgebied', () {
    testWidgets(
      'zonder wijk een melding; met wijk gaan wijk en straal apart naar de server',
      (tester) async {
        final fake = fakeNieuweJongere();
        await _pomp(tester, HhPadenJongere.werkgebied, fake: fake);

        await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);
        expect(
          find.text(TekstenJongereNl.validatieWijkVerplicht),
          findsOneWidget,
        );
        expect(fake.laatsteAccountBody, isNull);

        await tikTekst(tester, 'Passewaaij');
        await tikTekst(tester, TekstenJongereNl.j6StraalLabel(5));
        await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

        expect(fake.laatsteAccountBody, {'wijk': 'wijk-passewaaij'});
        expect(fake.laatsteProfielBody, {'straal_km': 5});
      },
    );
  });

  group('J7 en J8', () {
    testWidgets(
      'J7 zonder dagdeel een melding; daarna json met alle zeven dagen',
      (tester) async {
        final fake = fakeNieuweJongere();
        await _pomp(tester, HhPadenJongere.beschikbaarheid, fake: fake);

        await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);
        expect(
          find.text(TekstenJongereNl.validatieBeschikbaarheidLeeg),
          findsOneWidget,
        );

        await tikTekst(tester, TekstenJongereNl.dagdeelMiddag);
        await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

        expect(fake.laatsteProfielBody, {
          'beschikbaarheid': {
            'ma': ['middag'],
            'di': <String>[],
            'wo': <String>[],
            'do': <String>[],
            'vr': <String>[],
            'za': <String>[],
            'zo': <String>[],
          },
        });
      },
    );

    testWidgets(
      'J8 zonder keuze een melding; twee keuzes gaan als gesorteerde lijst',
      (tester) async {
        final fake = fakeNieuweJongere();
        await _pomp(tester, HhPadenJongere.klussoorten, fake: fake);

        await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);
        expect(
          find.text(TekstenJongereNl.validatieKlustypesLeeg),
          findsOneWidget,
        );

        await tikTekst(tester, 'tuin');
        await tikTekst(tester, 'boodschappen');
        await tikKnop(tester, TekstenJongereNl.opslaanEnVerder);

        expect(fake.laatsteProfielBody, {
          'klustypes': ['type-boodschappen', 'type-tuin'],
        });
      },
    );
  });

  group('J9 overzicht', () {
    testWidgets(
      'indienen stuurt alleen verificatiestatus en toont de wachttekst',
      (tester) async {
        final fake = fakeJongereKlaarOmInTeDienen();
        await _pomp(tester, HhPadenJongere.overzicht, fake: fake);

        await tikKnop(tester, TekstenJongereNl.j9Indienen);

        expect(fake.laatsteProfielBody, {
          'verificatiestatus': 'in_behandeling',
        });
        expect(
          fake.profielVan(jongereId)?.verificatiestatus,
          HhScreeningStatus.inBehandeling,
        );
        expect(find.text(TekstenJongereNl.j9Ingediend), findsOneWidget);
        expect(find.text(TekstenJongereNl.j9WachtTekst), findsOneWidget);
        expect(
          find.widgetWithText(HhKnop, TekstenJongereNl.j9Indienen),
          findsNothing,
        );
      },
    );

    testWidgets('indienen offline: melding, status blijft nieuw', (
      tester,
    ) async {
      final fake = fakeJongereKlaarOmInTeDienen();
      await _pomp(tester, HhPadenJongere.overzicht, fake: fake);
      fake.isOffline = true;

      await tikKnop(tester, TekstenJongereNl.j9Indienen);

      expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
      expect(
        fake.profielVan(jongereId)?.verificatiestatus,
        HhScreeningStatus.nieuw,
      );
    });

    testWidgets('een stap tikken opent die stap', (tester) async {
      await _pomp(tester, HhPadenJongere.overzicht, fake: fakeNieuweJongere());

      await tikKnop(tester, '5. ${TekstenJongereNl.j5Titel}');

      expect(find.byType(ScreeningIbanScreen), findsOneWidget);
    });

    testWidgets(
      'Bel ons belt de meldkamer; lukt dat niet, dan het nummer in beeld',
      (tester) async {
        await _pomp(
          tester,
          HhPadenJongere.overzicht,
          fake: fakeJongereMetStatus(HhScreeningStatus.afgewezen),
          urlOpenerLukt: false,
        );

        await tikKnop(tester, TekstenJongereNl.j9BelOns);

        expect(find.textContaining('Bellen lukt niet'), findsOneWidget);
      },
    );
  });
}

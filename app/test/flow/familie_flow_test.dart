import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_familie_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/familie/model/hh_koppeling.dart';
import 'package:heitjehulp_app/features/familie/paden_familie.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/nieuwe_klus.dart';
import 'package:heitjehulp_app/features/hulpvrager/paden_hulpvrager.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_familie_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';

import '../support/hh_familie_wikkel.dart';
import '../support/hh_hulpvrager_wikkel.dart';
import '../support/hh_jongere_wikkel.dart';
import '../support/hh_uitvoeren_wikkel.dart';

void main() {
  group('aanvragen (familielid)', () {
    testWidgets('F1 -> koppelen -> vast bericht -> F1 "wacht op toestemming"', (
      tester,
    ) async {
      final familie = fakeFamilie();
      await tester.pumpWidget(
        hhFamilieWikkel(HhPaden.familie, familieGateway: familie),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenFamilieNl.f1Leeg), findsOneWidget);

      await tikKnop(tester, TekstenFamilieNl.f1Koppelen);
      await vulVeld(tester, 0, testOudereEmail);
      await tikKnop(tester, TekstenFamilieNl.aanvraagVersturen);

      expect(find.text(fakeVastBericht), findsOneWidget);
      final k = familie.alleKoppelingen.single;
      expect(k.status, KoppelingStatus.aangevraagd);
      expect(k.rechten, isEmpty);
      expect(k.oudereId, oudereId);

      await tikKnop(tester, TekstenFamilieNl.aanvraagTerug);
      // Besluit 30 sep: de aanvraag staat niet op F1 (geen adres-lek).
      expect(find.text(TekstenFamilieNl.f1AanvragenKop), findsNothing);
      expect(find.text(TekstenFamilieNl.f1Leeg), findsOneWidget);
      // Nog geen naam: de server geeft de oudere pas bij "Ja" prijs.
      expect(find.text(testOudereNaam), findsNothing);
    });

    testWidgets('onbekend adres: precies hetzelfde bericht, niets aangemaakt', (
      tester,
    ) async {
      final familie = fakeFamilie();
      await tester.pumpWidget(
        hhFamilieWikkel(HhPadenFamilie.koppelen, familieGateway: familie),
      );
      await tester.pumpAndSettle();
      await vulVeld(tester, 0, 'niemand@voorbeeld.nl');
      await tikKnop(tester, TekstenFamilieNl.aanvraagVersturen);
      expect(find.text(fakeVastBericht), findsOneWidget);
      expect(familie.alleKoppelingen, isEmpty);
    });

    testWidgets('na vijf keer: de limiet-melding', (tester) async {
      final familie = fakeFamilie();
      for (var i = 0; i < 5; i++) {
        await familie.aanvragen('iemand$i@voorbeeld.nl');
      }
      await tester.pumpWidget(
        hhFamilieWikkel(HhPadenFamilie.koppelen, familieGateway: familie),
      );
      await tester.pumpAndSettle();
      await vulVeld(tester, 0, testOudereEmail);
      await tikKnop(tester, TekstenFamilieNl.aanvraagVersturen);
      expect(find.text(TekstenFamilieNl.aanvraagLimiet), findsOneWidget);
      expect(familie.alleKoppelingen, isEmpty);
    });
  });

  group('toestemming (oudere, O12)', () {
    testWidgets('Ja: actief met beide rechten, en de zin verandert', (
      tester,
    ) async {
      final familie = fakeFamilie(
        koppelingen: [testKoppeling(status: KoppelingStatus.aangevraagd)],
      );
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenHulpvrager.gegevens,
          rol: HhRol.hulpvrager,
          familieGateway: familie,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenFamilieNl.o12Ja);
      expect(find.text(TekstenFamilieNl.o12JaGelukt), findsOneWidget);
      expect(
        find.text(TekstenFamilieNl.o12Gekoppeld(familieNaam)),
        findsOneWidget,
      );
      final k = familie.alleKoppelingen.single;
      expect(k.isActief, isTrue);
      expect(k.rechten, FamilieRecht.values.toSet());
    });

    testWidgets('Nee: de koppeling is weg', (tester) async {
      final familie = fakeFamilie(
        koppelingen: [testKoppeling(status: KoppelingStatus.aangevraagd)],
      );
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenHulpvrager.gegevens,
          rol: HhRol.hulpvrager,
          familieGateway: familie,
        ),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenFamilieNl.o12Nee);
      expect(familie.alleKoppelingen, isEmpty);
      expect(find.text(TekstenFamilieNl.o12Niemand), findsOneWidget);
    });

    testWidgets('ontkoppelen: eerst een bevestigvraag, "Nee" laat staan', (
      tester,
    ) async {
      final familie = fakeFamilie(koppelingen: [testKoppeling()]);
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenHulpvrager.gegevens,
          rol: HhRol.hulpvrager,
          familieGateway: familie,
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenFamilieNl.o12Ontkoppelen);
      expect(
        find.text(TekstenFamilieNl.o12OntkoppelVraag(familieNaam)),
        findsOneWidget,
      );
      await tikKnop(tester, TekstenFamilieNl.o12OntkoppelNee);
      expect(familie.alleKoppelingen, hasLength(1));

      await tikKnop(tester, TekstenFamilieNl.o12Ontkoppelen);
      await tikKnop(tester, TekstenFamilieNl.o12OntkoppelJa);
      expect(familie.alleKoppelingen, isEmpty);
      expect(find.text(TekstenFamilieNl.o12OntkoppeldGelukt), findsOneWidget);
    });
  });

  group('plaatsen namens de oudere (F2)', () {
    testWidgets('F3 -> de M4-stroom -> klus met hulpvrager = oudere, '
        'geplaatst_door = ik, bron familie; terug op F3', (tester) async {
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPaden.familie,
          familieGateway: fakeFamilie(koppelingen: [testKoppeling()]),
          uitvoerGateway: fakeUitvoer(klussen: const [], ikBen: familieId),
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();
      // Eén oudere: F1 stuurt meteen door naar F3.
      await tikKnop(tester, TekstenFamilieNl.f3HulpVragen(testOudereNaam));

      await tikTekst(tester, 'klusje in huis');
      await tikTekst(tester, TekstenHulpvragerNl.dagMorgen);
      await tikTekst(tester, TekstenHulpvragerNl.dagdeelMiddag);
      // Het adres van de OUDERE is bekend: het staat in de samenvatting.
      expect(find.text('Prins Bernhardlaan 12, 4003 AB Tiel'), findsOneWidget);
      await tikKnop(tester, TekstenHulpvragerNl.bevestigenAkkoord);

      final body = klusGateway.aangemaakteKlussen.single.alsBody;
      expect(body['hulpvrager'], oudereId);
      expect(body['geplaatst_door'], familieId);
      expect(body['bron'], NieuweKlus.bronFamilie);
      expect(body['status'], 'open');
      expect(
        find.text(TekstenFamilieNl.f3Titel(testOudereNaam)),
        findsOneWidget,
      );
    });

    testWidgets('meekijken zonder recht plaatsen verbergt F2', (tester) async {
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPaden.familie,
          familieGateway: fakeFamilie(
            koppelingen: [
              testKoppeling(rechten: {FamilieRecht.meekijken}),
            ],
          ),
          uitvoerGateway: fakeUitvoer(ikBen: familieId),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(TekstenFamilieNl.f3Titel(testOudereNaam)),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          HhKnop,
          TekstenFamilieNl.f3HulpVragen(testOudereNaam),
        ),
        findsNothing,
      );
    });

    testWidgets('een oudere die zelf inlogt plaatst gewoon voor zichzelf', (
      tester,
    ) async {
      // Ook als er (van een eerdere familiesessie) nog "namens" zou staan:
      // de naad geldt alleen voor de rol familie.
      final klusGateway = fakeKlusGateway();
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenHulpvrager.hulpVragenWat,
          rol: HhRol.hulpvrager,
          klusGateway: klusGateway,
        ),
      );
      await tester.pumpAndSettle();
      await tikTekst(tester, 'klusje in huis');
      await tikTekst(tester, TekstenHulpvragerNl.dagMorgen);
      await tikTekst(tester, TekstenHulpvragerNl.dagdeelMiddag);
      await tikKnop(tester, TekstenHulpvragerNl.bevestigenAkkoord);
      final body = klusGateway.aangemaakteKlussen.single.alsBody;
      expect(body['bron'], NieuweKlus.bronApp);
      expect(body['geplaatst_door'], oudereId);
    });
  });
}

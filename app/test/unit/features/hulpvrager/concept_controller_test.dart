import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/fake_adres_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hulpvraag_concept.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/nieuwe_klus.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/concept_controller.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvraag_plaatser.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';

import '../../../support/hh_hulpvrager_wikkel.dart';
import '../../../support/hh_toegang_wikkel.dart';

void main() {
  group('ConceptController', () {
    test('begint leeg en vult stap voor stap, zonder mutatie', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);
      final begin = container.read(conceptProvider);
      expect(begin.isLeeg, isTrue);

      controller.kiesKlustype(testKlustypes.first);
      final naWat = container.read(conceptProvider);
      expect(naWat.heeftWat, isTrue);
      expect(begin.klustype, isNull, reason: 'oude state is niet gewijzigd');

      controller.zetOmschrijving('Heg knippen');
      controller.zetFoto(testKlusFoto);
      controller.kiesDagKeuze(HhDagKeuze.morgen);
      final naDag = container.read(conceptProvider);
      expect(naDag.dag, DateTime(2026, 9, 16));
      expect(naDag.vanafMinuten, 10 * 60, reason: 'tijdwiel begint op 10:00');
      expect(naDag.heeftWanneer, isTrue);
      expect(naDag.isCompleet, isFalse, reason: 'adres ontbreekt');

      controller.zetWaar(
        adres: 'Kerkstraat 1',
        postcode: '4001 AA',
        plaats: 'Tiel',
      );
      final compleet = container.read(conceptProvider);
      expect(compleet.isCompleet, isTrue);
      expect(naWat.adres, isNull, reason: 'tussenstate blijft zoals hij was');
    });

    test('punt B: ergens anders zonder adres maakt waar leeg', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);
      controller.zetWaar(
        adres: 'Kerkstraat 1',
        postcode: '4001 AA',
        plaats: 'Tiel',
      );

      controller.zetElders(null);
      final leeg = container.read(conceptProvider);
      expect(leeg.isElders, isTrue);
      expect(leeg.heeftWaar, isFalse);

      controller.zetElders(FakeAdresGateway.kerkstraat1);
      final elders = container.read(conceptProvider);
      expect(elders.adres, 'Kerkstraat 1');
      expect(elders.postcode, '4001 MA');
      expect(elders.heeftWaar, isTrue);

      controller.zetWaar(adres: 'Thuis 2', postcode: '4003 AB', plaats: 'Tiel');
      final thuis = container.read(conceptProvider);
      expect(thuis.isElders, isFalse);
      expect(thuis.eldersAdres, FakeAdresGateway.kerkstraat1);
    });

    test('vandaag: het tijdwiel begint twee hele uren na nu', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      container.read(conceptProvider.notifier).kiesDagKeuze(HhDagKeuze.vandaag);
      // testNu is 10:00.
      expect(container.read(conceptProvider).vanafMinuten, 12 * 60);
    });

    test('een gekozen tijd blijft staan bij een andere dag', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);
      controller.kiesDagKeuze(HhDagKeuze.morgen);
      controller.zetVanaf(14 * 60 + 30);
      controller.kiesDag(DateTime(2026, 9, 20, 9));
      final concept = container.read(conceptProvider);
      expect(concept.dagKeuze, HhDagKeuze.andereDag);
      expect(concept.dag, DateTime(2026, 9, 20));
      expect(concept.vanafMinuten, 14 * 60 + 30);
    });

    test('van morgen terug naar kies een dag houdt de dag vast', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);

      controller.kiesDagKeuze(HhDagKeuze.morgen);
      controller.kiesDagKeuze(HhDagKeuze.andereDag);

      expect(container.read(conceptProvider).dag, DateTime(2026, 9, 16));
    });

    test('eindtijd verplicht: een uur na de begintijd, en na het begin', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);
      expect(container.read(conceptProvider).heeftGeldigeEindtijd, isFalse);

      controller.kiesDagKeuze(HhDagKeuze.morgen);
      expect(container.read(conceptProvider).eindMinuten, 11 * 60);
      expect(container.read(conceptProvider).heeftGeldigeEindtijd, isTrue);

      controller.zetTot(9 * 60);
      expect(container.read(conceptProvider).heeftGeldigeEindtijd, isFalse);
    });

    test('omschrijving: hooguit 300 tekens, minstens 5 telt als ingevuld', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);
      controller.zetOmschrijving('x' * 350);
      expect(container.read(conceptProvider).omschrijving.length, 300);
      controller.zetOmschrijving(' abc ');
      expect(container.read(conceptProvider).heeftOmschrijving, isFalse);
      controller.zetOmschrijving('Heg knippen');
      expect(container.read(conceptProvider).heeftOmschrijving, isTrue);
    });

    test('foto weghalen maakt het concept weer onvolledig', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);
      controller.zetFoto(testKlusFoto);
      expect(container.read(conceptProvider).heeftFoto, isTrue);
      controller.zetFoto(null);
      expect(container.read(conceptProvider).heeftFoto, isFalse);
    });

    test('wis maakt alles leeg', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);
      controller.kiesKlustype(testKlustypes.first);

      controller.wis();

      expect(container.read(conceptProvider).isLeeg, isTrue);
    });
  });

  group('HulpvraagPlaatser', () {
    final kleineKlusjes = testKlustypes.firstWhere((t) => t.id == 'kt-klusje');
    HulpvraagConcept compleetConcept({bool metEindtijd = true}) =>
        HulpvraagConcept(
          klustype: kleineKlusjes,
          omschrijving: ' Lamp ophangen. ',
          foto: testKlusFoto,
          dagKeuze: HhDagKeuze.morgen,
          dag: DateTime(2026, 9, 16),
          vanafMinuten: 9 * 60,
          totMinuten: metEindtijd ? 10 * 60 + 30 : null,
          adres: 'Kerkstraat 1',
          postcode: '4001 AA',
          plaats: 'Tiel',
        );

    test(
      'plaatst precies een klus met status open, foto, vinkje en tijden',
      () async {
        final gateway = fakeKlusGateway();
        final container = hulpvragerContainer(klusGateway: gateway);

        final result = await container
            .read(hulpvraagPlaatserProvider)
            .plaats(concept: compleetConcept(), gebruikerId: 'id-hulpvrager');

        expect(result, isA<Ok<GeplaatsteHulpvraag>>());
        expect(gateway.aangemaakteKlussen, hasLength(1));
        final klus = gateway.aangemaakteKlussen.single;
        final body = klus.alsBody;
        expect(body['status'], 'open');
        expect(body['bron'], 'app');
        expect(body['hulpvrager'], 'id-hulpvrager');
        expect(body['geplaatst_door'], 'id-hulpvrager');
        expect(body['klustype'], 'kt-klusje');
        expect(body['bedrag_bruto'], 1250);
        expect(body['vergoeding_jongere'], 1250);
        expect(body['commissie'], 0);
        expect(body['adres'], 'Kerkstraat 1, 4001 AA Tiel');
        expect(body['omschrijving'], 'Lamp ophangen.');
        expect(body['nee_lijst_akkoord'], isTrue);
        expect(identical(klus.foto, testKlusFoto), isTrue);
        expect(
          body.containsKey('foto'),
          isFalse,
          reason: 'foto gaat als bestand',
        );
        expect(body.containsKey('toegewezen_jongere'), isFalse);
        expect(body.containsKey('lat'), isFalse);
        // Keur- en rekenvelden zet de server (rule 101 weigert ze anders).
        for (final veld in [
          'klus_goedgekeurd_op',
          'min_leeftijd',
          'geboren_uiterlijk',
          'controle_markering',
        ]) {
          expect(body.containsKey(veld), isFalse, reason: veld);
        }
        expect(
          DateTime.parse(body['wanneer_van'] as String).toLocal(),
          DateTime(2026, 9, 16, 9),
        );
        expect(
          DateTime.parse(body['wanneer_tot'] as String).toLocal(),
          DateTime(2026, 9, 16, 10, 30),
        );
      },
    );

    test('zonder eindtijd plaatst niets (feedbackronde 1)', () async {
      final gateway = fakeKlusGateway();
      final container = hulpvragerContainer(klusGateway: gateway);

      final result = await container
          .read(hulpvraagPlaatserProvider)
          .plaats(
            concept: compleetConcept(metEindtijd: false),
            gebruikerId: 'id-hulpvrager',
          );

      expect(result, isA<Err<GeplaatsteHulpvraag>>());
      expect(gateway.aangemaakteKlussen, isEmpty);
    });

    test('zonder foto plaatst niets', () async {
      final gateway = fakeKlusGateway();
      final container = hulpvragerContainer(klusGateway: gateway);
      final plaatser = container.read(hulpvraagPlaatserProvider);

      final zonderFoto = await plaatser.plaats(
        concept: compleetConcept().copyWith(foto: () => null),
        gebruikerId: 'id-hulpvrager',
      );

      expect(zonderFoto, isA<Err<GeplaatsteHulpvraag>>());
      expect(gateway.aangemaakteKlussen, isEmpty);
    });

    // M6: de app schrijft GEEN logregel meer; dat doet de hook zelf bij het
    // aanmaken van de klus (backend OPEN-PUNT 16, app OPEN-PUNT M4:32).
    test('schrijft zelf geen logregel meer: alleen de klus gaat weg', () async {
      final gateway = fakeKlusGateway();
      final container = hulpvragerContainer(klusGateway: gateway);

      final result = await container
          .read(hulpvraagPlaatserProvider)
          .plaats(concept: compleetConcept(), gebruikerId: 'id-hulpvrager');

      final geplaatst = (result as Ok<GeplaatsteHulpvraag>).waarde;
      expect(geplaatst.klusId, isNotEmpty);
      expect(gateway.aangemaakteKlussen, hasLength(1));
    });

    test('onvolledig concept plaatst niets', () async {
      final gateway = fakeKlusGateway();
      final container = hulpvragerContainer(klusGateway: gateway);

      final result = await container
          .read(hulpvraagPlaatserProvider)
          .plaats(
            concept: const HulpvraagConcept(),
            gebruikerId: 'id-hulpvrager',
          );

      expect(result, isA<Err<GeplaatsteHulpvraag>>());
      expect(gateway.aangemaakteKlussen, isEmpty);
    });

    test('offline: fout terug, niets geplaatst', () async {
      final gateway = fakeKlusGateway()..isOffline = true;
      final container = hulpvragerContainer(klusGateway: gateway);

      final result = await container
          .read(hulpvraagPlaatserProvider)
          .plaats(concept: compleetConcept(), gebruikerId: 'id-hulpvrager');

      expect(
        (result as Err<GeplaatsteHulpvraag>).fout.soort,
        HhFoutSoort.geenVerbinding,
      );
      expect(gateway.aangemaakteKlussen, isEmpty);
    });

    test('401 bij plaatsen logt uit met reden sessie verlopen', () async {
      final gateway = fakeKlusGateway()
        ..volgendeFout = const HhFout(HhFoutSoort.nietIngelogd);
      final container = hulpvragerContainer(
        klusGateway: gateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
      );

      await container
          .read(hulpvraagPlaatserProvider)
          .plaats(concept: compleetConcept(), gebruikerId: 'id-hulpvrager');

      final sessie = container.read(sessieControllerProvider);
      expect(sessie, isA<SessieUitgelogd>());
      expect((sessie as SessieUitgelogd).reden, UitlogReden.sessieVerlopen);
    });
  });

  group('GegevensController', () {
    test(
      'laadt de eigen gegevens en stuurt bij bijwerken alleen de velden',
      () async {
        final gateway = fakeKlusGateway();
        final container = hulpvragerContainer(
          klusGateway: gateway,
          sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
        );

        final gegevens = await container.read(gegevensProvider.future);
        expect(gegevens.adres, 'Prins Bernhardlaan 12');

        final result = await container
            .read(gegevensProvider.notifier)
            .bijwerken({'plaats': 'Zaltbommel'});

        expect(result, isA<Ok<void>>());
        expect(gateway.laatsteGegevensBody, {'plaats': 'Zaltbommel'});
        expect(container.read(gegevensProvider).value?.plaats, 'Zaltbommel');
        expect(gateway.aantalGegevensAanvragen, 1, reason: 'geen herlading');
      },
    );

    test('lege wijziging stuurt niets naar de server', () async {
      final gateway = fakeKlusGateway();
      final container = hulpvragerContainer(
        klusGateway: gateway,
        sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
      );
      await container.read(gegevensProvider.future);

      final result = await container
          .read(gegevensProvider.notifier)
          .bijwerken({});

      expect(result, isA<Ok<void>>());
      expect(gateway.laatsteGegevensBody, isNull);
    });
  });
}

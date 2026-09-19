import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
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

      controller.kiesDagKeuze(HhDagKeuze.morgen);
      expect(container.read(conceptProvider).dag, DateTime(2026, 9, 16));
      expect(container.read(conceptProvider).heeftWanneer, isFalse);

      controller.kiesDagdeel(HhDagdeel.middag);
      expect(container.read(conceptProvider).heeftWanneer, isTrue);

      controller.zetWaar(
        adres: 'Kerkstraat 1',
        postcode: '4001 AA',
        plaats: 'Tiel',
        toelichting: 'Twee tassen.',
      );
      final compleet = container.read(conceptProvider);
      expect(compleet.isCompleet, isTrue);
      expect(compleet.klustype, testKlustypes.first);
      expect(naWat.adres, isNull, reason: 'tussenstate blijft zoals hij was');
    });

    test('een eigen dag zet de dagkeuze op andereDag', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);

      controller.kiesDag(DateTime(2026, 9, 20, 14));

      final concept = container.read(conceptProvider);
      expect(concept.dagKeuze, HhDagKeuze.andereDag);
      expect(concept.dag, DateTime(2026, 9, 20));
    });

    test('van morgen terug naar kies een dag houdt de dag vast', () {
      final container = hulpvragerContainer(klusGateway: fakeKlusGateway());
      final controller = container.read(conceptProvider.notifier);

      controller.kiesDagKeuze(HhDagKeuze.morgen);
      controller.kiesDagKeuze(HhDagKeuze.andereDag);

      expect(container.read(conceptProvider).dag, DateTime(2026, 9, 16));
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
    HulpvraagConcept compleetConcept() => HulpvraagConcept(
      klustype: testKlustypes[2], // klusje in huis, 1250
      dagKeuze: HhDagKeuze.morgen,
      dag: DateTime(2026, 9, 16),
      dagdeel: HhDagdeel.ochtend,
      adres: 'Kerkstraat 1',
      postcode: '4001 AA',
      plaats: 'Tiel',
      toelichting: ' Lamp ophangen. ',
    );

    test(
      'plaatst precies een klus met status open en juiste bedragen',
      () async {
        final gateway = fakeKlusGateway();
        final container = hulpvragerContainer(klusGateway: gateway);

        final result = await container
            .read(hulpvraagPlaatserProvider)
            .plaats(concept: compleetConcept(), gebruikerId: 'id-hulpvrager');

        expect(result, isA<Ok<GeplaatsteHulpvraag>>());
        expect(gateway.aangemaakteKlussen, hasLength(1));
        final body = gateway.aangemaakteKlussen.single.alsBody;
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
        expect(body.containsKey('toegewezen_jongere'), isFalse);
        expect(body.containsKey('lat'), isFalse);
        expect(
          DateTime.parse(body['wanneer_van'] as String).toLocal(),
          DateTime(2026, 9, 16, 9),
        );
        expect(
          DateTime.parse(body['wanneer_tot'] as String).toLocal(),
          DateTime(2026, 9, 16, 12),
        );
      },
    );

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

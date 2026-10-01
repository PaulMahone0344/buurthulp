import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/pb/coordinator_gateway.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_incident.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_incidenten_screen.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_klussen_screen.dart';
import 'package:heitjehulp_app/features/coordinator/widget/incident_tegel.dart';
import 'package:heitjehulp_app/features/coordinator/widget/kandidaat_lijst.dart';
import 'package:heitjehulp_app/features/coordinator/widget/vrijgeef_blok.dart';
import 'package:heitjehulp_app/features/jongere/klussen/screen/klussen_home_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_coordinator_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../support/hh_coordinator_wikkel.dart';
import '../support/hh_jongere_wikkel.dart';

/// Tikt op een knop in een dialoog (die staat buiten de scrollvlakken van
/// het scherm, dus zonder ensureVisible).
Future<void> _tikInDialoog(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(TextButton, label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('C1 meldingen binnenkrijgen', () {
    testWidgets('een nieuwe melding van de server komt bovenaan te staan', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      expect(find.byType(CoordinatorIncidentenScreen), findsOneWidget);
      expect(find.byType(IncidentTegel), findsNWidgets(2));

      fake.stuurIncident(
        testIncident(
          id: 'i-net-binnen',
          soort: HhIncidentSoort.nood,
          aangemaaktOp: coordinatorNu,
          melderNaam: 'Meneer B. Jansen',
          omschrijving: 'Geen gehoor bij de voordeur.',
        ),
      );
      await tester.pumpAndSettle();

      final tegels = tester.widgetList<IncidentTegel>(
        find.byType(IncidentTegel),
      );
      expect(tegels.first.incident.id, 'i-net-binnen');
      expect(tegels, hasLength(3));
    });

    testWidgets('een noodmelding laat het toestel trillen, een probleem niet', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      final tril = TrilTeller();
      await pompCoordinatorApp(tester, gateway: fake, tril: tril);
      expect(tril.aantal, 0);

      fake.stuurIncident(
        testIncident(id: 'i-gewoon', aangemaaktOp: coordinatorNu),
      );
      await tester.pumpAndSettle();
      expect(tril.aantal, 0);

      fake.stuurIncident(
        testIncident(
          id: 'i-nood-2',
          soort: HhIncidentSoort.nood,
          aangemaaktOp: coordinatorNu,
        ),
      );
      await tester.pumpAndSettle();
      expect(tril.aantal, 1);
    });

    testWidgets('een wijziging van een bekende melding trilt niet opnieuw', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      final tril = TrilTeller();
      await pompCoordinatorApp(tester, gateway: fake, tril: tril);

      final bestaand = fake.alleIncidenten.firstWhere((i) => i.id == 'i-nood');
      fake.stuurIncident(bestaand, soort: IncidentWijzigingSoort.gewijzigd);
      await tester.pumpAndSettle();

      expect(tril.aantal, 0);
      expect(find.byType(IncidentTegel), findsNWidgets(2));
    });

    testWidgets('de teller op het tabblad loopt mee met wat binnenkomt', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);
      expect(
        find.text(TekstenCoordinatorNl.tabIncidentenTeller(2)),
        findsOneWidget,
      );

      fake.stuurIncident(
        testIncident(id: 'i-erbij', aangemaaktOp: coordinatorNu),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(TekstenCoordinatorNl.tabIncidentenTeller(3)),
        findsOneWidget,
      );
    });
  });

  group('C1 afhandelen', () {
    testWidgets('afhandelen haalt de melding uit de open lijst', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.soortNood);
      await vulVeld(tester, 0, 'Ambulance gebeld.');
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenCoordinatorNl.c1Afhandelen);

      expect(find.text(TekstenCoordinatorNl.c1Afgehandeld), findsOneWidget);

      await tikTekst(tester, TekstenNl.terug);
      expect(find.byType(IncidentTegel), findsOneWidget);
      expect(
        find.text(TekstenCoordinatorNl.tabIncidentenTeller(1)),
        findsOneWidget,
      );

      await tikTekst(tester, TekstenCoordinatorNl.c1FilterAfgehandeld);
      expect(find.byType(IncidentTegel), findsNWidgets(2));
    });

    testWidgets('een fout van de server laat de melding open staan', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.soortNood);
      await vulVeld(tester, 0, 'Poging.');
      await tester.pumpAndSettle();
      fake.isOffline = true;
      await tikKnop(tester, TekstenCoordinatorNl.c1Afhandelen);

      expect(find.text(TekstenNl.foutGeenVerbinding), findsOneWidget);
      expect(
        fake.alleIncidenten.firstWhere((i) => i.id == 'i-nood').isAfgehandeld,
        isFalse,
      );
    });
  });

  group('C2 koppelen', () {
    testWidgets('koppelen zet de klus op naam van de jongere', (tester) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.tabKlussen);
      expect(find.byType(CoordinatorKlussenScreen), findsOneWidget);

      await tikTekst(tester, TekstenCoordinatorNl.c2Koppelen);
      expect(find.byType(KandidaatLijst), findsOneWidget);

      await tikTekst(tester, 'Sanne Bakker');
      expect(find.text(TekstenCoordinatorNl.c2BevestigTitel), findsOneWidget);
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigKoppelen);

      expect(
        find.text(TekstenCoordinatorNl.c2Gekoppeld('Sanne Bakker')),
        findsOneWidget,
      );
      final klus = fake.klusVan('k-open-oud')!;
      expect(klus.status, HhKlusStatus.geaccepteerd);
      expect(klus.toegewezenJongereId, 'id-jongere-2');
      expect(fake.gekoppeldeIds, ['k-open-oud']);
    });

    testWidgets('bij een andere wijk staat er een waarschuwing in de vraag', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.tabKlussen);
      await tikTekst(tester, TekstenCoordinatorNl.c2Koppelen);
      await tikTekst(tester, 'Daan Verhoeven');

      expect(
        find.text(
          TekstenCoordinatorNl.c2AndereWijkWaarschuwing(
            wijkPassewaaijNaam,
            wijkWestNaam,
          ),
        ),
        findsOneWidget,
      );

      // Koppelen over de wijkgrens mag: het is een waarschuwing, geen slot.
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigKoppelen);
      expect(fake.klusVan('k-open-oud')!.toegewezenJongereId, 'id-jongere-3');
    });

    testWidgets('annuleren koppelt niets', (tester) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.tabKlussen);
      await tikTekst(tester, TekstenCoordinatorNl.c2Koppelen);
      await tikTekst(tester, 'Sanne Bakker');
      await _tikInDialoog(tester, TekstenNl.annuleren);

      expect(fake.gekoppeldeIds, isEmpty);
      expect(fake.klusVan('k-open-oud')!.isOpen, isTrue);
    });

    testWidgets('409: iemand anders was eerder, met de melding van de server', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.tabKlussen);
      await tikTekst(tester, TekstenCoordinatorNl.c2Koppelen);

      fake.koppelUitkomst = const KoppelGeweigerd(
        KoppelReden.bezet,
        melding: 'Deze klus is net door iemand anders aangenomen.',
      );
      await tikTekst(tester, 'Sanne Bakker');
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigKoppelen);

      expect(
        find.text('Deze klus is net door iemand anders aangenomen.'),
        findsOneWidget,
      );
      expect(fake.klusVan('k-open-oud')!.isOpen, isTrue);
    });

    testWidgets('409: de jongere is niet goedgekeurd', (tester) async {
      final fake = fakeCoordinator();
      fake.nietGoedgekeurd.add('id-jongere-2');
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.tabKlussen);
      await tikTekst(tester, TekstenCoordinatorNl.c2Koppelen);
      await tikTekst(tester, 'Sanne Bakker');
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigKoppelen);

      expect(
        find.text(TekstenCoordinatorNl.c2KoppelenNietGoedgekeurd),
        findsOneWidget,
      );
      expect(fake.klusVan('k-open-oud')!.isOpen, isTrue);
    });
  });

  group('C2 vrijgeven', () {
    testWidgets('vrijgeven en daarna opnieuw koppelen', (tester) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.tabKlussen);
      // De toegewezen klus staat niet in de lijst; via de melding erheen.
      await tikTekst(tester, TekstenCoordinatorNl.tabIncidenten);
      await tikTekst(tester, TekstenCoordinatorNl.soortProbleem);
      await tikKnop(tester, TekstenCoordinatorNl.c1NaarKlus);

      // De melding hangt aan k-open-oud; die is open, dus eerst koppelen
      // zodat er iets is om vrij te geven.
      expect(find.byType(KandidaatLijst), findsOneWidget);
      await tikTekst(tester, 'Sanne Bakker');
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigKoppelen);

      expect(find.byType(VrijgeefBlok), findsOneWidget);
      await vulVeld(tester, 0, 'Jongere is ziek geworden.');
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenCoordinatorNl.c2Vrijgeven);
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigVrijgeven);

      expect(find.text(TekstenCoordinatorNl.c2Vrijgegeven), findsOneWidget);
      expect(fake.vrijgegevenIds, ['k-open-oud']);
      expect(fake.klusVan('k-open-oud')!.isOpen, isTrue);

      // En hij is meteen weer te koppelen.
      expect(find.byType(KandidaatLijst), findsOneWidget);
      await tikTekst(tester, 'Yusuf el Amrani');
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigKoppelen);
      expect(fake.klusVan('k-open-oud')!.toegewezenJongereId, 'id-jongere-1');
    });

    testWidgets('409: de klus staat niet op geaccepteerd of onderweg', (
      tester,
    ) async {
      final fake = fakeCoordinator();
      await pompCoordinatorApp(tester, gateway: fake);

      await tikTekst(tester, TekstenCoordinatorNl.tabIncidenten);
      await tikTekst(tester, TekstenCoordinatorNl.soortProbleem);
      await tikKnop(tester, TekstenCoordinatorNl.c1NaarKlus);
      await tikTekst(tester, 'Sanne Bakker');
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigKoppelen);

      fake.koppelUitkomst = const KoppelGeweigerd(KoppelReden.nietVrijTeGeven);
      await vulVeld(tester, 0, 'Poging.');
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenCoordinatorNl.c2Vrijgeven);
      await _tikInDialoog(tester, TekstenCoordinatorNl.c2BevestigVrijgeven);

      expect(
        find.text(TekstenCoordinatorNl.c2VrijgevenNietMogelijk),
        findsOneWidget,
      );
    });
  });

  group('guard', () {
    testWidgets('een jongere komt niet op de coordinatorschermen', (
      tester,
    ) async {
      final container = await pompCoordinatorApp(
        tester,
        gateway: fakeCoordinator(),
        rol: HhRol.jongere,
      );
      addTearDown(container.dispose);

      // De jongere landt op zijn eigen J11, niet op C1.
      expect(find.byType(KlussenHomeScreen), findsOneWidget);
      expect(find.byType(CoordinatorIncidentenScreen), findsNothing);
      expect(find.byType(CoordinatorKlussenScreen), findsNothing);
    });

    testWidgets('een jongere wordt van elk coordinatorpad teruggestuurd', (
      tester,
    ) async {
      final container = await pompCoordinatorApp(
        tester,
        gateway: fakeCoordinator(),
        rol: HhRol.jongere,
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      for (final pad in [
        HhPaden.coordinator,
        HhPadenCoordinator.klussen,
        HhPadenCoordinator.instellingen,
        HhPadenCoordinator.klusDetail('k-open-oud'),
        HhPadenCoordinator.incidentDetail('i-nood'),
      ]) {
        router.go(pad);
        await tester.pumpAndSettle();

        expect(
          find.byType(CoordinatorIncidentenScreen),
          findsNothing,
          reason: pad,
        );
        expect(
          find.byType(CoordinatorKlussenScreen),
          findsNothing,
          reason: pad,
        );
        expect(
          router.state.matchedLocation,
          isNot(startsWith(HhPaden.coordinator)),
          reason: pad,
        );
      }
    });
  });
}

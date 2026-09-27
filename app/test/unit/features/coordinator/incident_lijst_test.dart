import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/coordinator/domein/incident_lijst.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_incident.dart';

import '../../../support/hh_coordinator_wikkel.dart';

void main() {
  group('sorteren', () {
    test('zet de nieuwste melding bovenaan', () {
      final oud = testIncident(
        id: 'oud',
        aangemaaktOp: DateTime(2026, 9, 15, 8),
      );
      final nieuw = testIncident(
        id: 'nieuw',
        aangemaaktOp: DateTime(2026, 9, 15, 9, 30),
      );

      final gesorteerd = sorteerIncidenten([oud, nieuw]);

      expect([for (final i in gesorteerd) i.id], ['nieuw', 'oud']);
    });

    test('laat de volgorde bij een gelijke tijd niet springen', () {
      final moment = DateTime(2026, 9, 15, 9);
      final a = testIncident(id: 'aaa', aangemaaktOp: moment);
      final b = testIncident(id: 'bbb', aangemaaktOp: moment);

      expect([for (final i in sorteerIncidenten([a, b])) i.id], ['bbb', 'aaa']);
      expect([for (final i in sorteerIncidenten([b, a])) i.id], ['bbb', 'aaa']);
    });
  });

  group('filteren', () {
    test('open toont alleen meldingen zonder afhandeling', () {
      final lijst = filterIncidenten(testIncidenten(), IncidentFilter.open);

      expect([for (final i in lijst) i.id], ['i-nood', 'i-probleem']);
    });

    test('afgehandeld toont alleen meldingen met een afhandeling', () {
      final lijst = filterIncidenten(
        testIncidenten(),
        IncidentFilter.afgehandeld,
      );

      expect([for (final i in lijst) i.id], ['i-afgehandeld']);
    });

    test('een afhandeling van alleen spaties telt als open', () {
      final incident = testIncident(id: 'i1', afhandeling: '   ');

      expect(incident.isAfgehandeld, isFalse);
      expect(filterIncidenten([incident], IncidentFilter.open), hasLength(1));
    });
  });

  group('tellen', () {
    test('telt alleen de openstaande meldingen', () {
      expect(telOpenIncidenten(testIncidenten()), 2);
    });

    test('telt nul bij een lege lijst', () {
      expect(telOpenIncidenten(const <HhIncident>[]), 0);
    });
  });

  group('metIncident', () {
    test('zet een onbekende melding bovenaan zonder de oude lijst te wijzigen', () {
      final huidige = sorteerIncidenten(testIncidenten());
      final nieuw = testIncident(
        id: 'i-nieuw',
        aangemaaktOp: coordinatorNu,
      );

      final na = metIncident(huidige, nieuw);

      expect(na.first.id, 'i-nieuw');
      expect(na, hasLength(huidige.length + 1));
      expect(huidige.any((i) => i.id == 'i-nieuw'), isFalse);
    });

    test('vervangt een bekende melding in plaats van hem te verdubbelen', () {
      final huidige = sorteerIncidenten(testIncidenten());
      final bijgewerkt = huidige
          .firstWhere((i) => i.id == 'i-nood')
          .metAfhandeling('Ambulance gebeld.');

      final na = metIncident(huidige, bijgewerkt);

      expect(na, hasLength(huidige.length));
      expect(na.firstWhere((i) => i.id == 'i-nood').isAfgehandeld, isTrue);
    });
  });

  test('zonderIncident haalt de melding eruit', () {
    final huidige = sorteerIncidenten(testIncidenten());

    final na = zonderIncident(huidige, 'i-nood');

    expect(na, hasLength(huidige.length - 1));
    expect(na.any((i) => i.id == 'i-nood'), isFalse);
  });

  test('een onbekende soort van de server telt als overig', () {
    expect(HhIncidentSoort.vanCode('ramp'), HhIncidentSoort.overig);
    expect(HhIncidentSoort.vanCode('nood'), HhIncidentSoort.nood);
  });
}

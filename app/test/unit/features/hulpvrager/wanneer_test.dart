import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/wanneer.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hulpvraag_concept.dart';

void main() {
  final nu = DateTime(2026, 9, 15, 10, 30); // dinsdag

  group('dagVoorKeuze', () {
    test('vandaag is de datum van nu, om middernacht', () {
      expect(dagVoorKeuze(HhDagKeuze.vandaag, nu), DateTime(2026, 9, 15));
    });

    test('morgen is een dag later', () {
      expect(dagVoorKeuze(HhDagKeuze.morgen, nu), DateTime(2026, 9, 16));
    });

    test('morgen over een maandgrens', () {
      final eindSeptember = DateTime(2026, 9, 30, 23, 59);
      expect(
        dagVoorKeuze(HhDagKeuze.morgen, eindSeptember),
        DateTime(2026, 10, 1),
      );
    });

    test('morgen over een jaargrens', () {
      expect(
        dagVoorKeuze(HhDagKeuze.morgen, DateTime(2026, 12, 31, 8)),
        DateTime(2027, 1, 1),
      );
    });

    test('een andere dag kiest de gebruiker zelf', () {
      expect(dagVoorKeuze(HhDagKeuze.andereDag, nu), isNull);
    });
  });

  group('tijdvakVoor', () {
    test('ochtend is 9 tot 12', () {
      final vak = tijdvakVoor(DateTime(2026, 9, 16), HhDagdeel.ochtend);
      expect(vak.van, DateTime(2026, 9, 16, 9));
      expect(vak.tot, DateTime(2026, 9, 16, 12));
    });

    test('middag is 13 tot 17, avond 18 tot 20', () {
      final dag = DateTime(2026, 9, 16);
      expect(tijdvakVoor(dag, HhDagdeel.middag).van.hour, 13);
      expect(tijdvakVoor(dag, HhDagdeel.middag).tot.hour, 17);
      expect(tijdvakVoor(dag, HhDagdeel.avond).van.hour, 18);
      expect(tijdvakVoor(dag, HhDagdeel.avond).tot.hour, 20);
    });

    test('een dag met tijd erin wordt eerst op middernacht gezet', () {
      final vak = tijdvakVoor(DateTime(2026, 9, 16, 15, 45), HhDagdeel.avond);
      expect(vak.van, DateTime(2026, 9, 16, 18));
    });
  });

  group('isVoorbij', () {
    test('de ochtend van vandaag om half elf is nog niet voorbij', () {
      expect(isVoorbij(DateTime(2026, 9, 15), HhDagdeel.ochtend, nu), isFalse);
    });

    test('de ochtend van vandaag is om twaalf uur voorbij', () {
      expect(
        isVoorbij(
          DateTime(2026, 9, 15),
          HhDagdeel.ochtend,
          DateTime(2026, 9, 15, 12),
        ),
        isTrue,
      );
    });

    test('gisteren is altijd voorbij, morgen nooit', () {
      expect(isVoorbij(DateTime(2026, 9, 14), HhDagdeel.avond, nu), isTrue);
      expect(isVoorbij(DateTime(2026, 9, 16), HhDagdeel.ochtend, nu), isFalse);
    });
  });

  group('komendeDagen', () {
    test('begint vandaag en telt door over de maandgrens', () {
      final dagen = komendeDagen(DateTime(2026, 9, 29, 20), 4);
      expect(dagen, [
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
      ]);
    });
  });

  group('teksten', () {
    test('dagTekst zegt vandaag, morgen of de datum', () {
      expect(dagTekst(DateTime(2026, 9, 15), nu), 'vandaag');
      expect(dagTekst(DateTime(2026, 9, 16), nu), 'morgen');
      expect(dagTekst(DateTime(2026, 9, 17), nu), 'donderdag 17 september');
    });

    test('datumTekst kent alle weekdagen en maanden', () {
      expect(datumTekst(DateTime(2026, 1, 5)), 'maandag 5 januari');
      expect(datumTekst(DateTime(2026, 12, 27)), 'zondag 27 december');
    });

    test('wanneerTekst combineert dag en dagdeel met de uren', () {
      expect(
        wanneerTekst(DateTime(2026, 9, 16), HhDagdeel.ochtend, nu),
        'morgen in de ochtend (van 9 tot 12 uur)',
      );
      expect(
        wanneerTekst(DateTime(2026, 9, 18), HhDagdeel.avond, nu),
        'vrijdag 18 september in de avond (van 18 tot 20 uur)',
      );
    });
  });
}

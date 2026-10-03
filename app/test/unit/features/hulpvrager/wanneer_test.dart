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

  group('momentOp', () {
    test('dag plus minuten na middernacht, lokale tijd', () {
      expect(
        momentOp(DateTime(2026, 9, 16), 14 * 60 + 15),
        DateTime(2026, 9, 16, 14, 15),
      );
    });

    test('een dag met tijd erin wordt eerst op middernacht gezet', () {
      expect(
        momentOp(DateTime(2026, 9, 16, 15, 45), 18 * 60),
        DateTime(2026, 9, 16, 18),
      );
    });
  });

  group('isVoorbij', () {
    test('vandaag om 11:00 is om half elf nog niet voorbij', () {
      expect(isVoorbij(DateTime(2026, 9, 15), 11 * 60, nu), isFalse);
    });

    test('vandaag om 10:30 is om half elf voorbij', () {
      expect(isVoorbij(DateTime(2026, 9, 15), 10 * 60 + 30, nu), isTrue);
    });

    test('gisteren is altijd voorbij, morgen nooit', () {
      expect(isVoorbij(DateTime(2026, 9, 14), 23 * 60, nu), isTrue);
      expect(isVoorbij(DateTime(2026, 9, 16), 7 * 60, nu), isFalse);
    });
  });

  group('standaardVanaf', () {
    test('vandaag: twee hele uren na nu', () {
      expect(standaardVanaf(DateTime(2026, 9, 15), nu), 12 * 60);
    });

    test('vandaag laat op de avond: niet over middernacht heen', () {
      expect(
        standaardVanaf(DateTime(2026, 9, 15), DateTime(2026, 9, 15, 23, 10)),
        laatsteVanafMinuten,
      );
    });

    test('een andere dag: 10:00', () {
      expect(standaardVanaf(DateTime(2026, 9, 16), nu), 10 * 60);
    });
  });

  test('tijdTekst schrijft 24-uursklok met twee cijfers', () {
    expect(tijdTekst(14 * 60), '14:00');
    expect(tijdTekst(9 * 60 + 5), '09:05');
    expect(tijdTekst(23 * 60 + 45), '23:45');
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

    test('wanneerTekst: dag met begintijd, en een eindtijd als die er is', () {
      expect(
        wanneerTekst(DateTime(2026, 9, 16), 14 * 60, null, nu),
        'morgen vanaf 14:00',
      );
      expect(
        wanneerTekst(DateTime(2026, 9, 18), 9 * 60, 11 * 60 + 30, nu),
        'vrijdag 18 september van 09:00 tot 11:30',
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/klussen/domein/wanneer_tekst.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';

void main() {
  final nu = DateTime(2026, 9, 15, 10); // dinsdag

  group('wanneerTekst', () {
    test('vandaag en morgen met tijden', () {
      expect(
        wanneerTekst(
          DateTime(2026, 9, 15, 14),
          DateTime(2026, 9, 15, 15, 30),
          nu,
        ),
        'vandaag van 14:00 tot 15:30',
      );
      expect(
        wanneerTekst(DateTime(2026, 9, 16, 9), DateTime(2026, 9, 16, 10), nu),
        'morgen van 09:00 tot 10:00',
      );
    });

    test('verder weg: weekdag, dag en maand zonder jaar', () {
      expect(
        wanneerTekst(
          DateTime(2026, 9, 17, 18, 30),
          DateTime(2026, 9, 17, 20),
          nu,
        ),
        'donderdag 17 september van 18:30 tot 20:00',
      );
    });

    test('zonder eindtijd, of een eindtijd voor de begintijd: "om"', () {
      expect(
        wanneerTekst(DateTime(2026, 9, 15, 14), null, nu),
        'vandaag om 14:00',
      );
      expect(
        wanneerTekst(DateTime(2026, 9, 15, 14), DateTime(2026, 9, 15, 13), nu),
        'vandaag om 14:00',
      );
    });

    test('zonder begintijd leeg', () {
      expect(wanneerTekst(null, DateTime(2026, 9, 15, 14), nu), '');
    });

    test('UTC-momenten worden in lokale tijd getoond', () {
      final van = DateTime(2026, 9, 15, 14).toUtc();
      final tot = DateTime(2026, 9, 15, 15).toUtc();
      expect(wanneerTekst(van, tot, nu), 'vandaag van 14:00 tot 15:00');
    });

    test('morgen loopt door over een maandgrens', () {
      final oud = DateTime(2026, 9, 30, 10);
      expect(
        wanneerTekst(DateTime(2026, 10, 1, 9), null, oud),
        'morgen om 09:00',
      );
    });
  });

  test('metHoofdletter', () {
    expect(metHoofdletter('boodschappen'), 'Boodschappen');
    expect(metHoofdletter(''), '');
    expect(metHoofdletter('Tuin'), 'Tuin');
  });

  test('euroTekst', () {
    expect(euroTekst(1000), '€ 10,00');
    expect(euroTekst(1250), '€ 12,50');
    expect(euroTekst(5), '€ 0,05');
    expect(euroTekst(0), '€ 0,00');
  });

  test('vergoedingVoorHelper: 0 = "Vergoeding volgt", anders het bedrag', () {
    expect(vergoedingVoorHelper(0), TekstenKlussenNl.vergoedingVolgt);
    expect(vergoedingVoorHelper(-5), TekstenKlussenNl.vergoedingVolgt);
    expect(vergoedingVoorHelper(1000), TekstenKlussenNl.vergoeding('€ 10,00'));
  });
}

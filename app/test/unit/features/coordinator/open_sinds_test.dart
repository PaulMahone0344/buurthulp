import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/coordinator/domein/open_sinds.dart';

void main() {
  final nu = DateTime(2026, 9, 15, 10);

  test('onder een minuut: zojuist geplaatst', () {
    expect(
      openSindsTekst(nu.subtract(const Duration(seconds: 30)), nu),
      'zojuist geplaatst',
    );
  });

  test('minuten, met enkelvoud', () {
    expect(
      openSindsTekst(nu.subtract(const Duration(minutes: 1)), nu),
      '1 minuut',
    );
    expect(
      openSindsTekst(nu.subtract(const Duration(minutes: 45)), nu),
      '45 minuten',
    );
  });

  test('uren, met enkelvoud', () {
    expect(openSindsTekst(nu.subtract(const Duration(hours: 1)), nu), '1 uur');
    expect(openSindsTekst(nu.subtract(const Duration(hours: 5)), nu), '5 uur');
  });

  test('dagen, met enkelvoud', () {
    expect(openSindsTekst(nu.subtract(const Duration(days: 1)), nu), '1 dag');
    expect(
      openSindsTekst(nu.subtract(const Duration(days: 12)), nu),
      '12 dagen',
    );
  });

  test('een tijd in de toekomst geeft zojuist geplaatst', () {
    expect(
      openSindsTekst(nu.add(const Duration(hours: 2)), nu),
      'zojuist geplaatst',
    );
  });

  test('UTC en lokale tijd geven hetzelfde aantal dagen', () {
    // De server bewaart UTC, de app rekent lokaal; het verschil mag het
    // aantal dagen niet verschuiven.
    final aangemaaktUtc = DateTime.utc(2026, 9, 12, 8);
    final nuLokaal = aangemaaktUtc.toLocal().add(const Duration(days: 3));

    expect(openSindsTekst(aangemaaktUtc, nuLokaal), '3 dagen');
  });
}

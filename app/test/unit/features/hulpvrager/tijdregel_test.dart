import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/tijdregel.dart';

/// Dezelfde grenzen als backend/pb_hooks/hh_klusplaatsen_hulp.js
/// (isAlleen18Plus). De server beslist; de app waarschuwt alleen vooraf.
void main() {
  int uur(int u, [int m = 0]) => u * 60 + m;

  test('binnen 07:00-19:00 en hooguit 2 uur: voor iedereen', () {
    expect(isAlleenVoor18Plus(vanaf: uur(14), tot: uur(16)), isFalse);
    expect(isAlleenVoor18Plus(vanaf: uur(7), tot: uur(9)), isFalse);
    expect(isAlleenVoor18Plus(vanaf: uur(17), tot: uur(19)), isFalse);
    expect(isAlleenVoor18Plus(vanaf: uur(17)), isFalse);
  });

  test('te vroeg, te laat, te lang of laat zonder eindtijd: alleen 18+', () {
    expect(isAlleenVoor18Plus(vanaf: uur(6, 45), tot: uur(8)), isTrue);
    expect(isAlleenVoor18Plus(vanaf: uur(18), tot: uur(19, 15)), isTrue);
    expect(isAlleenVoor18Plus(vanaf: uur(20)), isTrue);
    expect(isAlleenVoor18Plus(vanaf: uur(17, 15)), isTrue);
    expect(isAlleenVoor18Plus(vanaf: uur(14), tot: uur(16, 15)), isTrue);
  });

  test('een eindtijd vóór het begin telt als geen eindtijd', () {
    expect(isAlleenVoor18Plus(vanaf: uur(14), tot: uur(13)), isFalse);
    expect(isAlleenVoor18Plus(vanaf: uur(18), tot: uur(17)), isTrue);
  });

  // Antwoord Ibrahim 4 okt: 10 t/m 14 jaar om 18:00 klaar (tijdMinLeeftijd).
  test(
    '10 t/m 14: na 18:00 klaar of zonder eindtijd na 16:00 is pas vanaf 15',
    () {
      expect(tijdMinLeeftijd(vanaf: uur(16), tot: uur(18)), 0);
      expect(tijdMinLeeftijd(vanaf: uur(16, 30), tot: uur(18, 15)), 15);
      expect(tijdMinLeeftijd(vanaf: uur(17), tot: uur(19)), 15);
      expect(tijdMinLeeftijd(vanaf: uur(16)), 0);
      expect(tijdMinLeeftijd(vanaf: uur(16, 15)), 15);
      expect(tijdMinLeeftijd(vanaf: uur(17, 15)), 18);
      expect(tijdMinLeeftijd(vanaf: uur(18), tot: uur(19, 15)), 18);
      expect(tijdMinLeeftijd(vanaf: uur(10), tot: uur(11)), 0);
    },
  );
}

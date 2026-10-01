import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/domein/sterren.dart';
import 'package:heitjehulp_app/l10n/teksten_beoordelen_nl.dart';

void main() {
  group('gemiddelde voor de weergave (spiegelt de hook, rekent niet zelf)', () {
    test('een decimaal, .5 naar boven zoals Math.round in de hook', () {
      expect(gemiddeldVoorWeergave(4.25), 4.3);
      expect(gemiddeldVoorWeergave(4.349), 4.3);
      // 4,35 x 10 is in drijvende komma precies 43,5; ook in JS wordt dat 4,4.
      expect(gemiddeldVoorWeergave(4.35), 4.4);
      expect(gemiddeldVoorWeergave(4.36), 4.4);
      expect(gemiddeldVoorWeergave(13 / 3), 4.3);
      expect(gemiddeldVoorWeergave(11 / 3), 3.7);
    });

    test('een waarde die al op een decimaal staat blijft gelijk', () {
      for (final w in [0.0, 1.0, 2.5, 4.3, 5.0]) {
        expect(gemiddeldVoorWeergave(w), w);
      }
    });

    test('buiten 0-5 wordt begrensd', () {
      expect(gemiddeldVoorWeergave(-1), 0);
      expect(gemiddeldVoorWeergave(7), 5);
      expect(gemiddeldVoorWeergave(double.nan), 0);
    });

    test('met een komma, altijd een decimaal', () {
      expect(sterrenTekst(4.25), '4,3');
      expect(sterrenTekst(5), '5,0');
      expect(sterrenTekst(3.7), '3,7');
    });
  });

  group('duim als opstapje (O9)', () {
    test('omhoog vult 5 sterren voor, omlaag 2', () {
      expect(sterrenVoorDuim(Duim.omhoog), 5);
      expect(sterrenVoorDuim(Duim.omlaag), 2);
    });
  });

  group('invoer', () {
    test('sterren moeten 1 tot en met 5 zijn', () {
      expect(isGeldigAantalSterren(null), isFalse);
      expect(isGeldigAantalSterren(0), isFalse);
      for (var s = 1; s <= 5; s++) {
        expect(isGeldigAantalSterren(s), isTrue);
      }
      expect(isGeldigAantalSterren(6), isFalse);
    });

    test('tekst mag leeg, en hooguit 500 tekens', () {
      expect(isGeldigeBeoordelingTekst(''), isTrue);
      expect(isGeldigeBeoordelingTekst('a' * 500), isTrue);
      expect(isGeldigeBeoordelingTekst('a' * 501), isFalse);
      // Spaties rond de tekst tellen niet mee; die gaan er toch af.
      expect(isGeldigeBeoordelingTekst('  ${'a' * 500}  '), isTrue);
    });

    test('elk aantal sterren heeft een woord, zonder cijfer', () {
      final woorden = {for (var s = 1; s <= 5; s++) sterrenWoord(s)};
      expect(woorden, hasLength(5));
      for (final woord in woorden) {
        expect(woord, isNot(matches(RegExp(r'\d'))));
      }
      expect(sterrenWoord(5), TekstenBeoordelenNl.woordHeelGoed);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/l10n/teksten_klus_nl.dart';

void main() {
  group('omschrijvingTitelVoor (feedbackronde 1)', () {
    test('de voorbeelden van de collega', () {
      expect(
        TekstenKlusNl.omschrijvingTitelVoor('Tuin'),
        'Vertel meer over het tuinwerk',
      );
      expect(
        TekstenKlusNl.omschrijvingTitelVoor('Schoonmaak'),
        'Vertel meer over de schoonmaak',
      );
      expect(
        TekstenKlusNl.omschrijvingTitelVoor('Boodschappen'),
        'Vertel meer over de boodschappen',
      );
      expect(
        TekstenKlusNl.omschrijvingTitelVoor('Overig'),
        'Vertel wat je wilt',
      );
    });

    test('niets gekozen of een onbekende categorie: de gewone kop', () {
      expect(
        TekstenKlusNl.omschrijvingTitelVoor(null),
        TekstenKlusNl.omschrijvingTitel,
      );
      expect(
        TekstenKlusNl.omschrijvingTitelVoor('vervoer'),
        TekstenKlusNl.omschrijvingTitel,
      );
    });
  });
}

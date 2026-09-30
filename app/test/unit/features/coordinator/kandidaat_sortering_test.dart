import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/coordinator/domein/kandidaat_sortering.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_kandidaat.dart';

import '../../../support/hh_coordinator_wikkel.dart';

void main() {
  group('sorteren', () {
    test('zet de jongeren uit dezelfde wijk vooraan, daarna op naam', () {
      final lijst = sorteerKandidaten(testKandidaten(), wijkWestId);

      // Sanne en Yusuf wonen in Tiel-West (op naam), Daan in Passewaaij.
      expect(
        [for (final k in lijst) k.naam],
        ['Sanne Bakker', 'Yusuf el Amrani', 'Daan Verhoeven'],
      );
    });

    test('andere wijk vooraan als de klus in die wijk ligt', () {
      final lijst = sorteerKandidaten(testKandidaten(), wijkPassewaaijId);

      expect(lijst.first.naam, 'Daan Verhoeven');
    });

    test('zonder wijk op de klus telt alleen de naam', () {
      final lijst = sorteerKandidaten(testKandidaten(), '');

      expect(
        [for (final k in lijst) k.naam],
        ['Daan Verhoeven', 'Sanne Bakker', 'Yusuf el Amrani'],
      );
    });

    test('sorteert hoofdletterongevoelig', () {
      final lijst = sorteerKandidaten(const [
        HhKandidaat(id: 'b', naam: 'bakker'),
        HhKandidaat(id: 'a', naam: 'Amrani'),
      ], '');

      expect([for (final k in lijst) k.id], ['a', 'b']);
    });

    test('laat de meegegeven lijst ongemoeid', () {
      final origineel = testKandidaten();
      sorteerKandidaten(origineel, wijkPassewaaijId);

      expect(origineel.first.naam, 'Yusuf el Amrani');
    });
  });

  group('zoeken', () {
    test('vindt op een deel van de naam, hoofdletterongevoelig', () {
      final lijst = zoekKandidaten(testKandidaten(), 'BAK');

      expect([for (final k in lijst) k.naam], ['Sanne Bakker']);
    });

    test('negeert spaties om het zoekwoord', () {
      expect(zoekKandidaten(testKandidaten(), '  daan  '), hasLength(1));
    });

    test('een leeg zoekwoord laat alles staan', () {
      expect(zoekKandidaten(testKandidaten(), '   '), hasLength(3));
    });

    test('geeft een lege lijst als niets past', () {
      expect(zoekKandidaten(testKandidaten(), 'zzz'), isEmpty);
    });
  });

  test('kandidatenVoorKlus zoekt en sorteert in één stap', () {
    final lijst = kandidatenVoorKlus(testKandidaten(), wijkWestId, 'e');

    // Alle drie de namen bevatten een "e"; eigen wijk eerst, dan op naam.
    expect(
      [for (final k in lijst) k.naam],
      ['Sanne Bakker', 'Yusuf el Amrani', 'Daan Verhoeven'],
    );
  });
}

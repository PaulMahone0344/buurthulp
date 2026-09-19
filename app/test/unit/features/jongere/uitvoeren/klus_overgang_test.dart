import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/domein/klus_overgang.dart';
import 'package:heitjehulp_app/theme.dart';

/// De overgangstabel in de app is een spiegel van die in de hook; hij dient
/// alleen om de goede knop te tonen. Deze tests leggen vast dat hij precies
/// hetzelfde zegt: één stap vooruit, nooit terug, nooit overslaan.
void main() {
  group('volgendeStap', () {
    test('de reeks loopt geaccepteerd -> onderweg -> bezig -> afgerond', () {
      expect(volgendeStap(HhKlusStatus.geaccepteerd), HhKlusStatus.onderweg);
      expect(volgendeStap(HhKlusStatus.onderweg), HhKlusStatus.bezig);
      expect(volgendeStap(HhKlusStatus.bezig), HhKlusStatus.afgerond);
    });

    test('een eindstatus heeft geen volgende stap', () {
      for (final status in [
        HhKlusStatus.concept,
        HhKlusStatus.open,
        HhKlusStatus.afgerond,
        HhKlusStatus.geannuleerd,
        HhKlusStatus.probleem,
      ]) {
        expect(volgendeStap(status), isNull, reason: status.name);
      }
    });

    test('geen enkele stap springt over een status heen', () {
      // De waarde van de tabel is altijd de status die er in de reeks
      // direct op volgt.
      const reeks = [
        HhKlusStatus.geaccepteerd,
        HhKlusStatus.onderweg,
        HhKlusStatus.bezig,
        HhKlusStatus.afgerond,
      ];
      for (var i = 0; i < reeks.length - 1; i++) {
        expect(volgendeStap(reeks[i]), reeks[i + 1]);
      }
    });

    test('isInUitvoering geldt alleen waar nog een stap te zetten is', () {
      expect(isInUitvoering(HhKlusStatus.geaccepteerd), isTrue);
      expect(isInUitvoering(HhKlusStatus.onderweg), isTrue);
      expect(isInUitvoering(HhKlusStatus.bezig), isTrue);
      expect(isInUitvoering(HhKlusStatus.afgerond), isFalse);
      expect(isInUitvoering(HhKlusStatus.open), isFalse);
    });
  });

  group('gezetteStappen', () {
    test('telt de drie stappen na het aannemen', () {
      expect(gezetteStappen(HhKlusStatus.geaccepteerd), 0);
      expect(gezetteStappen(HhKlusStatus.onderweg), 1);
      expect(gezetteStappen(HhKlusStatus.bezig), 2);
      expect(gezetteStappen(HhKlusStatus.afgerond), 3);
    });

    test('een klus die niet in uitvoering is telt nul', () {
      expect(gezetteStappen(HhKlusStatus.open), 0);
      expect(gezetteStappen(HhKlusStatus.geannuleerd), 0);
    });

    test('uitvoerStappen zijn precies de drie knoppen van J15', () {
      expect(uitvoerStappen, [
        HhKlusStatus.onderweg,
        HhKlusStatus.bezig,
        HhKlusStatus.afgerond,
      ]);
    });
  });

  group('annuleren', () {
    test('de oudere mag bij open, geaccepteerd en onderweg', () {
      expect(magOudereAnnuleren(HhKlusStatus.open), isTrue);
      expect(magOudereAnnuleren(HhKlusStatus.geaccepteerd), isTrue);
      expect(magOudereAnnuleren(HhKlusStatus.onderweg), isTrue);
    });

    test('de jongere mag alleen bij geaccepteerd en onderweg', () {
      expect(magJongereAnnuleren(HhKlusStatus.open), isFalse);
      expect(magJongereAnnuleren(HhKlusStatus.geaccepteerd), isTrue);
      expect(magJongereAnnuleren(HhKlusStatus.onderweg), isTrue);
    });

    test('bij bezig annuleert niemand (dat wordt probleem melden, M8)', () {
      expect(magOudereAnnuleren(HhKlusStatus.bezig), isFalse);
      expect(magJongereAnnuleren(HhKlusStatus.bezig), isFalse);
    });

    test('na afloop annuleert niemand meer', () {
      for (final status in [
        HhKlusStatus.afgerond,
        HhKlusStatus.geannuleerd,
        HhKlusStatus.probleem,
        HhKlusStatus.concept,
      ]) {
        expect(magOudereAnnuleren(status), isFalse, reason: status.name);
        expect(magJongereAnnuleren(status), isFalse, reason: status.name);
      }
    });
  });

  group('magBellenBij', () {
    test('bellen kan zodra de klus is aangenomen en zolang hij loopt', () {
      expect(magBellenBij(HhKlusStatus.geaccepteerd), isTrue);
      expect(magBellenBij(HhKlusStatus.onderweg), isTrue);
      expect(magBellenBij(HhKlusStatus.bezig), isTrue);
    });

    test('bij open of na afloop niet', () {
      for (final status in [
        HhKlusStatus.concept,
        HhKlusStatus.open,
        HhKlusStatus.afgerond,
        HhKlusStatus.geannuleerd,
        HhKlusStatus.probleem,
      ]) {
        expect(magBellenBij(status), isFalse, reason: status.name);
      }
    });
  });

  group('isGeldigeReden', () {
    test('minder dan vijf tekens mag niet', () {
      expect(isGeldigeReden(''), isFalse);
      expect(isGeldigeReden('kort'), isFalse);
      expect(isGeldigeReden('    '), isFalse);
    });

    test('vijf tekens mag precies', () {
      expect(isGeldigeReden('ziek!'), isTrue);
    });

    test('spaties eromheen tellen niet mee', () {
      expect(isGeldigeReden('  ziek  '), isFalse);
      expect(isGeldigeReden('  ziek!  '), isTrue);
    });

    test('driehonderd tekens mag, eenendertighonderd-en-een niet', () {
      expect(isGeldigeReden('x' * redenMaxLengte), isTrue);
      expect(isGeldigeReden('x' * (redenMaxLengte + 1)), isFalse);
    });

    test('de grenzen zijn gelijk aan die van de hook', () {
      expect(redenMinLengte, 5);
      expect(redenMaxLengte, 300);
    });
  });
}

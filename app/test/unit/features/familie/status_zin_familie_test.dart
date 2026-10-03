import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/familie/domein/status_zin_familie.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_uitvoeren_wikkel.dart';

void main() {
  group('statusZinVoorFamilie', () {
    test('noemt de oudere bij elke status met jongere', () {
      final zinnen = {
        for (final s in [
          HhKlusStatus.geaccepteerd,
          HhKlusStatus.onderweg,
          HhKlusStatus.bezig,
          HhKlusStatus.afgerond,
        ])
          s: statusZinVoorFamilie(uitvoerKlus(status: s)),
      };
      expect(
        zinnen[HhKlusStatus.geaccepteerd],
        'Sanne komt Mevrouw de Vries helpen.',
      );
      expect(
        zinnen[HhKlusStatus.onderweg],
        'Sanne is onderweg naar Mevrouw de Vries.',
      );
      expect(
        zinnen[HhKlusStatus.bezig],
        'Sanne is bij Mevrouw de Vries aan het werk.',
      );
      expect(zinnen[HhKlusStatus.afgerond], 'Sanne heeft de klus gedaan.');
    });

    test('zonder jongere: we zoeken iemand voor de oudere', () {
      final klus = uitvoerKlus(status: HhKlusStatus.open, metJongere: false);
      expect(
        statusZinVoorFamilie(klus),
        'We zoeken iemand voor Mevrouw de Vries.',
      );
    });

    test('geen enkele zin zegt "u" alsof het familielid geholpen wordt', () {
      for (final s in HhKlusStatus.values) {
        for (final metJongere in [true, false]) {
          final zin = statusZinVoorFamilie(
            uitvoerKlus(status: s, metJongere: metJongere),
          );
          expect(
            RegExp(r'\bu\b', caseSensitive: false).hasMatch(zin),
            isFalse,
            reason: '$s: $zin',
          );
        }
      }
    });

    test('zonder naam van de bewoner: "je familielid"', () {
      final klus = uitvoerKlus(
        status: HhKlusStatus.onderweg,
      ).copyWith(oudereNaam: '');
      expect(
        statusZinVoorFamilie(klus),
        'Sanne is onderweg naar je familielid.',
      );
    });
  });
}

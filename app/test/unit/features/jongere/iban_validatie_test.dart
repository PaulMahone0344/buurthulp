import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/iban_validatie.dart';
import 'package:heitjehulp_app/l10n/teksten_jongere_nl.dart';

void main() {
  group('isGeldigNlIban', () {
    test('accepteert geldige NL-IBANs, ook met spaties en kleine letters', () {
      expect(isGeldigNlIban('NL91ABNA0417164300'), isTrue);
      expect(isGeldigNlIban('NL91 ABNA 0417 1643 00'), isTrue);
      expect(isGeldigNlIban('nl91abna0417164300'), isTrue);
      expect(isGeldigNlIban('NL02ABNA0123456789'), isTrue);
      expect(isGeldigNlIban('NL20INGB0001234567'), isTrue);
    });

    test('weigert een fout controlegetal (mod-97)', () {
      expect(isGeldigNlIban('NL92ABNA0417164300'), isFalse);
      expect(isGeldigNlIban('NL91ABNA0417164301'), isFalse);
    });

    test('weigert de verkeerde vorm of lengte', () {
      expect(isGeldigNlIban(''), isFalse);
      expect(isGeldigNlIban('NL91ABNA041716430'), isFalse);
      expect(isGeldigNlIban('NL91ABNA04171643001'), isFalse);
      expect(isGeldigNlIban('NL91AB1A0417164300'), isFalse);
      expect(isGeldigNlIban('DE89370400440532013000'), isFalse);
    });
  });

  group('valideerIban', () {
    test('leeg is verplicht, fout is ongeldig, goed is null', () {
      expect(valideerIban('  '), TekstenJongereNl.validatieIbanVerplicht);
      expect(
        valideerIban('NL00ABNA0000'),
        TekstenJongereNl.validatieIbanOngeldig,
      );
      expect(valideerIban('NL91 ABNA 0417 1643 00'), isNull);
    });
  });

  test('normaliseer en toon', () {
    expect(normaliseerIban(' nl91 abna 0417 1643 00 '), 'NL91ABNA0417164300');
    expect(toonIban('NL91ABNA0417164300'), 'NL91 ABNA 0417 1643 00');
    expect(toonIban(''), '');
  });
}

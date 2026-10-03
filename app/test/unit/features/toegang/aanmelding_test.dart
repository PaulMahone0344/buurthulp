import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/toegang/domein/aanmelding.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';

void main() {
  final vandaag = DateTime(2026, 10, 3);

  group('leeftijdOp', () {
    test('telt een verjaardag pas op de dag zelf', () {
      expect(leeftijdOp(DateTime.utc(2008, 10, 3), vandaag), 18);
      expect(leeftijdOp(DateTime.utc(2008, 10, 4), vandaag), 17);
      expect(leeftijdOp(DateTime.utc(2016, 10, 3), vandaag), 10);
    });
  });

  group('valideerGeboortedatumHelper', () {
    test('leeg, onzin en toekomst geven een melding', () {
      expect(
        valideerGeboortedatumHelper('', vandaag),
        TekstenAanmeldenNl.validatieGeboortedatumVerplicht,
      );
      expect(
        valideerGeboortedatumHelper('31-02-2012', vandaag),
        TekstenAanmeldenNl.validatieGeboortedatumOngeldig,
      );
      expect(
        valideerGeboortedatumHelper('01-01-2030', vandaag),
        TekstenAanmeldenNl.validatieGeboortedatumToekomst,
      );
    });

    test('onder de 10 is te jong, precies 10 mag', () {
      expect(
        valideerGeboortedatumHelper('04-10-2016', vandaag),
        TekstenAanmeldenNl.validatieTeJong,
      );
      expect(valideerGeboortedatumHelper('03-10-2016', vandaag), isNull);
      expect(valideerGeboortedatumHelper('14-05-1990', vandaag), isNull);
    });
  });

  group('isMinderjarig', () {
    test('onder 18 is minderjarig, 18 niet', () {
      expect(isMinderjarig(DateTime.utc(2008, 10, 4), vandaag), isTrue);
      expect(isMinderjarig(DateTime.utc(2008, 10, 3), vandaag), isFalse);
    });
  });

  group('valideerOuderEmail (B3: alleen e-mail, geen telefoon meer)', () {
    test('een e-mailadres is goed', () {
      expect(valideerOuderEmail(' ouder@voorbeeld.nl '), isNull);
    });

    test('leeg, een 06-nummer of onzin is fout', () {
      expect(
        valideerOuderEmail(''),
        TekstenAanmeldenNl.validatieOuderVerplicht,
      );
      for (final fout in ['06 12 34 56 78', 'mama', 'mama@']) {
        expect(
          valideerOuderEmail(fout),
          TekstenAanmeldenNl.validatieOuderOngeldig,
          reason: fout,
        );
      }
    });

    test('niet je eigen adres', () {
      expect(
        valideerOuderEmail(
          'Daan@voorbeeld.nl',
          eigenEmail: 'daan@voorbeeld.nl ',
        ),
        TekstenAanmeldenNl.validatieOuderEigen,
      );
    });
  });

  group('adresvelden', () {
    test('postcode: 4 cijfers en 2 letters, netjes gemaakt', () {
      expect(
        valideerPostcode(''),
        TekstenAanmeldenNl.validatiePostcodeVerplicht,
      );
      expect(
        valideerPostcode('4003'),
        TekstenAanmeldenNl.validatiePostcodeOngeldig,
      );
      expect(
        valideerPostcode('0123 AB'),
        TekstenAanmeldenNl.validatiePostcodeOngeldig,
      );
      expect(valideerPostcode('4003ab'), isNull);
      expect(normaliseerPostcode(' 4003ab '), '4003 AB');
    });

    test('huisnummer begint met een cijfer', () {
      expect(
        valideerHuisnummer(''),
        TekstenAanmeldenNl.validatieHuisnummerVerplicht,
      );
      expect(
        valideerHuisnummer('a12'),
        TekstenAanmeldenNl.validatieHuisnummerOngeldig,
      );
      expect(valideerHuisnummer('12'), isNull);
      expect(valideerHuisnummer('12a'), isNull);
      expect(valideerHuisnummer('12-2'), isNull);
    });

    test('straat en plaats zijn verplicht', () {
      expect(valideerStraat(' '), TekstenAanmeldenNl.validatieStraatVerplicht);
      expect(valideerPlaats(''), TekstenAanmeldenNl.validatiePlaatsVerplicht);
      expect(valideerStraat('Dorpsstraat'), isNull);
    });
  });

  group('HhAanmelding.velden', () {
    test('bewoner: adres = straat + huisnummer, geen telefoon', () {
      const aanmelding = BewonerAanmelding(
        naam: 'Ans',
        email: 'ans@voorbeeld.nl',
        wachtwoord: 'geheim123',
        straat: ' Dorpsstraat ',
        huisnummer: '12a',
        postcode: '4003ab',
        plaats: 'Tiel',
      );
      expect(aanmelding.rol, HhRol.hulpvrager);
      expect(aanmelding.velden, {
        'adres': 'Dorpsstraat 12a',
        'huisnummer': '12a',
        'postcode': '4003 AB',
        'plaats': 'Tiel',
      });
    });

    test('helper onder 18: geboortedatum, postcode, huisnummer en ouder', () {
      final aanmelding = HelperAanmelding(
        voornaam: 'Daan',
        email: 'daan@voorbeeld.nl',
        wachtwoord: 'geheim123',
        geboortedatum: DateTime.utc(2012, 5, 14),
        postcode: '4003 ab',
        huisnummer: '7',
        ouderEmail: ' Mama@Voorbeeld.nl ',
      );
      expect(aanmelding.rol, HhRol.jongere);
      expect(aanmelding.naam, 'Daan');
      expect(aanmelding.velden, {
        'geboortedatum': '2012-05-14T00:00:00.000Z',
        'postcode': '4003 AB',
        'huisnummer': '7',
        'ouder_email': 'mama@voorbeeld.nl',
      });
    });

    test('helper 18+: geen ouder', () {
      final aanmelding = HelperAanmelding(
        voornaam: 'Sara',
        email: 'sara@voorbeeld.nl',
        wachtwoord: 'geheim123',
        geboortedatum: DateTime.utc(1999, 1, 2),
        postcode: '4007AA',
        huisnummer: '1',
      );
      expect(aanmelding.velden.containsKey('ouder_email'), isFalse);
      expect(aanmelding.velden.containsKey('ouder_telefoon'), isFalse);
    });
  });
}

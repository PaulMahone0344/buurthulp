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

  group('herkenOuderContact', () {
    test('herkent een e-mailadres', () {
      expect(
        herkenOuderContact(' ouder@voorbeeld.nl '),
        const OuderEmail('ouder@voorbeeld.nl'),
      );
    });

    test('herkent een 06-nummer, ook met spaties, streepjes of +31', () {
      expect(
        herkenOuderContact('06-12 34 56 78'),
        const OuderTelefoon('0612345678'),
      );
      expect(
        herkenOuderContact('+31 6 12345678'),
        const OuderTelefoon('0612345678'),
      );
      expect(
        herkenOuderContact('0031612345678'),
        const OuderTelefoon('0612345678'),
      );
    });

    test('vast nummer, te kort of onzin is niets', () {
      expect(herkenOuderContact('0344123456'), isNull);
      expect(herkenOuderContact('061234567'), isNull);
      expect(herkenOuderContact('mama'), isNull);
      expect(herkenOuderContact(''), isNull);
    });

    test('velden: e-mail naar ouder_email, nummer naar ouder_telefoon', () {
      expect(const OuderEmail('a@b.nl').velden, {'ouder_email': 'a@b.nl'});
      expect(const OuderTelefoon('0612345678').velden, {
        'ouder_telefoon': '0612345678',
      });
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
        ouder: const OuderTelefoon('0612345678'),
      );
      expect(aanmelding.rol, HhRol.jongere);
      expect(aanmelding.naam, 'Daan');
      expect(aanmelding.velden, {
        'geboortedatum': '2012-05-14T00:00:00.000Z',
        'postcode': '4003 AB',
        'huisnummer': '7',
        'ouder_telefoon': '0612345678',
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

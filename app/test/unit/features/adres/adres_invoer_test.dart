import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/adres/domein/adres_invoer.dart';
import 'package:heitjehulp_app/features/adres/model/hh_adres.dart';

TextEditingValue _typ(String tekst) => const PostcodeFormatter()
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: tekst));

void main() {
  group('PostcodeFormatter: hoofdletters en een spatie na de cijfers', () {
    test('4001ma -> 4001 MA', () => expect(_typ('4001ma').text, '4001 MA'));
    test('4001 m -> 4001 M', () => expect(_typ('4001 m').text, '4001 M'));
    test('alleen cijfers blijven zonder spatie', () {
      expect(_typ('400').text, '400');
      expect(_typ('4001').text, '4001');
    });
    test('letters vóór de 4 cijfers en tekens vallen weg', () {
      expect(_typ('40a01MA').text, '4001 MA');
      expect(_typ('4001-ma').text, '4001 MA');
    });
    test('max 4 cijfers + 2 letters', () {
      expect(_typ('40011MAB').text, '4001 MA');
    });
    test('cursor aan het eind', () {
      expect(_typ('4001ma').selection.baseOffset, 7);
    });
  });

  group('invoer', () {
    test('isVolledigePostcode', () {
      expect(isVolledigePostcode('4001 MA'), isTrue);
      expect(isVolledigePostcode('4001ma'), isTrue);
      expect(isVolledigePostcode('0401 MA'), isFalse);
      expect(isVolledigePostcode('4001'), isFalse);
    });
    test('normaliseerPostcode', () {
      expect(normaliseerPostcode('4001ma'), '4001 MA');
      expect(normaliseerPostcode('4001'), '4001');
    });
    test('isGeldigHuisnummer: alleen cijfers, niet 0', () {
      expect(isGeldigHuisnummer('1'), isTrue);
      expect(isGeldigHuisnummer('12345'), isTrue);
      expect(isGeldigHuisnummer('0'), isFalse);
      expect(isGeldigHuisnummer('12a'), isFalse);
      expect(isGeldigHuisnummer(''), isFalse);
    });
    test('isGeldigeToevoeging: leeg mag, max 6 letters/cijfers', () {
      expect(isGeldigeToevoeging(''), isTrue);
      expect(isGeldigeToevoeging('A'), isTrue);
      expect(isGeldigeToevoeging('a-01'), isTrue);
      expect(isGeldigeToevoeging('abcdefg'), isFalse);
      expect(isGeldigeToevoeging('a/b'), isFalse);
    });
    test('kanZoeken: postcode + huisnummer geldig', () {
      expect(kanZoeken('4001 MA', '1', ''), isTrue);
      expect(kanZoeken('4001', '1', ''), isFalse);
      expect(kanZoeken('4001 MA', '', ''), isFalse);
      expect(kanZoeken('4001 MA', '1', 'abcdefgh'), isFalse);
    });
    test('heeftVolledigAdres: 6-tekens-postcode en een huisnummer', () {
      expect(heeftVolledigAdres('4001 MA', '1'), isTrue);
      expect(heeftVolledigAdres('4001', '1'), isFalse);
      expect(heeftVolledigAdres('4001 MA', ''), isFalse);
    });
  });

  group('AdresKeuze: wat het formulier naar de server stuurt', () {
    const kerkstraat = HhAdres(
      straat: 'Kerkstraat',
      huisnummer: '1',
      postcode: '4001 MA',
      plaats: 'Tiel',
      adres: 'Kerkstraat 1',
      weergave: 'Kerkstraat 1, 4001 MA Tiel',
      lat: 51.88,
      lon: 5.43,
      binnenWerkgebied: true,
    );
    test(
      'bevestigd: postcode, nummer, toevoeging en straat/plaats van PDOK',
      () {
        const keuze = AdresKeuze.bevestigd(kerkstraat);
        expect(keuze.isBevestigd, isTrue);
        expect(keuze.velden, {
          'postcode': '4001 MA',
          'huisnummer': '1',
          'toevoeging': '',
          'adres': 'Kerkstraat 1',
          'plaats': 'Tiel',
        });
      },
    );
    test('ongecontroleerd (PDOK weg): alleen wat er getypt is', () {
      const keuze = AdresKeuze.ongecontroleerd(
        postcode: '4001ma',
        huisnummer: '1',
        toevoeging: 'b',
      );
      expect(keuze.isBevestigd, isFalse);
      expect(keuze.velden, {
        'postcode': '4001 MA',
        'huisnummer': '1',
        'toevoeging': 'b',
      });
    });
  });

  test('HhAdres.vanJson leest het antwoord van /api/hh/adres', () {
    final a = HhAdres.vanJson({
      'straat': 'Nieuwe Tielseweg',
      'huisnummer': '1',
      'toevoeging': 'a-01',
      'postcode': '4001 JS',
      'plaats': 'Tiel',
      'gemeente': 'Tiel',
      'lat': 51.8837,
      'lon': 5.436,
      'adres': 'Nieuwe Tielseweg 1a-01',
      'weergave': 'Nieuwe Tielseweg 1a-01, 4001 JS Tiel',
      'binnen_werkgebied': true,
    });
    expect(a.toevoeging, 'a-01');
    expect(a.weergave, 'Nieuwe Tielseweg 1a-01, 4001 JS Tiel');
    expect(a.binnenWerkgebied, isTrue);
    expect(a.lat, 51.8837);
  });
}

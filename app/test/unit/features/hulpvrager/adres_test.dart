import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/adres.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/klustype_icoon.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_gegevens.dart';

void main() {
  group('stelAdresSamen', () {
    test('straat, postcode en plaats op een regel', () {
      expect(
        stelAdresSamen(
          adres: 'Prins Bernhardlaan 12',
          postcode: '4003 AB',
          plaats: 'Tiel',
        ),
        'Prins Bernhardlaan 12, 4003 AB Tiel',
      );
    });

    test('randspaties en dubbele spaties verdwijnen', () {
      expect(
        stelAdresSamen(
          adres: '  Kerkstraat   1 ',
          postcode: ' 4001AA',
          plaats: 'Tiel  ',
        ),
        'Kerkstraat 1, 4001AA Tiel',
      );
    });

    test('lege delen worden overgeslagen', () {
      expect(
        stelAdresSamen(adres: 'Kerkstraat 1', postcode: '', plaats: ''),
        'Kerkstraat 1',
      );
      expect(
        stelAdresSamen(adres: '', postcode: '4001 AA', plaats: 'Tiel'),
        '4001 AA Tiel',
      );
      expect(stelAdresSamen(adres: '', postcode: '', plaats: ''), '');
    });
  });

  group('HhGegevens.gewijzigdeVelden', () {
    const gegevens = HhGegevens(
      id: 'u1',
      naam: 'Mevrouw Jansen',
      telefoon: '0344-1',
      adres: 'Kerkstraat 1',
      postcode: '4001 AA',
      plaats: 'Tiel',
    );

    test('alleen wat afwijkt gaat mee, nooit het hele record', () {
      final velden = gegevens.gewijzigdeVelden({
        ...gegevens.alsVelden,
        HhGegevens.veldAdres: 'Kerkstraat 2',
        HhGegevens.veldContactNaam: 'Zoon',
      });

      expect(velden, {
        HhGegevens.veldAdres: 'Kerkstraat 2',
        HhGegevens.veldContactNaam: 'Zoon',
      });
      expect(velden.containsKey('rol'), isFalse);
    });

    test('niets gewijzigd geeft een lege map', () {
      expect(gegevens.gewijzigdeVelden(gegevens.alsVelden), isEmpty);
    });

    test('heeftAdres vraagt straat, postcode en plaats', () {
      expect(gegevens.heeftAdres, isTrue);
      expect(
        gegevens.metVelden({HhGegevens.veldPlaats: ''}).heeftAdres,
        isFalse,
      );
    });
  });

  group('KlustypeIcoon', () {
    test('bekende namen krijgen een eigen icoon', () {
      for (final naam in KlustypeIcoon.bekendeNamen) {
        expect(KlustypeIcoon.voor(naam), isNot(KlustypeIcoon.terugval));
      }
    });

    test('onbekend, leeg of met spaties valt netjes terug', () {
      expect(KlustypeIcoon.voor('bestaat_niet'), KlustypeIcoon.terugval);
      expect(KlustypeIcoon.voor(''), KlustypeIcoon.terugval);
      expect(
        KlustypeIcoon.voor(' shopping_cart '),
        KlustypeIcoon.voor('shopping_cart'),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/bedragen.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/duur.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_klustype.dart';

void main() {
  group('berekenBedragen', () {
    test('bruto en vergoeding zijn de richtvergoeding, commissie nul', () {
      const klustype = HhKlustype(
        id: 'kt',
        naam: 'boodschappen',
        richtvergoedingCenten: 1250,
      );

      final bedragen = berekenBedragen(klustype);

      expect(bedragen.bedragBruto, 1250);
      expect(bedragen.vergoedingJongere, 1250);
      expect(bedragen.commissie, 0);
    });

    test('klustype zonder richtvergoeding geeft drie keer nul', () {
      const klustype = HhKlustype(id: 'kt', naam: 'gratis');

      expect(
        berekenBedragen(klustype),
        const HhBedragen(bedragBruto: 0, vergoedingJongere: 0, commissie: 0),
      );
    });
  });

  group('euroTekst', () {
    test('centen worden "€ 12,50"', () {
      expect(euroTekst(1250), '€ 12,50');
    });

    test('hele euro krijgt twee nullen', () {
      expect(euroTekst(1000), '€ 10,00');
    });

    test('een enkele cent krijgt een voorloopnul', () {
      expect(euroTekst(705), '€ 7,05');
      expect(euroTekst(0), '€ 0,00');
    });
  });

  group('duurTekst', () {
    test('richtduur in gewone taal', () {
      expect(duurTekst(60), 'ongeveer 1 uur');
      expect(duurTekst(120), 'ongeveer 2 uur');
      expect(duurTekst(45), 'ongeveer 45 minuten');
      expect(duurTekst(15), 'ongeveer een kwartier');
      expect(duurTekst(30), 'ongeveer een half uur');
      expect(duurTekst(90), 'ongeveer anderhalf uur');
      expect(duurTekst(150), 'ongeveer 2 uur en 30 minuten');
    });

    test('nul of onbekend wordt afgesproken met de helper', () {
      expect(duurTekst(0), 'wordt afgesproken met de helper');
    });
  });
}

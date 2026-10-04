import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/klussen/domein/afstand.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../../support/hh_klussen_wikkel.dart';

void main() {
  group('afstandKm (haversine)', () {
    test('zelfde punt is 0', () {
      expect(
        afstandKm((lat: 51.8865, lon: 5.4126), (lat: 51.8865, lon: 5.4126)),
        0,
      );
    });

    test('Tiel-West naar Passewaaij is ongeveer 1,8 km', () {
      // Seed-coördinaten van de twee wijken (03-seed.mjs).
      final km = afstandKm(
        (lat: 51.8865, lon: 5.4126),
        (lat: 51.8712, lon: 5.4045),
      );
      expect(km, closeTo(1.79, 0.05));
    });

    test('Amsterdam naar Rotterdam is ongeveer 57 km', () {
      final km = afstandKm(
        (lat: 52.3676, lon: 4.9041),
        (lat: 51.9244, lon: 4.4777),
      );
      expect(km, closeTo(57.2, 0.5));
    });

    test('is symmetrisch', () {
      const a = (lat: 51.88, lon: 5.41);
      const b = (lat: 51.90, lon: 5.45);
      expect(afstandKm(a, b), closeTo(afstandKm(b, a), 1e-9));
    });
  });

  group('middelpunt', () {
    test('leeg of alleen klussen zonder coördinaten geeft null', () {
      expect(middelpunt(const []), isNull);
      expect(middelpunt([testKlus(id: 'a', afstandKm: null)]), isNull);
    });

    test('is het gemiddelde van de klussen met coördinaten', () {
      final punt = middelpunt([
        testKlus(id: 'a', afstandKm: 0),
        testKlus(id: 'b', afstandKm: 2),
        testKlus(id: 'c', afstandKm: null),
      ]);
      expect(punt, isNotNull);
      expect(punt!.lat, closeTo(wijkLat + 0.009, 1e-9));
      expect(punt.lon, closeTo(wijkLon, 1e-9));
    });
  });

  group('afstandVanKlus', () {
    test('null zonder middelpunt of zonder coördinaten', () {
      final klus = testKlus(id: 'a', afstandKm: 1);
      expect(afstandVanKlus(klus, null), isNull);
      expect(
        afstandVanKlus(testKlus(id: 'b', afstandKm: null), (
          lat: wijkLat,
          lon: wijkLon,
        )),
        isNull,
      );
    });

    test('meet ongeveer de verschuiving uit de testdata', () {
      final klus = testKlus(id: 'a', afstandKm: 1.2, status: HhKlusStatus.open);
      final km = afstandVanKlus(klus, (lat: wijkLat, lon: wijkLon));
      expect(km, closeTo(1.2, 0.05));
    });
  });

  group('afstandTekst', () {
    test('kilometers met komma en een decimaal', () {
      expect(afstandTekst(1.2), 'ca. 1,2 km');
      expect(afstandTekst(1.0), 'ca. 1,0 km');
      expect(afstandTekst(12.345), 'ca. 12,3 km');
    });

    test('onder de kilometer in meters, op 50 afgerond, minimaal 50', () {
      expect(afstandTekst(0.83), 'ca. 850 m');
      expect(afstandTekst(0.31), 'ca. 300 m');
      expect(afstandTekst(0.0), 'ca. 50 m');
    });
  });

  // ADRES (antwoord Ibrahim 3): vóór de match stuurt de server een vaag punt
  // en afstand_m (eigen punt van de helper tot het ECHTE punt, op 100 m).
  group('afstand van de server (vaag vóór de match)', () {
    test('afstand_m wint van het (vage) punt', () {
      const klus = HhKlus(
        id: 'k',
        hulpvragerId: 'o',
        status: HhKlusStatus.open,
        lat: 51.9,
        lon: 5.5,
        afstandMeter: 300,
        isLocatieVaag: true,
      );
      expect(afstandVanKlus(klus, (lat: 51.0, lon: 5.0)), 0.3);
      expect(afstandVanKlus(klus, null), 0.3, reason: 'ook zonder middelpunt');
    });

    test('zonder afstand_m: zoals voorheen (middelpunt)', () {
      const klus = HhKlus(
        id: 'k',
        hulpvragerId: 'o',
        status: HhKlusStatus.open,
        lat: 51.8865,
        lon: 5.4126,
      );
      expect(afstandVanKlus(klus, (lat: 51.8865, lon: 5.4126)), 0);
      expect(afstandVanKlus(klus, null), isNull);
    });
  });
}

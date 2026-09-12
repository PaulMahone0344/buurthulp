import 'dart:math';

import '../../../../l10n/teksten_klussen_nl.dart';
import '../model/hh_klus.dart';

/// Een punt op de kaart: breedte- en lengtegraad.
typedef HhPunt = ({double lat, double lon});

const _aardstraalKm = 6371.0;

double _radialen(double graden) => graden * pi / 180;

/// Afstand in kilometers over de aardbol (haversine). Goed genoeg voor
/// "ca. 1,2 km" in een wijk; niemand meet hier de route.
double afstandKm(HhPunt a, HhPunt b) {
  final dLat = _radialen(b.lat - a.lat);
  final dLon = _radialen(b.lon - a.lon);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(_radialen(a.lat)) * cos(_radialen(b.lat)) * pow(sin(dLon / 2), 2);
  return 2 * _aardstraalKm * asin(sqrt(h));
}

/// Het gemiddelde van de coördinaten van [klussen] die er een hebben; null
/// als geen enkele klus een locatie heeft. Pilot-keuze (M5, keuze 3): de
/// jongere heeft zelf geen coördinaten, dus dit is het middelpunt van zijn
/// wijk voor de straalfilter.
HhPunt? middelpunt(Iterable<HhKlus> klussen) {
  var n = 0;
  var somLat = 0.0;
  var somLon = 0.0;
  for (final klus in klussen) {
    if (!klus.heeftCoordinaten) continue;
    n++;
    somLat += klus.lat!;
    somLon += klus.lon!;
  }
  if (n == 0) return null;
  return (lat: somLat / n, lon: somLon / n);
}

/// Afstand van [klus] tot [punt], of null zonder coördinaten.
double? afstandVanKlus(HhKlus klus, HhPunt? punt) {
  if (punt == null || !klus.heeftCoordinaten) return null;
  return afstandKm((lat: klus.lat!, lon: klus.lon!), punt);
}

/// "ca. 1,2 km", of onder de kilometer "ca. 350 m" (op 50 m afgerond).
String afstandTekst(double km) {
  if (km < 1) {
    final meter = ((km * 1000) / 50).round() * 50;
    return TekstenKlussenNl.afstandMeter(meter < 50 ? 50 : meter);
  }
  final tekst = km.toStringAsFixed(1).replaceAll('.', ',');
  return TekstenKlussenNl.afstandKm(tekst);
}

import 'package:flutter/foundation.dart';

import '../model/hh_klustype.dart';

/// De drie bedragvelden van hh_klussen, in centen.
@immutable
class HhBedragen {
  const HhBedragen({
    required this.bedragBruto,
    required this.vergoedingJongere,
    required this.commissie,
  });

  final int bedragBruto;
  final int vergoedingJongere;
  final int commissie;

  @override
  bool operator ==(Object other) =>
      other is HhBedragen &&
      other.bedragBruto == bedragBruto &&
      other.vergoedingJongere == vergoedingJongere &&
      other.commissie == commissie;

  @override
  int get hashCode => Object.hash(bedragBruto, vergoedingJongere, commissie);
}

/// Vaste keuze voor de pilot (app-plan hoofdstuk 10 punt 1, backend
/// OPEN-PUNT 17): geen commissie. De oudere betaalt de richtvergoeding van
/// het klustype en de jongere krijgt datzelfde bedrag. Pure functie; bij
/// M16 verhuist dit naar een server-hook (zie OPEN-PUNTEN-M4.txt).
HhBedragen berekenBedragen(HhKlustype klustype) {
  final richt = klustype.richtvergoedingCenten;
  return HhBedragen(bedragBruto: richt, vergoedingJongere: richt, commissie: 0);
}

const _centenPerEuro = 100;

/// Centen als "€ 12,50": euroteken, spatie, komma, altijd twee decimalen.
String euroTekst(int centen) {
  final euros = centen ~/ _centenPerEuro;
  final rest = centen % _centenPerEuro;
  return '€ $euros,${rest.toString().padLeft(2, '0')}';
}

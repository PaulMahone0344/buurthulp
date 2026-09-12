import 'package:flutter/material.dart';

/// De enige plek die hh_klustypes.icoon (een naam als "shopping_cart")
/// naar een Material-icoon vertaalt. Onbekende of lege namen krijgen het
/// helpende-handen-icoon, zodat een nieuw klustype op de server nooit een
/// leeg vakje geeft.
abstract final class KlustypeIcoon {
  static const _iconen = <String, IconData>{
    'shopping_cart': Icons.shopping_cart_outlined,
    'yard': Icons.yard_outlined,
    'handyman': Icons.handyman_outlined,
    'devices': Icons.devices_outlined,
    'directions_walk': Icons.directions_walk,
    'directions_car': Icons.directions_car_outlined,
    'cleaning_services': Icons.cleaning_services_outlined,
    'pets': Icons.pets_outlined,
    'local_pharmacy': Icons.local_pharmacy_outlined,
    'restaurant': Icons.restaurant_outlined,
  };

  static const terugval = Icons.volunteer_activism_outlined;

  static IconData voor(String naam) => _iconen[naam.trim()] ?? terugval;

  /// Alle namen die de app kent; voor de test en voor wie op het webpaneel
  /// een nieuw klustype invoert.
  static Iterable<String> get bekendeNamen => _iconen.keys;
}

import 'package:flutter/material.dart';

/// hh_klustypes.icoon is een tekst (bv. "shopping_cart"). Een vaste tabel,
/// want iconen op naam opzoeken kan Flutter niet zonder de hele iconenset
/// mee te bundelen. Onbekend geeft een gereedschapsicoon.
const _klustypeIconen = <String, IconData>{
  'shopping_cart': Icons.shopping_cart_outlined,
  'yard': Icons.yard_outlined,
  'handyman': Icons.handyman_outlined,
  'devices': Icons.devices_outlined,
  'directions_walk': Icons.directions_walk,
  'directions_car': Icons.directions_car_outlined,
};

IconData klustypeIcoon(String naam) =>
    _klustypeIconen[naam] ?? Icons.build_outlined;

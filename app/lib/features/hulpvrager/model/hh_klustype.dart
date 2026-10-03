import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// Een categorie uit hh_klustypes: naam, icoonnaam, richtduur in minuten
/// en richtvergoeding in centen. B4: plus de minimumleeftijd van een
/// helper, de volgorde van de tegels en of hij nog te kiezen is (de oude
/// soorten van vóór B4 zijn niet-actief). Onveranderlijk.
@immutable
class HhKlustype {
  const HhKlustype({
    required this.id,
    required this.naam,
    this.icoon = '',
    this.richtduurMinuten = 0,
    this.richtvergoedingCenten = 0,
    this.minLeeftijd = 0,
    this.volgorde = 0,
    this.isActief = true,
  });

  final String id;
  final String naam;

  /// Naam van het icoon zoals de server hem kent (bv. "shopping_cart").
  final String icoon;
  final int richtduurMinuten;
  final int richtvergoedingCenten;

  /// Vanaf welke leeftijd een helper deze klus mag doen (10, 13 of 16).
  final int minLeeftijd;
  final int volgorde;
  final bool isActief;

  factory HhKlustype.vanRecord(RecordModel record) {
    return HhKlustype(
      id: record.id,
      naam: record.getStringValue('naam'),
      icoon: record.getStringValue('icoon'),
      richtduurMinuten: record.getIntValue('richtduur'),
      richtvergoedingCenten: record.getIntValue('richtvergoeding'),
      minLeeftijd: record.getIntValue('min_leeftijd'),
      volgorde: record.getIntValue('volgorde'),
      isActief: record.getBoolValue('actief'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhKlustype &&
      other.id == id &&
      other.naam == naam &&
      other.icoon == icoon &&
      other.richtduurMinuten == richtduurMinuten &&
      other.richtvergoedingCenten == richtvergoedingCenten &&
      other.minLeeftijd == minLeeftijd &&
      other.volgorde == volgorde &&
      other.isActief == isActief;

  @override
  int get hashCode => Object.hash(
    id,
    naam,
    icoon,
    richtduurMinuten,
    richtvergoedingCenten,
    minLeeftijd,
    volgorde,
    isActief,
  );
}

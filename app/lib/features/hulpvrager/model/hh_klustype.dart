import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// Een soort hulp uit hh_klustypes: naam, icoonnaam, richtduur in minuten
/// en richtvergoeding in centen. Onveranderlijk.
@immutable
class HhKlustype {
  const HhKlustype({
    required this.id,
    required this.naam,
    this.icoon = '',
    this.richtduurMinuten = 0,
    this.richtvergoedingCenten = 0,
  });

  final String id;
  final String naam;

  /// Naam van het icoon zoals de server hem kent (bv. "shopping_cart").
  final String icoon;
  final int richtduurMinuten;
  final int richtvergoedingCenten;

  factory HhKlustype.vanRecord(RecordModel record) {
    return HhKlustype(
      id: record.id,
      naam: record.getStringValue('naam'),
      icoon: record.getStringValue('icoon'),
      richtduurMinuten: record.getIntValue('richtduur'),
      richtvergoedingCenten: record.getIntValue('richtvergoeding'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhKlustype &&
      other.id == id &&
      other.naam == naam &&
      other.icoon == icoon &&
      other.richtduurMinuten == richtduurMinuten &&
      other.richtvergoedingCenten == richtvergoedingCenten;

  @override
  int get hashCode =>
      Object.hash(id, naam, icoon, richtduurMinuten, richtvergoedingCenten);
}

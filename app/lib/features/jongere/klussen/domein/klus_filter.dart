import 'package:flutter/foundation.dart';

import '../../../hulpvrager/model/hulpvraag_concept.dart';
import '../model/hh_klus.dart';
import 'afstand.dart';
import 'dagdeel.dart';

/// De filterbalk van J11: nul of meer klustypes en nul of meer dagdelen.
/// Leeg betekent "alles". Onveranderlijk.
@immutable
class KlusFilter {
  const KlusFilter({this.klustypeIds = const {}, this.dagdelen = const {}});

  final Set<String> klustypeIds;
  final Set<HhDagdeel> dagdelen;

  bool get isLeeg => klustypeIds.isEmpty && dagdelen.isEmpty;

  int get aantalActief =>
      (klustypeIds.isEmpty ? 0 : 1) + (dagdelen.isEmpty ? 0 : 1);

  bool laatDoor(HhKlus klus) {
    if (klustypeIds.isNotEmpty && !klustypeIds.contains(klus.klustypeId)) {
      return false;
    }
    if (dagdelen.isNotEmpty) {
      final dagdeel = dagdeelVan(klus.wanneerVan);
      if (dagdeel == null || !dagdelen.contains(dagdeel)) return false;
    }
    return true;
  }

  KlusFilter copyWith({Set<String>? klustypeIds, Set<HhDagdeel>? dagdelen}) =>
      KlusFilter(
        klustypeIds: klustypeIds ?? this.klustypeIds,
        dagdelen: dagdelen ?? this.dagdelen,
      );

  @override
  bool operator ==(Object other) =>
      other is KlusFilter &&
      setEquals(other.klustypeIds, klustypeIds) &&
      setEquals(other.dagdelen, dagdelen);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(klustypeIds),
    Object.hashAllUnordered(dagdelen),
  );
}

/// Wat de lijst en de kaart tonen na filteren en de straalfilter.
@immutable
class GefilterdeKlussen {
  const GefilterdeKlussen({
    required this.klussen,
    required this.buitenStraal,
    required this.middelpunt,
  });

  /// De klussen die overblijven, in de volgorde van de invoer.
  final List<HhKlus> klussen;

  /// Hoeveel klussen wel door de filterbalk kwamen maar buiten de straal
  /// liggen (voor de melding onder de lijst).
  final int buitenStraal;

  final HhPunt? middelpunt;

  List<HhKlus> get metCoordinaten => [
    for (final k in klussen)
      if (k.heeftCoordinaten) k,
  ];
  List<HhKlus> get zonderCoordinaten => [
    for (final k in klussen)
      if (!k.heeftCoordinaten) k,
  ];
}

/// Filterbalk plus straalfilter (M5, keuze 3). De straal geldt alleen als
/// [straalKm] groter is dan 0 en er een middelpunt is; een klus zonder
/// coördinaten valt nooit buiten de straal (die kunnen we niet meten).
GefilterdeKlussen filterKlussen(
  List<HhKlus> klussen,
  KlusFilter filter, {
  int straalKm = 0,
}) {
  final punt = middelpunt(klussen);
  final door = <HhKlus>[];
  var buiten = 0;
  for (final klus in klussen) {
    if (!filter.laatDoor(klus)) continue;
    final afstand = afstandVanKlus(klus, punt);
    if (straalKm > 0 && afstand != null && afstand > straalKm) {
      buiten++;
      continue;
    }
    door.add(klus);
  }
  return GefilterdeKlussen(
    klussen: List.unmodifiable(door),
    buitenStraal: buiten,
    middelpunt: punt,
  );
}

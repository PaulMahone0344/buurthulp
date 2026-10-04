import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../l10n/teksten_coordinator_nl.dart';
import '../../jongere/model/hh_profiel.dart' show HhProfiel;

/// De soorten melding uit hh_incidenten.soort.
enum HhIncidentSoort {
  nood('nood'),
  probleem('probleem'),
  overig('overig'),

  /// B5: "nee" op de geheime vraag na de klus. Zachter dan probleem: geen
  /// melding aan elke coordinator, wel in de lijst.
  signaal('signaal');

  const HhIncidentSoort(this.code);

  final String code;

  /// Onbekende serverwaarde telt als overig: een melding verdwijnt nooit
  /// uit de lijst omdat de app het woord niet kent.
  static HhIncidentSoort vanCode(String code) {
    for (final soort in values) {
      if (soort.code == code) return soort;
    }
    return HhIncidentSoort.overig;
  }

  String get naam => switch (this) {
    HhIncidentSoort.nood => TekstenCoordinatorNl.soortNood,
    HhIncidentSoort.probleem => TekstenCoordinatorNl.soortProbleem,
    HhIncidentSoort.overig => TekstenCoordinatorNl.soortOverig,
    HhIncidentSoort.signaal => TekstenCoordinatorNl.soortSignaal,
  };
}

/// Een melding uit hh_incidenten zoals de coordinator hem ziet (C1).
/// Onveranderlijk. De coordinator mag alles lezen, dus de expand van melder
/// en klus komt altijd mee; leeg betekent hier echt "niet ingevuld".
@immutable
class HhIncident {
  const HhIncident({
    required this.id,
    required this.soort,
    required this.aangemaaktOp,
    this.melderId = '',
    this.melderNaam = '',
    this.melderTelefoon = '',
    this.klusId = '',
    this.klusOmschrijving = '',
    this.omschrijving = '',
    this.afhandeling = '',
  });

  final String id;
  final HhIncidentSoort soort;
  final DateTime aangemaaktOp;
  final String melderId;
  final String melderNaam;
  final String melderTelefoon;
  final String klusId;
  final String klusOmschrijving;
  final String omschrijving;

  /// De aantekening van de coordinator. Gevuld = afgehandeld.
  final String afhandeling;

  /// Wat de lijst en het detail nodig hebben.
  static const expand = 'melder,klus';

  bool get isAfgehandeld => afhandeling.trim().isNotEmpty;
  bool get isNood => soort == HhIncidentSoort.nood;
  bool get heeftKlus => klusId.isNotEmpty;
  bool get heeftTelefoon => melderTelefoon.trim().isNotEmpty;

  factory HhIncident.vanRecord(RecordModel record) {
    final melder = record.get<RecordModel?>('expand.melder');
    final klus = record.get<RecordModel?>('expand.klus');
    return HhIncident(
      id: record.id,
      soort: HhIncidentSoort.vanCode(record.getStringValue('soort')),
      aangemaaktOp:
          HhProfiel.datumVanServer(record.getStringValue('created')) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      melderId: record.getStringValue('melder'),
      melderNaam: melder?.getStringValue('naam') ?? '',
      melderTelefoon: melder?.getStringValue('telefoon') ?? '',
      klusId: record.getStringValue('klus'),
      klusOmschrijving: klus?.getStringValue('omschrijving') ?? '',
      omschrijving: record.getStringValue('omschrijving'),
      afhandeling: record.getStringValue('afhandeling'),
    );
  }

  HhIncident metAfhandeling(String nieuweAfhandeling) => HhIncident(
    id: id,
    soort: soort,
    aangemaaktOp: aangemaaktOp,
    melderId: melderId,
    melderNaam: melderNaam,
    melderTelefoon: melderTelefoon,
    klusId: klusId,
    klusOmschrijving: klusOmschrijving,
    omschrijving: omschrijving,
    afhandeling: nieuweAfhandeling,
  );

  @override
  bool operator ==(Object other) =>
      other is HhIncident &&
      other.id == id &&
      other.soort == soort &&
      other.afhandeling == afhandeling &&
      other.aangemaaktOp == aangemaaktOp;

  @override
  int get hashCode => Object.hash(id, soort, afhandeling, aangemaaktOp);
}

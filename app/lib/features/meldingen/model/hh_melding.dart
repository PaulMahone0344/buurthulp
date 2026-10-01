import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../jongere/model/hh_profiel.dart' show HhProfiel;

/// De soorten uit hh_meldingen.soort (backend script 30).
enum HhMeldingSoort {
  nieuweKlus('nieuwe_klus'),
  toegewezen('toegewezen'),
  onderweg('onderweg'),
  afgerond('afgerond'),
  geannuleerd('geannuleerd'),
  incident('incident'),

  /// Een waarde die de app (nog) niet kent: de melding blijft zichtbaar.
  onbekend('');

  const HhMeldingSoort(this.code);

  final String code;

  static HhMeldingSoort vanCode(String code) {
    for (final soort in values) {
      if (soort.code.isNotEmpty && soort.code == code) return soort;
    }
    return HhMeldingSoort.onbekend;
  }
}

/// Eén melding uit hh_meldingen (M8, laag 1). De server (hook) maakt hem;
/// de app leest hem en zet alleen gelezen_op. Onveranderlijk.
@immutable
class HhMelding {
  const HhMelding({
    required this.id,
    required this.ontvangerId,
    required this.soort,
    this.klusId = '',
    this.incidentId = '',
    this.titel = '',
    this.tekst = '',
    this.gemaakt,
    this.gelezenOp,
  });

  static const collectie = 'hh_meldingen';
  static const veldGelezenOp = 'gelezen_op';

  final String id;
  final String ontvangerId;
  final HhMeldingSoort soort;
  final String klusId;
  final String incidentId;
  final String titel;
  final String tekst;

  /// "created" van de server (UTC).
  final DateTime? gemaakt;
  final DateTime? gelezenOp;

  bool get isGelezen => gelezenOp != null;

  factory HhMelding.vanRecord(RecordModel record) => HhMelding(
    id: record.id,
    ontvangerId: record.getStringValue('ontvanger'),
    soort: HhMeldingSoort.vanCode(record.getStringValue('soort')),
    klusId: record.getStringValue('klus'),
    incidentId: record.getStringValue('incident'),
    titel: record.getStringValue('titel'),
    tekst: record.getStringValue('tekst'),
    gemaakt: HhProfiel.datumVanServer(record.getStringValue('created')),
    gelezenOp: HhProfiel.datumVanServer(record.getStringValue(veldGelezenOp)),
  );

  HhMelding gelezenOpMoment(DateTime moment) => HhMelding(
    id: id,
    ontvangerId: ontvangerId,
    soort: soort,
    klusId: klusId,
    incidentId: incidentId,
    titel: titel,
    tekst: tekst,
    gemaakt: gemaakt,
    gelezenOp: moment,
  );

  @override
  bool operator ==(Object other) =>
      other is HhMelding &&
      other.id == id &&
      other.gelezenOp == gelezenOp &&
      other.titel == titel &&
      other.tekst == tekst;

  @override
  int get hashCode => Object.hash(id, gelezenOp, titel, tekst);
}

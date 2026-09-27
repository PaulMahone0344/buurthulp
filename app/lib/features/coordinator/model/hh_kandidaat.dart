import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// Een goedgekeurde jongere zoals C2 hem in de koppellijst toont: naam,
/// wijk en het aantal klussen dat hij deed. Komt uit hh_profielen met de
/// expand van gebruiker en diens wijk (de coordinator mag beide lezen).
@immutable
class HhKandidaat {
  const HhKandidaat({
    required this.id,
    required this.naam,
    this.wijkId = '',
    this.wijkNaam = '',
    this.klussenAantal = 0,
  });

  /// Het id van de GEBRUIKER (hh_users), niet van het profiel: dat is wat
  /// de koppel-route in de body verwacht.
  final String id;
  final String naam;
  final String wijkId;
  final String wijkNaam;
  final int klussenAantal;

  /// hh_profielen met de gebruiker en diens wijk erbij.
  static const expand = 'gebruiker,gebruiker.wijk';

  bool get heeftWijk => wijkId.isNotEmpty;

  /// Leest een hh_profielen-record. Geeft null als de expand van gebruiker
  /// ontbreekt: zonder gebruiker is er niets om aan te koppelen.
  static HhKandidaat? vanProfielRecord(RecordModel record) {
    final gebruiker = record.get<RecordModel?>('expand.gebruiker');
    if (gebruiker == null) return null;
    final wijk = gebruiker.get<RecordModel?>('expand.wijk');
    return HhKandidaat(
      id: gebruiker.id,
      naam: gebruiker.getStringValue('naam'),
      wijkId: gebruiker.getStringValue('wijk'),
      wijkNaam: wijk?.getStringValue('wijk') ?? '',
      klussenAantal: record.getIntValue('klussen_aantal'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhKandidaat &&
      other.id == id &&
      other.naam == naam &&
      other.wijkId == wijkId &&
      other.klussenAantal == klussenAantal;

  @override
  int get hashCode => Object.hash(id, naam, wijkId, klussenAantal);
}

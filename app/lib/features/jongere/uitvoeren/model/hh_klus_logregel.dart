import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../../theme.dart';
import '../../model/hh_profiel.dart';

/// Een regel uit hh_klus_status: wie zette de klus wanneer van welke status
/// naar welke. Sinds M6 schrijft alleen de hook deze regels; de app leest ze
/// om de tijd per stap te tonen (J15) en de geschiedenis te volgen (O7).
///
/// [van] is leeg bij de allereerste regel (de klus ontstond). [toelichting]
/// is alleen gevuld bij een annulering: de verplichte reden.
@immutable
class HhKlusLogregel {
  const HhKlusLogregel({
    required this.id,
    required this.klusId,
    required this.naar,
    this.van,
    this.doorId = '',
    this.toelichting = '',
    this.wanneer,
  });

  final String id;
  final String klusId;

  /// Null bij de eerste regel: er was nog geen status.
  final HhKlusStatus? van;
  final HhKlusStatus naar;
  final String doorId;
  final String toelichting;

  /// Het tijdstempel van de wissel: het veld "created" van de logregel.
  final DateTime? wanneer;

  bool get isEerste => van == null;
  bool get heeftToelichting => toelichting.trim().isNotEmpty;

  static const collectie = 'hh_klus_status';

  /// Oudste eerst; dat is de volgorde waarin de stappen gezet zijn.
  static const sort = 'created,id';

  factory HhKlusLogregel.vanRecord(RecordModel record) {
    final vanCode = record.getStringValue('van');
    return HhKlusLogregel(
      id: record.id,
      klusId: record.getStringValue('klus'),
      van: vanCode.isEmpty ? null : statusVanCode(vanCode),
      naar: statusVanCode(record.getStringValue('naar')),
      doorId: record.getStringValue('door'),
      toelichting: record.getStringValue('toelichting'),
      wanneer: HhProfiel.datumVanServer(record.getStringValue('created')),
    );
  }

  /// Een onbekende serverwaarde valt terug op open; zo verdwijnt een regel
  /// nooit uit de geschiedenis door een nieuwe status.
  static HhKlusStatus statusVanCode(String code) {
    for (final status in HhKlusStatus.values) {
      if (status.name == code) return status;
    }
    return HhKlusStatus.open;
  }
}

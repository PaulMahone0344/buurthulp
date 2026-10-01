import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../theme.dart';
import '../../jongere/klussen/model/hh_klus.dart' show HhKlus;
import '../../jongere/model/hh_profiel.dart' show HhProfiel;

/// Een klus zoals de COORDINATOR hem ziet (C2). Een eigen model naast
/// [HhKlus] van M5, omdat de coordinator andere velden nodig heeft: hij
/// mag altijd alles zien (naam en wijk van de oudere staan er dus altijd
/// in, ook op een open klus), hij heeft [aangemaaktOp] nodig voor "open
/// sinds", en hij wil weten wie er nu op de klus staat.
@immutable
class HhCoordinatorKlus {
  const HhCoordinatorKlus({
    required this.id,
    required this.status,
    required this.aangemaaktOp,
    this.klustypeNaam = '',
    this.omschrijving = '',
    this.adres = '',
    this.wanneerVan,
    this.wanneerTot,
    this.oudereId = '',
    this.oudereNaam = '',
    this.oudereWijkId = '',
    this.oudereWijkNaam = '',
    this.toegewezenJongereId = '',
    this.toegewezenJongereNaam = '',
  });

  final String id;
  final HhKlusStatus status;
  final DateTime aangemaaktOp;
  final String klustypeNaam;
  final String omschrijving;
  final String adres;
  final DateTime? wanneerVan;
  final DateTime? wanneerTot;
  final String oudereId;
  final String oudereNaam;
  final String oudereWijkId;
  final String oudereWijkNaam;
  final String toegewezenJongereId;
  final String toegewezenJongereNaam;

  /// Alles wat C2 toont; de coordinator mag elke expand lezen.
  static const expand =
      'klustype,hulpvrager,hulpvrager.wijk,toegewezen_jongere';

  bool get isOpen => status == HhKlusStatus.open && toegewezenJongereId.isEmpty;

  /// Alleen vanuit deze twee statussen laat de hook vrijgeven toe.
  bool get isVrijTeGeven =>
      status == HhKlusStatus.geaccepteerd || status == HhKlusStatus.onderweg;

  factory HhCoordinatorKlus.vanRecord(RecordModel record) {
    final klustype = record.get<RecordModel?>('expand.klustype');
    final oudere = record.get<RecordModel?>('expand.hulpvrager');
    final wijk = oudere?.get<RecordModel?>('expand.wijk');
    final jongere = record.get<RecordModel?>('expand.toegewezen_jongere');
    return HhCoordinatorKlus(
      id: record.id,
      status: HhKlus.statusVanCode(record.getStringValue('status')),
      aangemaaktOp:
          HhProfiel.datumVanServer(record.getStringValue('created')) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      klustypeNaam: klustype?.getStringValue('naam') ?? '',
      omschrijving: record.getStringValue('omschrijving'),
      adres: record.getStringValue('adres'),
      wanneerVan: HhProfiel.datumVanServer(
        record.getStringValue('wanneer_van'),
      ),
      wanneerTot: HhProfiel.datumVanServer(
        record.getStringValue('wanneer_tot'),
      ),
      oudereId: record.getStringValue('hulpvrager'),
      oudereNaam: oudere?.getStringValue('naam') ?? '',
      oudereWijkId: oudere?.getStringValue('wijk') ?? '',
      oudereWijkNaam: wijk?.getStringValue('wijk') ?? '',
      toegewezenJongereId: record.getStringValue('toegewezen_jongere'),
      toegewezenJongereNaam: jongere?.getStringValue('naam') ?? '',
    );
  }

  HhCoordinatorKlus copyWith({
    HhKlusStatus? status,
    String? toegewezenJongereId,
    String? toegewezenJongereNaam,
  }) => HhCoordinatorKlus(
    id: id,
    status: status ?? this.status,
    aangemaaktOp: aangemaaktOp,
    klustypeNaam: klustypeNaam,
    omschrijving: omschrijving,
    adres: adres,
    wanneerVan: wanneerVan,
    wanneerTot: wanneerTot,
    oudereId: oudereId,
    oudereNaam: oudereNaam,
    oudereWijkId: oudereWijkId,
    oudereWijkNaam: oudereWijkNaam,
    toegewezenJongereId: toegewezenJongereId ?? this.toegewezenJongereId,
    toegewezenJongereNaam: toegewezenJongereNaam ?? this.toegewezenJongereNaam,
  );

  @override
  bool operator ==(Object other) =>
      other is HhCoordinatorKlus &&
      other.id == id &&
      other.status == status &&
      other.toegewezenJongereId == toegewezenJongereId &&
      other.aangemaaktOp == aangemaaktOp;

  @override
  int get hashCode =>
      Object.hash(id, status, toegewezenJongereId, aangemaaktOp);
}

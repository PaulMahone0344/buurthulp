import 'package:flutter/foundation.dart';

/// B3: waar de ouder-toestemming van een helper onder 18 staat. Komt van
/// GET /api/hh/ouder/status (backend/pb_hooks/hh_ouder.pb.js); de app leest
/// hh_ouder_toestemming nooit zelf (alleen de meldkamer mag dat).
enum HhOuderStatus {
  /// Nog nooit een mail verstuurd.
  geen('geen'),

  /// Mail met code is weg; de ouder moet nog toestemming geven.
  verstuurd('verstuurd'),

  /// De ouder gaf toestemming.
  gegeven('gegeven'),

  /// De ouder trok de toestemming in.
  ingetrokken('ingetrokken'),

  /// De code is ouder dan 24 uur.
  verlopen('verlopen');

  const HhOuderStatus(this.code);

  final String code;

  static HhOuderStatus vanCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return HhOuderStatus.geen;
  }
}

@immutable
class HhOuderStand {
  const HhOuderStand({
    this.status = HhOuderStatus.geen,
    this.nodig = true,
    this.ouderEmail = '',
    this.verstuurdOp,
    this.isGeblokkeerd = false,
    this.gegevenOp,
    this.nogTeSturen = 3,
  });

  final HhOuderStatus status;

  /// Onder 18 (of leeftijd onbekend): toestemming is nodig.
  final bool nodig;
  final String ouderEmail;
  final DateTime? verstuurdOp;

  /// 5 keer een verkeerde code: de ouder kan pas verder met een nieuwe.
  final bool isGeblokkeerd;
  final DateTime? gegevenOp;

  /// Hoeveel mails er vandaag nog mogen (max 3 per dag).
  final int nogTeSturen;

  bool get kanOpnieuw => nogTeSturen > 0;

  /// De laatste code werkt niet meer: verlopen of geblokkeerd.
  bool get wachtOpNieuweCode =>
      status == HhOuderStatus.verlopen ||
      (status == HhOuderStatus.verstuurd && isGeblokkeerd);

  factory HhOuderStand.vanJson(Map<String, dynamic> json) => HhOuderStand(
    status: HhOuderStatus.vanCode(json['status']),
    nodig: json['nodig'] != false,
    ouderEmail: '${json['ouder_email'] ?? ''}',
    verstuurdOp: _datum(json['verstuurd_op']),
    isGeblokkeerd: json['geblokkeerd'] == true,
    gegevenOp: _datum(json['gegeven_op']),
    nogTeSturen: json['nog_te_sturen'] is num
        ? (json['nog_te_sturen'] as num).toInt()
        : 0,
  );

  /// "2026-10-04 10:00:00.000Z" -> UTC, of null.
  static DateTime? _datum(Object? waarde) {
    final tekst = '${waarde ?? ''}'.trim();
    if (tekst.isEmpty) return null;
    return DateTime.tryParse(tekst.replaceFirst(' ', 'T'))?.toUtc();
  }

  @override
  bool operator ==(Object other) =>
      other is HhOuderStand &&
      other.status == status &&
      other.nodig == nodig &&
      other.ouderEmail == ouderEmail &&
      other.verstuurdOp == verstuurdOp &&
      other.isGeblokkeerd == isGeblokkeerd &&
      other.gegevenOp == gegevenOp &&
      other.nogTeSturen == nogTeSturen;

  @override
  int get hashCode => Object.hash(
    status,
    nodig,
    ouderEmail,
    verstuurdOp,
    isGeblokkeerd,
    gegevenOp,
    nogTeSturen,
  );
}

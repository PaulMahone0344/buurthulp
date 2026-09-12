import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../../theme.dart';
import '../../model/hh_profiel.dart';

/// Een klus uit hh_klussen zoals de jongere hem ziet (M5). Onveranderlijk.
///
/// [oudereNaam] en [oudereFotoUrl] komen uit de expand van hulpvrager; de
/// server geeft die alleen mee als de jongere de oudere mag zien (na
/// accepteren, hh_users-rule). Leeg betekent dus "nog niet zichtbaar", niet
/// "onbekend". [lat]/[lon] zijn null zolang de geocoding-hook niets kon
/// vinden (server bewaart dan 0/0).
@immutable
class HhKlus {
  const HhKlus({
    required this.id,
    required this.hulpvragerId,
    required this.status,
    this.klustypeId = '',
    this.klustypeNaam = '',
    this.klustypeIcoon = '',
    this.richtduurMinuten = 0,
    this.omschrijving = '',
    this.adres = '',
    this.lat,
    this.lon,
    this.wanneerVan,
    this.wanneerTot,
    this.vergoedingJongereCenten = 0,
    this.toegewezenJongereId = '',
    this.oudereNaam = '',
    this.oudereFotoUrl = '',
    this.oudereWijkId = '',
  });

  final String id;
  final String hulpvragerId;
  final HhKlusStatus status;
  final String klustypeId;
  final String klustypeNaam;
  final String klustypeIcoon;
  final int richtduurMinuten;
  final String omschrijving;
  final String adres;
  final double? lat;
  final double? lon;
  final DateTime? wanneerVan;
  final DateTime? wanneerTot;
  final int vergoedingJongereCenten;
  final String toegewezenJongereId;
  final String oudereNaam;
  final String oudereFotoUrl;
  final String oudereWijkId;

  static const veldStatus = 'status';
  static const veldToegewezenJongere = 'toegewezen_jongere';
  static const veldWanneerVan = 'wanneer_van';

  /// Wat de lijst en het detail nodig hebben; klustype altijd, hulpvrager
  /// alleen zichtbaar na accepteren.
  static const expand = 'klustype,hulpvrager';

  bool get heeftCoordinaten => lat != null && lon != null;
  bool get isOpen => status == HhKlusStatus.open && toegewezenJongereId.isEmpty;
  bool isToegewezenAan(String jongereId) =>
      jongereId.isNotEmpty && toegewezenJongereId == jongereId;

  /// Is de oudere (naam, adres) zichtbaar voor de jongere? De server geeft
  /// de expand van hulpvrager alleen mee als dat zo is.
  bool get isOudereZichtbaar => oudereNaam.isNotEmpty;

  /// Leest een hh_klussen-record met expand klustype en hulpvrager.
  /// [fotoUrl] maakt van het hulpvrager-record en de bestandsnaam een URL
  /// (de gateway kent de client); zonder [fotoUrl] blijft de foto leeg.
  factory HhKlus.vanRecord(
    RecordModel record, {
    String Function(RecordModel oudere, String bestand)? fotoUrl,
  }) {
    final klustype = record.get<RecordModel?>('expand.klustype');
    final oudere = record.get<RecordModel?>('expand.hulpvrager');
    final lat = record.getDoubleValue('lat');
    final lon = record.getDoubleValue('lon');
    final heeftPunt = lat != 0 || lon != 0;
    final foto = oudere?.getStringValue('foto') ?? '';
    return HhKlus(
      id: record.id,
      hulpvragerId: record.getStringValue('hulpvrager'),
      status: statusVanCode(record.getStringValue(veldStatus)),
      klustypeId: record.getStringValue('klustype'),
      klustypeNaam: klustype?.getStringValue('naam') ?? '',
      klustypeIcoon: klustype?.getStringValue('icoon') ?? '',
      richtduurMinuten: klustype?.getIntValue('richtduur') ?? 0,
      omschrijving: record.getStringValue('omschrijving'),
      adres: record.getStringValue('adres'),
      lat: heeftPunt ? lat : null,
      lon: heeftPunt ? lon : null,
      wanneerVan: HhProfiel.datumVanServer(
        record.getStringValue(veldWanneerVan),
      ),
      wanneerTot: HhProfiel.datumVanServer(
        record.getStringValue('wanneer_tot'),
      ),
      vergoedingJongereCenten: record.getIntValue('vergoeding_jongere'),
      toegewezenJongereId: record.getStringValue(veldToegewezenJongere),
      oudereNaam: oudere?.getStringValue('naam') ?? '',
      oudereFotoUrl: oudere != null && foto.isNotEmpty && fotoUrl != null
          ? fotoUrl(oudere, foto)
          : '',
      oudereWijkId: oudere?.getStringValue('wijk') ?? '',
    );
  }

  /// hh_klussen.status -> [HhKlusStatus]; onbekend telt als open zodat een
  /// nieuwe serverwaarde nooit een klus verbergt.
  static HhKlusStatus statusVanCode(String code) {
    for (final status in HhKlusStatus.values) {
      if (status.name == code) return status;
    }
    return HhKlusStatus.open;
  }

  HhKlus copyWith({
    HhKlusStatus? status,
    String? toegewezenJongereId,
    String? oudereNaam,
    String? oudereFotoUrl,
    String? adres,
  }) {
    return HhKlus(
      id: id,
      hulpvragerId: hulpvragerId,
      status: status ?? this.status,
      klustypeId: klustypeId,
      klustypeNaam: klustypeNaam,
      klustypeIcoon: klustypeIcoon,
      richtduurMinuten: richtduurMinuten,
      omschrijving: omschrijving,
      adres: adres ?? this.adres,
      lat: lat,
      lon: lon,
      wanneerVan: wanneerVan,
      wanneerTot: wanneerTot,
      vergoedingJongereCenten: vergoedingJongereCenten,
      toegewezenJongereId: toegewezenJongereId ?? this.toegewezenJongereId,
      oudereNaam: oudereNaam ?? this.oudereNaam,
      oudereFotoUrl: oudereFotoUrl ?? this.oudereFotoUrl,
      oudereWijkId: oudereWijkId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhKlus &&
      other.id == id &&
      other.status == status &&
      other.toegewezenJongereId == toegewezenJongereId &&
      other.oudereNaam == oudereNaam &&
      other.adres == adres &&
      other.wanneerVan == wanneerVan;

  @override
  int get hashCode => Object.hash(
    id,
    status,
    toegewezenJongereId,
    oudereNaam,
    adres,
    wanneerVan,
  );
}

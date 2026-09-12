import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'hh_beschikbaarheid.dart';
import 'hh_screening_status.dart';

/// Het hh_profielen-record van een jongere. Onveranderlijk; een wijziging
/// levert via [copyWith] een nieuw object. Bestandsvelden houden alleen de
/// bestandsnaam van de server (leeg = geen bestand); de app toont nooit de
/// beschermde foto's zelf, alleen of ze er zijn.
@immutable
class HhProfiel {
  const HhProfiel({
    required this.id,
    required this.gebruikerId,
    this.verificatiestatus = HhScreeningStatus.nieuw,
    this.vogStatus = HhScreeningStatus.nieuw,
    this.isIbanGeverifieerd = false,
    this.straalKm = 0,
    this.beschikbaarheid = const HhBeschikbaarheid.leeg(),
    this.klustypeIds = const {},
    this.overMij = '',
    this.documentFoto = '',
    this.selfie = '',
    this.iban = '',
    this.vogAangevraagdOp,
  });

  final String id;
  final String gebruikerId;
  final HhScreeningStatus verificatiestatus;
  final HhScreeningStatus vogStatus;
  final bool isIbanGeverifieerd;
  final int straalKm;
  final HhBeschikbaarheid beschikbaarheid;
  final Set<String> klustypeIds;
  final String overMij;
  final String documentFoto;
  final String selfie;
  final String iban;
  final DateTime? vogAangevraagdOp;

  factory HhProfiel.vanRecord(RecordModel record) {
    return HhProfiel(
      id: record.id,
      gebruikerId: record.getStringValue('gebruiker'),
      verificatiestatus: HhScreeningStatus.vanCode(
        record.getStringValue('verificatiestatus'),
      ),
      vogStatus: HhScreeningStatus.vanCode(record.getStringValue('vog_status')),
      isIbanGeverifieerd: record.getBoolValue('iban_geverifieerd'),
      straalKm: record.getDoubleValue('straal_km').round(),
      beschikbaarheid: HhBeschikbaarheid.vanJson(record.get('beschikbaarheid')),
      klustypeIds: Set.unmodifiable(record.getListValue<String>('klustypes')),
      overMij: record.getStringValue('over_mij'),
      documentFoto: record.getStringValue('document_foto'),
      selfie: record.getStringValue('selfie'),
      iban: record.getStringValue('iban'),
      vogAangevraagdOp: datumVanServer(
        record.getStringValue('vog_aangevraagd_op'),
      ),
    );
  }

  /// PocketBase-datums: "2026-09-12 10:00:00.000Z" of ISO. Leeg is null.
  static DateTime? datumVanServer(String waarde) {
    if (waarde.isEmpty) return null;
    return DateTime.tryParse(waarde);
  }

  bool get heeftDocumentFoto => documentFoto.isNotEmpty;
  bool get heeftSelfie => selfie.isNotEmpty;

  HhProfiel copyWith({
    HhScreeningStatus? verificatiestatus,
    HhScreeningStatus? vogStatus,
    bool? isIbanGeverifieerd,
    int? straalKm,
    HhBeschikbaarheid? beschikbaarheid,
    Set<String>? klustypeIds,
    String? overMij,
    String? documentFoto,
    String? selfie,
    String? iban,
    DateTime? Function()? vogAangevraagdOp,
  }) {
    return HhProfiel(
      id: id,
      gebruikerId: gebruikerId,
      verificatiestatus: verificatiestatus ?? this.verificatiestatus,
      vogStatus: vogStatus ?? this.vogStatus,
      isIbanGeverifieerd: isIbanGeverifieerd ?? this.isIbanGeverifieerd,
      straalKm: straalKm ?? this.straalKm,
      beschikbaarheid: beschikbaarheid ?? this.beschikbaarheid,
      klustypeIds: klustypeIds ?? this.klustypeIds,
      overMij: overMij ?? this.overMij,
      documentFoto: documentFoto ?? this.documentFoto,
      selfie: selfie ?? this.selfie,
      iban: iban ?? this.iban,
      vogAangevraagdOp: vogAangevraagdOp != null
          ? vogAangevraagdOp()
          : this.vogAangevraagdOp,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhProfiel &&
      other.id == id &&
      other.gebruikerId == gebruikerId &&
      other.verificatiestatus == verificatiestatus &&
      other.vogStatus == vogStatus &&
      other.isIbanGeverifieerd == isIbanGeverifieerd &&
      other.straalKm == straalKm &&
      other.beschikbaarheid == beschikbaarheid &&
      setEquals(other.klustypeIds, klustypeIds) &&
      other.overMij == overMij &&
      other.documentFoto == documentFoto &&
      other.selfie == selfie &&
      other.iban == iban &&
      other.vogAangevraagdOp == vogAangevraagdOp;

  @override
  int get hashCode => Object.hash(
    id,
    gebruikerId,
    verificatiestatus,
    vogStatus,
    isIbanGeverifieerd,
    straalKm,
    beschikbaarheid,
    Object.hashAllUnordered(klustypeIds),
    overMij,
    documentFoto,
    selfie,
    iban,
    vogAangevraagdOp,
  );
}

/// Referentiedata: een wijk uit hh_wijken.
@immutable
class HhWijk {
  const HhWijk({
    required this.id,
    required this.gemeente,
    required this.wijk,
    this.isActief = true,
  });

  final String id;
  final String gemeente;
  final String wijk;
  final bool isActief;

  factory HhWijk.vanRecord(RecordModel record) => HhWijk(
    id: record.id,
    gemeente: record.getStringValue('gemeente'),
    wijk: record.getStringValue('wijk'),
    isActief: record.getBoolValue('actief'),
  );
}

/// Referentiedata: een klussoort uit hh_klustypes. [icoon] is de naam van
/// het icoon zoals de server hem kent; de vertaling naar een IconData staat
/// in het scherm.
@immutable
class HhKlustype {
  const HhKlustype({required this.id, required this.naam, this.icoon = ''});

  final String id;
  final String naam;
  final String icoon;

  factory HhKlustype.vanRecord(RecordModel record) => HhKlustype(
    id: record.id,
    naam: record.getStringValue('naam'),
    icoon: record.getStringValue('icoon'),
  );
}

/// De velden van hh_users die de screening nodig heeft en die niet in
/// HhGebruiker zitten: foto, geboortedatum en wijk.
@immutable
class HhAccountGegevens {
  const HhAccountGegevens({
    this.fotoBestand = '',
    this.geboortedatum,
    this.wijkId = '',
  });

  final String fotoBestand;
  final DateTime? geboortedatum;
  final String wijkId;

  factory HhAccountGegevens.vanRecord(RecordModel record) => HhAccountGegevens(
    fotoBestand: record.getStringValue('foto'),
    geboortedatum: HhProfiel.datumVanServer(
      record.getStringValue('geboortedatum'),
    ),
    wijkId: record.getStringValue('wijk'),
  );

  bool get heeftFoto => fotoBestand.isNotEmpty;

  HhAccountGegevens copyWith({
    String? fotoBestand,
    DateTime? Function()? geboortedatum,
    String? wijkId,
  }) {
    return HhAccountGegevens(
      fotoBestand: fotoBestand ?? this.fotoBestand,
      geboortedatum: geboortedatum != null
          ? geboortedatum()
          : this.geboortedatum,
      wijkId: wijkId ?? this.wijkId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhAccountGegevens &&
      other.fotoBestand == fotoBestand &&
      other.geboortedatum == geboortedatum &&
      other.wijkId == wijkId;

  @override
  int get hashCode => Object.hash(fotoBestand, geboortedatum, wijkId);
}

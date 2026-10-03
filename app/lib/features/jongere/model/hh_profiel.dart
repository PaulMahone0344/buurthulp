import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'hh_screening_status.dart';

/// Het hh_profielen-record van een helper (rol jongere). Onveranderlijk;
/// een wijziging levert via [copyWith] een nieuw object. [documentFoto]
/// houdt alleen de bestandsnaam van de server (leeg = geen bestand); de app
/// toont de beschermde foto nooit zelf. Sinds B2 leest de app alleen nog
/// wat aanmelden en de wachtbalk nodig hebben (geen selfie, IBAN,
/// beschikbaarheid, klussoorten of vog_status meer).
@immutable
class HhProfiel {
  const HhProfiel({
    required this.id,
    required this.gebruikerId,
    this.verificatiestatus = HhScreeningStatus.nieuw,
    this.straalKm = 0,
    this.overMij = '',
    this.documentFoto = '',
    this.vogAangevraagdOp,
    this.vogGezienOp,
    this.idGecontroleerdOp,
  });

  final String id;
  final String gebruikerId;
  final HhScreeningStatus verificatiestatus;

  /// Uit M3 (werkgebied); de app zet hem niet meer, de klussenlijst
  /// gebruikt hem nog als filter als hij er staat.
  final int straalKm;
  final String overMij;
  final String documentFoto;
  final DateTime? vogAangevraagdOp;

  /// Helper 18+: de meldkamer zag de VOG op deze datum (B1).
  final DateTime? vogGezienOp;

  /// De meldkamer controleerde het ID (en de server wiste de foto).
  final DateTime? idGecontroleerdOp;

  factory HhProfiel.vanRecord(RecordModel record) {
    return HhProfiel(
      id: record.id,
      gebruikerId: record.getStringValue('gebruiker'),
      verificatiestatus: HhScreeningStatus.vanCode(
        record.getStringValue('verificatiestatus'),
      ),
      straalKm: record.getDoubleValue('straal_km').round(),
      overMij: record.getStringValue('over_mij'),
      documentFoto: record.getStringValue('document_foto'),
      vogAangevraagdOp: datumVanServer(
        record.getStringValue('vog_aangevraagd_op'),
      ),
      vogGezienOp: datumVanServer(record.getStringValue('vog_gezien_op')),
      idGecontroleerdOp: datumVanServer(
        record.getStringValue('id_gecontroleerd_op'),
      ),
    );
  }

  /// PocketBase-datums: "2026-09-12 10:00:00.000Z" of ISO. Leeg is null.
  static DateTime? datumVanServer(String waarde) {
    if (waarde.isEmpty) return null;
    return DateTime.tryParse(waarde);
  }

  bool get heeftDocumentFoto => documentFoto.isNotEmpty;
  bool get isIdGecontroleerd => idGecontroleerdOp != null;

  HhProfiel copyWith({
    HhScreeningStatus? verificatiestatus,
    int? straalKm,
    String? overMij,
    String? documentFoto,
    DateTime? Function()? vogAangevraagdOp,
    DateTime? Function()? vogGezienOp,
    DateTime? Function()? idGecontroleerdOp,
  }) {
    return HhProfiel(
      id: id,
      gebruikerId: gebruikerId,
      verificatiestatus: verificatiestatus ?? this.verificatiestatus,
      straalKm: straalKm ?? this.straalKm,
      overMij: overMij ?? this.overMij,
      documentFoto: documentFoto ?? this.documentFoto,
      vogAangevraagdOp: vogAangevraagdOp != null
          ? vogAangevraagdOp()
          : this.vogAangevraagdOp,
      vogGezienOp: vogGezienOp != null ? vogGezienOp() : this.vogGezienOp,
      idGecontroleerdOp: idGecontroleerdOp != null
          ? idGecontroleerdOp()
          : this.idGecontroleerdOp,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhProfiel &&
      other.id == id &&
      other.gebruikerId == gebruikerId &&
      other.verificatiestatus == verificatiestatus &&
      other.straalKm == straalKm &&
      other.overMij == overMij &&
      other.documentFoto == documentFoto &&
      other.vogAangevraagdOp == vogAangevraagdOp &&
      other.vogGezienOp == vogGezienOp &&
      other.idGecontroleerdOp == idGecontroleerdOp;

  @override
  int get hashCode => Object.hash(
    id,
    gebruikerId,
    verificatiestatus,
    straalKm,
    overMij,
    documentFoto,
    vogAangevraagdOp,
    vogGezienOp,
    idGecontroleerdOp,
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

/// De velden van hh_users die aanmelden en de wachtbalk nodig hebben en
/// die niet in HhGebruiker zitten: geboortedatum, wijk en (helper < 18) de
/// datum waarop de ouder toestemming gaf (zet alleen de meldkamer/server).
@immutable
class HhAccountGegevens {
  const HhAccountGegevens({
    this.geboortedatum,
    this.wijkId = '',
    this.ouderToestemmingOp,
  });

  final DateTime? geboortedatum;
  final String wijkId;
  final DateTime? ouderToestemmingOp;

  factory HhAccountGegevens.vanRecord(RecordModel record) => HhAccountGegevens(
    geboortedatum: HhProfiel.datumVanServer(
      record.getStringValue('geboortedatum'),
    ),
    wijkId: record.getStringValue('wijk'),
    ouderToestemmingOp: HhProfiel.datumVanServer(
      record.getStringValue('ouder_toestemming_op'),
    ),
  );

  HhAccountGegevens copyWith({
    DateTime? Function()? geboortedatum,
    String? wijkId,
    DateTime? Function()? ouderToestemmingOp,
  }) {
    return HhAccountGegevens(
      geboortedatum: geboortedatum != null
          ? geboortedatum()
          : this.geboortedatum,
      wijkId: wijkId ?? this.wijkId,
      ouderToestemmingOp: ouderToestemmingOp != null
          ? ouderToestemmingOp()
          : this.ouderToestemmingOp,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhAccountGegevens &&
      other.geboortedatum == geboortedatum &&
      other.wijkId == wijkId &&
      other.ouderToestemmingOp == ouderToestemmingOp;

  @override
  int get hashCode => Object.hash(geboortedatum, wijkId, ouderToestemmingOp);
}

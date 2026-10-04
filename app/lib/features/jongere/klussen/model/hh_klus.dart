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
    this.oudereContactNaam = '',
    this.jongereNaam = '',
    this.isJongereIdGecontroleerd = false,
    this.geplaatstDoorId = '',
    this.wordtNagekeken = false,
    this.afkeurReden = '',
    this.klusFotoUrl = '',
    this.afstandMeter,
    this.isLocatieVaag = false,
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

  /// M6: de contactpersoon van de oudere (hh_users.contact_naam). De jongere
  /// ziet die pas als de klus van hem is; het telefoonnummer nooit als tekst
  /// (dat loopt via de belroute).
  final String oudereContactNaam;

  /// M6: naam van de toegewezen helper, uit de expand van
  /// toegewezen_jongere. De bewoner ziet die op O7 zodra er een helper is;
  /// leeg betekent "nog niemand" of "niet meegevraagd". Sinds B2 stuurt de
  /// server een bewoner alleen de voornaam (hh_aanmelden.pb.js) en toont de
  /// app geen foto van de helper (geen beelden van mensen).
  final String jongereNaam;

  /// B2: het vinkje "ID gecontroleerd" (extra veld id_gecontroleerd dat de
  /// server bij een helper meestuurt). Nooit het document zelf.
  final bool isJongereIdGecontroleerd;

  /// Wie de klus plaatste (de bewoner zelf, of de meldkamer bij een
  /// telefonische klus).
  final String geplaatstDoorId;

  /// B4: een open klus die de meldkamer nog niet goedkeurde
  /// (klus_goedgekeurd_op leeg). Alleen de bewoner (en de meldkamer) ziet
  /// hem dan; helpers nog niet.
  final bool wordtNagekeken;

  /// B4: de reden als de meldkamer de klus afkeurde (status geannuleerd).
  final String afkeurReden;

  /// B4: de foto van de klus (beschermd bestand) als URL met een kortlevend
  /// bestandstoken; leeg als er geen foto is of hij niet is meegevraagd.
  final String klusFotoUrl;

  /// ADRES (antwoord Ibrahim 3): vóór de match stuurt de server een vaag punt
  /// (~200 m verschoven) en [afstandMeter] = de afstand van het eigen punt van
  /// de helper tot het ECHTE punt, afgerond op 100 m. Null = niet meegegeven
  /// (dan rekent de app zoals voorheen).
  final int? afstandMeter;

  /// ADRES: het punt is bewust vaag (vóór de match).
  final bool isLocatieVaag;

  static const veldStatus = 'status';
  static const veldToegewezenJongere = 'toegewezen_jongere';
  static const veldWanneerVan = 'wanneer_van';

  /// Wat de lijst en het detail nodig hebben; klustype altijd, hulpvrager
  /// alleen zichtbaar na accepteren.
  static const expand = 'klustype,hulpvrager';

  /// M6: wat de oudere op O7/O8 nodig heeft — ook de toegewezen jongere.
  static const expandMetJongere = 'klustype,hulpvrager,toegewezen_jongere';

  /// De voornaam van de jongere ("Sanne is onderweg naar u"); de server
  /// bewaart de volle naam.
  String get jongereVoornaam {
    final delen = jongereNaam.trim().split(RegExp(r'\s+'));
    return delen.isEmpty ? '' : delen.first;
  }

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
    String Function(RecordModel klus, String bestand)? klusFotoUrl,
  }) {
    final klustype = record.get<RecordModel?>('expand.klustype');
    final oudere = record.get<RecordModel?>('expand.hulpvrager');
    final jongere = record.get<RecordModel?>('expand.toegewezen_jongere');
    final lat = record.getDoubleValue('lat');
    final lon = record.getDoubleValue('lon');
    final heeftPunt = lat != 0 || lon != 0;
    final foto = oudere?.getStringValue('foto') ?? '';
    final klusFotos = record.getListValue<String>('foto');
    final status = statusVanCode(record.getStringValue(veldStatus));
    final afgekeurd = record.getStringValue('klus_afgekeurd_op').isNotEmpty;
    return HhKlus(
      id: record.id,
      hulpvragerId: record.getStringValue('hulpvrager'),
      status: status,
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
      oudereContactNaam: oudere?.getStringValue('contact_naam') ?? '',
      jongereNaam: jongere?.getStringValue('naam') ?? '',
      isJongereIdGecontroleerd:
          jongere?.getBoolValue('id_gecontroleerd') ?? false,
      geplaatstDoorId: record.getStringValue('geplaatst_door'),
      wordtNagekeken:
          status == HhKlusStatus.open &&
          !afgekeurd &&
          record.getStringValue('klus_goedgekeurd_op').isEmpty,
      afkeurReden: afgekeurd ? record.getStringValue('klus_afkeur_reden') : '',
      klusFotoUrl: klusFotos.isNotEmpty && klusFotoUrl != null
          ? klusFotoUrl(record, klusFotos.first)
          : '',
      afstandMeter: record.data['afstand_m'] is num
          ? (record.data['afstand_m'] as num).round()
          : null,
      isLocatieVaag: record.getBoolValue('locatie_vaag'),
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
    String? jongereNaam,
    bool? isJongereIdGecontroleerd,
    String? geplaatstDoorId,
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
      oudereContactNaam: oudereContactNaam,
      jongereNaam: jongereNaam ?? this.jongereNaam,
      isJongereIdGecontroleerd:
          isJongereIdGecontroleerd ?? this.isJongereIdGecontroleerd,
      geplaatstDoorId: geplaatstDoorId ?? this.geplaatstDoorId,
      wordtNagekeken: wordtNagekeken,
      afkeurReden: afkeurReden,
      klusFotoUrl: klusFotoUrl,
      afstandMeter: afstandMeter,
      isLocatieVaag: isLocatieVaag,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhKlus &&
      other.id == id &&
      other.status == status &&
      other.toegewezenJongereId == toegewezenJongereId &&
      other.oudereNaam == oudereNaam &&
      other.jongereNaam == jongereNaam &&
      other.isJongereIdGecontroleerd == isJongereIdGecontroleerd &&
      other.adres == adres &&
      other.wanneerVan == wanneerVan &&
      other.wordtNagekeken == wordtNagekeken &&
      other.afkeurReden == afkeurReden &&
      other.klusFotoUrl == klusFotoUrl;

  @override
  int get hashCode => Object.hash(
    id,
    status,
    toegewezenJongereId,
    oudereNaam,
    jongereNaam,
    isJongereIdGecontroleerd,
    adres,
    wanneerVan,
    wordtNagekeken,
    afkeurReden,
    klusFotoUrl,
  );
}

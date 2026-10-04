import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../jongere/model/hh_profiel.dart' show HhProfiel;

/// De statussen uit hh_reacties.status (backend script 130, B5).
enum HhReactieStatus {
  /// Helper onder 18: de ouder moet eerst "Goed" zeggen.
  wachtOpOuder('wacht_op_ouder'),

  /// De bewoner ziet hem en kan kiezen.
  open('open'),

  /// De bewoner koos deze helper: de match.
  gekozen('gekozen'),

  /// De bewoner koos iemand anders, of de ouder koos "liever niet".
  afgewezen('afgewezen'),

  /// De helper trok hem zelf in (of gaf de klus na de match terug).
  ingetrokken('ingetrokken'),

  /// De klus ging niet door of begon voordat de ouder koos.
  vervallen('vervallen'),

  /// Een waarde die de app (nog) niet kent.
  onbekend('');

  const HhReactieStatus(this.code);

  final String code;

  static HhReactieStatus vanCode(String code) {
    for (final s in values) {
      if (s.code.isNotEmpty && s.code == code) return s;
    }
    return HhReactieStatus.onbekend;
  }

  /// Nog in de race: wacht op de ouder of op de keuze van de bewoner.
  bool get isActief =>
      this == HhReactieStatus.wachtOpOuder || this == HhReactieStatus.open;
}

/// Een reactie van de helper zelf (hh_reacties, rule: helper = ik).
@immutable
class HhReactie {
  const HhReactie({
    required this.id,
    required this.klusId,
    required this.helperId,
    required this.status,
    this.bericht = '',
    this.klusSamenvatting = '',
    this.ouderBesluit = '',
    this.ouderGaatMee = false,
    this.gemaakt,
  });

  static const collectie = 'hh_reacties';

  final String id;
  final String klusId;
  final String helperId;
  final HhReactieStatus status;
  final String bericht;

  /// "Tuin, zaterdag 10 oktober om 10:00" (de server zet hem), zodat de
  /// helper ook een reactie ziet op een klus die hij niet meer mag openen.
  final String klusSamenvatting;

  /// "goed" of "liever_niet" (helper onder 18), anders leeg.
  final String ouderBesluit;
  final bool ouderGaatMee;
  final DateTime? gemaakt;

  bool get isDoorOuderAfgewezen => ouderBesluit == 'liever_niet';

  factory HhReactie.vanRecord(RecordModel record) => HhReactie(
    id: record.id,
    klusId: record.getStringValue('klus'),
    helperId: record.getStringValue('helper'),
    status: HhReactieStatus.vanCode(record.getStringValue('status')),
    bericht: record.getStringValue('bericht'),
    klusSamenvatting: record.getStringValue('klus_samenvatting'),
    ouderBesluit: record.getStringValue('ouder_besluit'),
    ouderGaatMee: record.getBoolValue('ouder_gaat_mee'),
    gemaakt: HhProfiel.datumVanServer(record.getStringValue('created')),
  );

  HhReactie metStatus(HhReactieStatus nieuw) => HhReactie(
    id: id,
    klusId: klusId,
    helperId: helperId,
    status: nieuw,
    bericht: bericht,
    klusSamenvatting: klusSamenvatting,
    ouderBesluit: ouderBesluit,
    ouderGaatMee: ouderGaatMee,
    gemaakt: gemaakt,
  );

  @override
  bool operator ==(Object other) =>
      other is HhReactie &&
      other.id == id &&
      other.status == status &&
      other.bericht == bericht &&
      other.ouderBesluit == ouderBesluit;

  @override
  int get hashCode => Object.hash(id, status, bericht, ouderBesluit);
}

/// Wat de bewoner op KiesHelper ziet (GET /api/hh/klussen/{id}/reacties).
/// De server stuurt NOOIT achternaam, geboortedatum of adres mee.
@immutable
class HhReactieKaart {
  const HhReactieKaart({
    required this.reactieId,
    required this.helperId,
    required this.voornaam,
    this.leeftijd,
    this.niveau = 'Nieuw',
    this.sterren = 0,
    this.beoordelingen = 0,
    this.isIdGecontroleerd = false,
    this.laatsteRecensie = '',
    this.bericht = '',
    this.ouderGaatMee = false,
  });

  final String reactieId;
  final String helperId;
  final String voornaam;
  final int? leeftijd;

  /// "Nieuw" tot B9 echte niveaus brengt.
  final String niveau;
  final double sterren;
  final int beoordelingen;
  final bool isIdGecontroleerd;
  final String laatsteRecensie;
  final String bericht;
  final bool ouderGaatMee;

  factory HhReactieKaart.vanJson(Map<String, dynamic> json) {
    final leeftijd = json['leeftijd'];
    final sterren = json['sterren'];
    final aantal = json['beoordelingen'];
    return HhReactieKaart(
      reactieId: '${json['reactie'] ?? ''}',
      helperId: '${json['helper'] ?? ''}',
      voornaam: '${json['voornaam'] ?? ''}',
      leeftijd: leeftijd is num ? leeftijd.toInt() : null,
      niveau: '${json['niveau'] ?? 'Nieuw'}',
      sterren: sterren is num ? sterren.toDouble() : 0,
      beoordelingen: aantal is num ? aantal.toInt() : 0,
      isIdGecontroleerd: json['id_gecontroleerd'] == true,
      laatsteRecensie: '${json['laatste_recensie'] ?? ''}',
      bericht: '${json['bericht'] ?? ''}',
      ouderGaatMee: json['ouder_gaat_mee'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhReactieKaart &&
      other.reactieId == reactieId &&
      other.voornaam == voornaam &&
      other.sterren == sterren &&
      other.beoordelingen == beoordelingen;

  @override
  int get hashCode => Object.hash(reactieId, voornaam, sterren, beoordelingen);
}

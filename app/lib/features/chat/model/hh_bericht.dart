import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../jongere/model/hh_profiel.dart' show HhProfiel;

/// hh_berichten.soort (backend script 110). Een snelknop is een gewoon
/// bericht; hij wisselt NOOIT de status van de klus.
enum HhBerichtSoort {
  tekst('tekst'),
  snel('snel');

  const HhBerichtSoort(this.code);

  final String code;

  static HhBerichtSoort vanCode(String code) =>
      code == snel.code ? snel : tekst;
}

/// Eén bericht uit hh_berichten (B6). De server zet [helperId] (de helper
/// van dit gesprek), filtert nummers, mail en links weg ("•••", dan
/// [isGefilterd]) en laat de ontvanger alleen gelezen_op zetten.
/// Onveranderlijk.
@immutable
class HhBericht {
  const HhBericht({
    required this.id,
    required this.klusId,
    required this.afzenderId,
    required this.tekst,
    this.helperId = '',
    this.soort = HhBerichtSoort.tekst,
    this.gemaakt,
    this.gelezenOp,
    this.isGefilterd = false,
    this.isGewist = false,
  });

  static const collectie = 'hh_berichten';
  static const veldGelezenOp = 'gelezen_op';

  /// Gelijk aan de max van hh_berichten.tekst op de server.
  static const maxTekst = 500;

  final String id;
  final String klusId;
  final String afzenderId;
  final String helperId;
  final String tekst;
  final HhBerichtSoort soort;

  /// "created" van de server (UTC).
  final DateTime? gemaakt;
  final DateTime? gelezenOp;

  /// De server verving een nummer, mailadres of link door "•••".
  final bool isGefilterd;

  /// Integratie (AVG): het account van de afzender is verwijderd; de tekst
  /// is leeg en de app toont "Bericht verwijderd".
  final bool isGewist;

  bool get isGelezen => gelezenOp != null;
  bool isVan(String gebruikerId) => afzenderId == gebruikerId;

  factory HhBericht.vanRecord(RecordModel record) => HhBericht(
    id: record.id,
    klusId: record.getStringValue('klus'),
    afzenderId: record.getStringValue('afzender'),
    helperId: record.getStringValue('helper'),
    tekst: record.getStringValue('tekst'),
    soort: HhBerichtSoort.vanCode(record.getStringValue('soort')),
    gemaakt: HhProfiel.datumVanServer(record.getStringValue('created')),
    gelezenOp: HhProfiel.datumVanServer(record.getStringValue(veldGelezenOp)),
    isGefilterd: record.getBoolValue('gefilterd'),
    isGewist: record.getBoolValue('gewist'),
  );

  HhBericht metGelezenOp(DateTime moment) => HhBericht(
    id: id,
    klusId: klusId,
    afzenderId: afzenderId,
    helperId: helperId,
    tekst: tekst,
    soort: soort,
    gemaakt: gemaakt,
    gelezenOp: moment,
    isGefilterd: isGefilterd,
    isGewist: isGewist,
  );

  @override
  bool operator ==(Object other) =>
      other is HhBericht &&
      other.id == id &&
      other.tekst == tekst &&
      other.gelezenOp == gelezenOp &&
      other.isGefilterd == isGefilterd &&
      other.isGewist == isGewist;

  @override
  int get hashCode => Object.hash(id, tekst, gelezenOp, isGefilterd, isGewist);
}

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../model/hh_profiel.dart';

/// Eén record uit hh_beoordelingen (M7). Onveranderlijk. Een beoordeling
/// hoort bij één klus en gaat van één deelnemer naar de andere; per klus per
/// kant bestaat er hooguit één (unieke index klus + van_gebruiker).
@immutable
class HhBeoordeling {
  const HhBeoordeling({
    required this.id,
    required this.klusId,
    required this.vanId,
    required this.naarId,
    required this.sterren,
    this.tekst = '',
    this.gemaakt,
  });

  static const collectie = 'hh_beoordelingen';

  final String id;
  final String klusId;
  final String vanId;
  final String naarId;

  /// 1 t/m 5.
  final int sterren;
  final String tekst;

  /// Het veld "created" (UTC van de server); null als het ontbreekt.
  final DateTime? gemaakt;

  bool get heeftTekst => tekst.trim().isNotEmpty;

  factory HhBeoordeling.vanRecord(RecordModel record) => HhBeoordeling(
    id: record.id,
    klusId: record.getStringValue('klus'),
    vanId: record.getStringValue('van_gebruiker'),
    naarId: record.getStringValue('naar_gebruiker'),
    sterren: record.getIntValue('sterren'),
    tekst: record.getStringValue('tekst'),
    gemaakt: HhProfiel.datumVanServer(record.getStringValue('created')),
  );

  HhBeoordeling copyWith({int? sterren, String? tekst}) => HhBeoordeling(
    id: id,
    klusId: klusId,
    vanId: vanId,
    naarId: naarId,
    sterren: sterren ?? this.sterren,
    tekst: tekst ?? this.tekst,
    gemaakt: gemaakt,
  );

  @override
  bool operator ==(Object other) =>
      other is HhBeoordeling &&
      other.id == id &&
      other.sterren == sterren &&
      other.tekst == tekst;

  @override
  int get hashCode => Object.hash(id, sterren, tekst);
}

/// De reputatie van een persoon zoals de SERVER hem uitrekent (hook
/// hh_beoordelingen.pb.js en hh_klussen.pb.js, via hh_reputatie.js) en op
/// hh_users zet. De app leest hem alleen.
@immutable
class HhReputatie {
  const HhReputatie({this.sterrenGemiddeld = 0, this.klussenAantal = 0});

  static const veldSterren = 'sterren_gemiddeld';
  static const veldKlussen = 'klussen_aantal';

  /// 0 t/m 5, op één decimaal; 0 = nog geen beoordelingen.
  final double sterrenGemiddeld;
  final int klussenAantal;

  bool get heeftBeoordelingen => sterrenGemiddeld > 0;

  factory HhReputatie.vanRecord(RecordModel record) => HhReputatie(
    sterrenGemiddeld: record.getDoubleValue(veldSterren),
    klussenAantal: record.getIntValue(veldKlussen),
  );

  @override
  bool operator ==(Object other) =>
      other is HhReputatie &&
      other.sterrenGemiddeld == sterrenGemiddeld &&
      other.klussenAantal == klussenAantal;

  @override
  int get hashCode => Object.hash(sterrenGemiddeld, klussenAantal);
}

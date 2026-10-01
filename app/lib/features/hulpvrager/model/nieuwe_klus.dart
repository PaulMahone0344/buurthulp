import 'package:flutter/foundation.dart';

import '../domein/bedragen.dart';

/// Wat de app naar hh_klussen stuurt bij het plaatsen (O5). Precies de
/// velden die de createRule voor een oudere toestaat: hulpvrager =
/// geplaatst_door = ik, bron app, status open, geen jongere. lat/lon
/// blijven leeg (geocoding komt in M5).
@immutable
class NieuweKlus {
  const NieuweKlus({
    required this.hulpvragerId,
    required this.klustypeId,
    required this.omschrijving,
    required this.adres,
    required this.wanneerVan,
    required this.wanneerTot,
    required this.bedragen,
    this.geplaatstDoorId,
    this.bron = bronApp,
  });

  final String hulpvragerId;
  final String klustypeId;
  final String omschrijving;
  final String adres;
  final DateTime wanneerVan;
  final DateTime wanneerTot;
  final HhBedragen bedragen;

  /// M9: een familielid plaatst namens de oudere (F2). Leeg = de oudere zelf.
  final String? geplaatstDoorId;
  final String bron;

  static const statusOpen = 'open';
  static const statusConcept = 'concept';
  static const bronApp = 'app';
  static const bronFamilie = 'familie';

  /// Het verzoek zoals de server hem verwacht. Datums in UTC (ISO 8601),
  /// bedragen in centen.
  Map<String, dynamic> get alsBody => {
    'hulpvrager': hulpvragerId,
    'geplaatst_door': geplaatstDoorId ?? hulpvragerId,
    'klustype': klustypeId,
    'omschrijving': omschrijving,
    'adres': adres,
    'wanneer_van': wanneerVan.toUtc().toIso8601String(),
    'wanneer_tot': wanneerTot.toUtc().toIso8601String(),
    'status': statusOpen,
    'bedrag_bruto': bedragen.bedragBruto,
    'vergoeding_jongere': bedragen.vergoedingJongere,
    'commissie': bedragen.commissie,
    'bron': bron,
  };
}

/// Het antwoord van het plaatsen: het id van de klus. De oudere ziet dit id
/// nooit (geen cijfers op O6); het is er voor de smoke en het verslag.
///
/// M6: het veld isLogGeschreven is vervallen. De logregel in hh_klus_status
/// schrijft de hook nu zelf bij het aanmaken (app OPEN-PUNT M4:32).
@immutable
class GeplaatsteHulpvraag {
  const GeplaatsteHulpvraag({required this.klusId});

  final String klusId;
}

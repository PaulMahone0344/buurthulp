import 'package:flutter/foundation.dart';

import '../../jongere/foto_kiezer.dart';
import '../domein/bedragen.dart';

/// Wat de app naar hh_klussen stuurt bij het plaatsen. Precies de velden
/// die de createRule voor een bewoner toestaat: hulpvrager = geplaatst_door
/// = ik, bron app, status open, geen helper. lat/lon zet de server
/// (geocoding, M5). B4: met de verplichte [foto] (als bestand, niet in
/// [alsBody]), het nee-lijst-vinkje en een optionele eindtijd. De
/// keur-velden en de leeftijdsgrens zet de server; die gaan nooit mee.
@immutable
class NieuweKlus {
  const NieuweKlus({
    required this.hulpvragerId,
    required this.klustypeId,
    required this.omschrijving,
    required this.adres,
    required this.wanneerVan,
    required this.bedragen,
    required this.foto,
    this.wanneerTot,
    this.geplaatstDoorId,
    this.bron = bronApp,
  });

  final String hulpvragerId;
  final String klustypeId;
  final String omschrijving;
  final String adres;
  final DateTime wanneerVan;

  /// Leeg = geen eindtijd (schakelaar "Eindtijd" uit).
  final DateTime? wanneerTot;
  final HhBedragen bedragen;

  /// De klusfoto; de gateway stuurt hem als bestand in veld [veldFoto].
  final HhFoto foto;

  /// Wie de klus plaatste (de meldkamer bij een telefonische klus). Leeg =
  /// de bewoner zelf.
  final String? geplaatstDoorId;
  final String bron;

  static const statusOpen = 'open';
  static const statusConcept = 'concept';
  static const bronApp = 'app';
  static const veldFoto = 'foto';

  /// Het verzoek zoals de server hem verwacht. Datums in UTC (ISO 8601),
  /// bedragen in centen.
  Map<String, dynamic> get alsBody => {
    'hulpvrager': hulpvragerId,
    'geplaatst_door': geplaatstDoorId ?? hulpvragerId,
    'klustype': klustypeId,
    'omschrijving': omschrijving,
    'adres': adres,
    'wanneer_van': wanneerVan.toUtc().toIso8601String(),
    'wanneer_tot': ?wanneerTot?.toUtc().toIso8601String(),
    'status': statusOpen,
    'nee_lijst_akkoord': true,
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

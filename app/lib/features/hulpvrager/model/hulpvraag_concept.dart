import 'package:flutter/foundation.dart';

import '../../jongere/foto_kiezer.dart';
import 'hh_klustype.dart';

/// De dagkeuze op "Klus plaatsen": vandaag, morgen of een zelf gekozen dag.
enum HhDagKeuze { vandaag, morgen, andereDag }

/// Minstens zoveel tekens in "Vertel wat je wilt" (zelfde grens als de
/// server, hh_klusplaatsen_hulp.js).
const omschrijvingMinTekens = 5;

/// De klus in wording op de pagina "Klus plaatsen" (B4). Onveranderlijk;
/// elke wijziging levert via [copyWith] een nieuw object, zodat terug-
/// navigatie (bijvoorbeeld naar Mijn gegevens) de invoer nooit kwijtraakt.
@immutable
class HulpvraagConcept {
  const HulpvraagConcept({
    this.klustype,
    this.omschrijving = '',
    this.foto,
    this.dagKeuze,
    this.dag,
    this.vanafMinuten,
    this.heeftEindtijd = false,
    this.totMinuten,
    this.isNeeLijstAkkoord = false,
    this.adres,
    this.postcode,
    this.plaats,
  });

  final HhKlustype? klustype;

  /// "Vertel wat je wilt", hooguit 300 tekens.
  final String omschrijving;

  /// De verplichte foto van de klus, al verkleind.
  final HhFoto? foto;
  final HhDagKeuze? dagKeuze;

  /// De gekozen dag zonder tijd (middernacht, lokale tijd).
  final DateTime? dag;

  /// Tijdwiel "Vanaf" en "Tot", in minuten na middernacht (lokale tijd).
  /// Vanaf krijgt een standaardwaarde zodra er een dag is.
  final int? vanafMinuten;
  final bool heeftEindtijd;
  final int? totMinuten;

  /// Het verplichte vinkje "Mijn klus valt hier niet onder" (nee-lijst).
  final bool isNeeLijstAkkoord;

  /// Null zolang het adres uit Mijn gegevens nog niet geladen is.
  final String? adres;
  final String? postcode;
  final String? plaats;

  bool get isLeeg =>
      klustype == null &&
      omschrijving.isEmpty &&
      foto == null &&
      dag == null &&
      !isNeeLijstAkkoord;

  bool get heeftWat => klustype != null;
  bool get heeftOmschrijving =>
      omschrijving.trim().length >= omschrijvingMinTekens;
  bool get heeftFoto => foto != null;
  bool get heeftWanneer => dag != null && vanafMinuten != null;

  /// De eindtijd telt alleen als de schakelaar aan staat.
  int? get eindMinuten => heeftEindtijd ? totMinuten : null;
  bool get heeftGeldigeEindtijd {
    final eind = eindMinuten;
    final vanaf = vanafMinuten;
    return eind == null || (vanaf != null && eind > vanaf);
  }

  bool get heeftWaar =>
      (adres ?? '').trim().isNotEmpty &&
      (postcode ?? '').trim().isNotEmpty &&
      (plaats ?? '').trim().isNotEmpty;

  /// Alles wat de server bij het plaatsen eist (behalve "niet voorbij":
  /// daar is de klok voor nodig).
  bool get isCompleet =>
      heeftWat &&
      heeftOmschrijving &&
      heeftFoto &&
      heeftWanneer &&
      heeftGeldigeEindtijd &&
      heeftWaar &&
      isNeeLijstAkkoord;

  HulpvraagConcept copyWith({
    HhKlustype? Function()? klustype,
    String? omschrijving,
    HhFoto? Function()? foto,
    HhDagKeuze? Function()? dagKeuze,
    DateTime? Function()? dag,
    int? Function()? vanafMinuten,
    bool? heeftEindtijd,
    int? Function()? totMinuten,
    bool? isNeeLijstAkkoord,
    String? Function()? adres,
    String? Function()? postcode,
    String? Function()? plaats,
  }) {
    return HulpvraagConcept(
      klustype: klustype != null ? klustype() : this.klustype,
      omschrijving: omschrijving ?? this.omschrijving,
      foto: foto != null ? foto() : this.foto,
      dagKeuze: dagKeuze != null ? dagKeuze() : this.dagKeuze,
      dag: dag != null ? dag() : this.dag,
      vanafMinuten: vanafMinuten != null ? vanafMinuten() : this.vanafMinuten,
      heeftEindtijd: heeftEindtijd ?? this.heeftEindtijd,
      totMinuten: totMinuten != null ? totMinuten() : this.totMinuten,
      isNeeLijstAkkoord: isNeeLijstAkkoord ?? this.isNeeLijstAkkoord,
      adres: adres != null ? adres() : this.adres,
      postcode: postcode != null ? postcode() : this.postcode,
      plaats: plaats != null ? plaats() : this.plaats,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HulpvraagConcept &&
      other.klustype == klustype &&
      other.omschrijving == omschrijving &&
      identical(other.foto, foto) &&
      other.dagKeuze == dagKeuze &&
      other.dag == dag &&
      other.vanafMinuten == vanafMinuten &&
      other.heeftEindtijd == heeftEindtijd &&
      other.totMinuten == totMinuten &&
      other.isNeeLijstAkkoord == isNeeLijstAkkoord &&
      other.adres == adres &&
      other.postcode == postcode &&
      other.plaats == plaats;

  @override
  int get hashCode => Object.hash(
    klustype,
    omschrijving,
    foto,
    dagKeuze,
    dag,
    vanafMinuten,
    heeftEindtijd,
    totMinuten,
    isNeeLijstAkkoord,
    adres,
    postcode,
    plaats,
  );
}

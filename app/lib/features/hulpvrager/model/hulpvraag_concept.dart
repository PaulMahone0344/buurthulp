import 'package:flutter/foundation.dart';

import '../../adres/model/hh_adres.dart';
import '../../jongere/foto_kiezer.dart';
import 'hh_klustype.dart';

/// De dagkeuze op "Klus plaatsen". Sinds feedbackronde 1 (23 okt) toont de
/// pagina alleen "Vandaag" en "Kies een dag"; [morgen] blijft voor de
/// tekst "morgen" bij een gekozen dag.
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
    this.totMinuten,
    this.adres,
    this.postcode,
    this.plaats,
    this.isElders = false,
    this.eldersAdres,
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
  /// Allebei verplicht (feedbackronde 1); ze krijgen een standaardwaarde
  /// zodra er een dag is.
  final int? vanafMinuten;
  final int? totMinuten;

  /// Null zolang het adres uit Mijn gegevens nog niet geladen is.
  final String? adres;
  final String? postcode;
  final String? plaats;

  /// Feedbackronde 1 punt B: de klus is niet bij de bewoner thuis. Dan
  /// komen [adres], [postcode] en [plaats] uit [eldersAdres] (PDOK).
  final bool isElders;

  /// Het gekozen adres bij "Ergens anders"; null zolang er geen bruikbaar
  /// adres is.
  final HhAdres? eldersAdres;

  bool get isLeeg =>
      klustype == null && omschrijving.isEmpty && foto == null && dag == null;

  bool get heeftWat => klustype != null;
  bool get heeftOmschrijving =>
      omschrijving.trim().length >= omschrijvingMinTekens;
  bool get heeftFoto => foto != null;
  bool get heeftWanneer => dag != null && vanafMinuten != null;

  int? get eindMinuten => totMinuten;

  /// De eindtijd is verplicht en ligt na de begintijd.
  bool get heeftGeldigeEindtijd {
    final eind = totMinuten;
    final vanaf = vanafMinuten;
    return eind != null && vanaf != null && eind > vanaf;
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
      heeftWaar;

  HulpvraagConcept copyWith({
    HhKlustype? Function()? klustype,
    String? omschrijving,
    HhFoto? Function()? foto,
    HhDagKeuze? Function()? dagKeuze,
    DateTime? Function()? dag,
    int? Function()? vanafMinuten,
    int? Function()? totMinuten,
    String? Function()? adres,
    String? Function()? postcode,
    String? Function()? plaats,
    bool? isElders,
    HhAdres? Function()? eldersAdres,
  }) {
    return HulpvraagConcept(
      klustype: klustype != null ? klustype() : this.klustype,
      omschrijving: omschrijving ?? this.omschrijving,
      foto: foto != null ? foto() : this.foto,
      dagKeuze: dagKeuze != null ? dagKeuze() : this.dagKeuze,
      dag: dag != null ? dag() : this.dag,
      vanafMinuten: vanafMinuten != null ? vanafMinuten() : this.vanafMinuten,
      totMinuten: totMinuten != null ? totMinuten() : this.totMinuten,
      adres: adres != null ? adres() : this.adres,
      postcode: postcode != null ? postcode() : this.postcode,
      plaats: plaats != null ? plaats() : this.plaats,
      isElders: isElders ?? this.isElders,
      eldersAdres: eldersAdres != null ? eldersAdres() : this.eldersAdres,
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
      other.totMinuten == totMinuten &&
      other.adres == adres &&
      other.postcode == postcode &&
      other.plaats == plaats &&
      other.isElders == isElders &&
      other.eldersAdres == eldersAdres;

  @override
  int get hashCode => Object.hash(
    klustype,
    omschrijving,
    foto,
    dagKeuze,
    dag,
    vanafMinuten,
    totMinuten,
    adres,
    postcode,
    plaats,
    isElders,
    eldersAdres,
  );
}

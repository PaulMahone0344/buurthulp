import 'package:flutter/foundation.dart';

import 'hh_klustype.dart';

/// De drie dagdelen van O3, met de uren die hoofdstuk 3 en de prompt
/// vastleggen: ochtend 9-12, middag 13-17, avond 18-20.
enum HhDagdeel {
  ochtend(vanUur: 9, totUur: 12),
  middag(vanUur: 13, totUur: 17),
  avond(vanUur: 18, totUur: 20);

  const HhDagdeel({required this.vanUur, required this.totUur});

  final int vanUur;
  final int totUur;
}

/// De dagkeuze van O3: vandaag, morgen of een zelf gekozen dag.
enum HhDagKeuze { vandaag, morgen, andereDag }

/// De hulpvraag in wording, stap voor stap gevuld door O2-O4 en samengevat
/// op O5. Onveranderlijk; elke wijziging levert via [copyWith] een nieuw
/// object, zodat terug-navigatie de invoer nooit kwijtraakt.
@immutable
class HulpvraagConcept {
  const HulpvraagConcept({
    this.klustype,
    this.dagKeuze,
    this.dag,
    this.dagdeel,
    this.adres,
    this.postcode,
    this.plaats,
    this.toelichting = '',
  });

  final HhKlustype? klustype;
  final HhDagKeuze? dagKeuze;

  /// De gekozen dag zonder tijd (middernacht, lokale tijd).
  final DateTime? dag;
  final HhDagdeel? dagdeel;

  /// Null zolang O4 nog niet is geopend; dan wordt het adres uit de eigen
  /// gegevens voorgevuld. Daarna de (bewerkte) invoer.
  final String? adres;
  final String? postcode;
  final String? plaats;
  final String toelichting;

  bool get isLeeg =>
      klustype == null &&
      dag == null &&
      dagdeel == null &&
      adres == null &&
      toelichting.isEmpty;

  bool get heeftWat => klustype != null;
  bool get heeftWanneer => dag != null && dagdeel != null;
  bool get heeftWaar =>
      (adres ?? '').trim().isNotEmpty &&
      (postcode ?? '').trim().isNotEmpty &&
      (plaats ?? '').trim().isNotEmpty;

  /// Alles wat O5 nodig heeft om te plaatsen.
  bool get isCompleet => heeftWat && heeftWanneer && heeftWaar;

  HulpvraagConcept copyWith({
    HhKlustype? Function()? klustype,
    HhDagKeuze? Function()? dagKeuze,
    DateTime? Function()? dag,
    HhDagdeel? Function()? dagdeel,
    String? Function()? adres,
    String? Function()? postcode,
    String? Function()? plaats,
    String? toelichting,
  }) {
    return HulpvraagConcept(
      klustype: klustype != null ? klustype() : this.klustype,
      dagKeuze: dagKeuze != null ? dagKeuze() : this.dagKeuze,
      dag: dag != null ? dag() : this.dag,
      dagdeel: dagdeel != null ? dagdeel() : this.dagdeel,
      adres: adres != null ? adres() : this.adres,
      postcode: postcode != null ? postcode() : this.postcode,
      plaats: plaats != null ? plaats() : this.plaats,
      toelichting: toelichting ?? this.toelichting,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HulpvraagConcept &&
      other.klustype == klustype &&
      other.dagKeuze == dagKeuze &&
      other.dag == dag &&
      other.dagdeel == dagdeel &&
      other.adres == adres &&
      other.postcode == postcode &&
      other.plaats == plaats &&
      other.toelichting == toelichting;

  @override
  int get hashCode => Object.hash(
    klustype,
    dagKeuze,
    dag,
    dagdeel,
    adres,
    postcode,
    plaats,
    toelichting,
  );
}

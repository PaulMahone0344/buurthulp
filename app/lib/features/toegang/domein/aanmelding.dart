import 'package:flutter/foundation.dart';

import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_adres_nl.dart';
import '../../adres/domein/adres_invoer.dart';
import '../../jongere/datum_invoer.dart';
import '../model/hh_rol.dart';

/// B2: aanmelden in één scherm per rol. Pure regels (leeftijd, adres,
/// e-mail van de ouder) en wat er naar hh_users gaat. De client-controle is voor
/// de gebruiker; de server weigert een helper onder de 10 ook zelf
/// (hh_aanmelden.pb.js).

/// Een helper is minstens 10 jaar (koers B).
const minLeeftijdHelper = 10;

/// Vanaf 18: VOG verplicht, geen ouder-toestemming meer.
const volwassenLeeftijd = 18;

/// Leeftijd in hele jaren op [vandaag]; een verjaardag telt op de dag zelf.
int leeftijdOp(DateTime geboortedatum, DateTime vandaag) {
  var jaren = vandaag.year - geboortedatum.year;
  final nogNietJarig =
      vandaag.month < geboortedatum.month ||
      (vandaag.month == geboortedatum.month && vandaag.day < geboortedatum.day);
  if (nogNietJarig) jaren--;
  return jaren;
}

bool isMinderjarig(DateTime geboortedatum, DateTime vandaag) =>
    leeftijdOp(geboortedatum, vandaag) < volwassenLeeftijd;

/// Geboortedatum van een helper als dag-maand-jaar: verplicht, bestaand,
/// niet in de toekomst en minstens 10 jaar geleden.
String? valideerGeboortedatumHelper(String invoer, DateTime vandaag) {
  if (invoer.trim().isEmpty) {
    return TekstenAanmeldenNl.validatieGeboortedatumVerplicht;
  }
  final datum = parseDatumNl(invoer);
  if (datum == null) return TekstenAanmeldenNl.validatieGeboortedatumOngeldig;
  final dag = DateTime.utc(vandaag.year, vandaag.month, vandaag.day);
  if (datum.isAfter(dag)) {
    return TekstenAanmeldenNl.validatieGeboortedatumToekomst;
  }
  if (leeftijdOp(datum, vandaag) < minLeeftijdHelper) {
    return TekstenAanmeldenNl.validatieTeJong;
  }
  return null;
}

final _emailPatroon = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// ADRES (4 okt): het adres komt uit de adres-suggestie (PDOK). Zonder
/// keuze (nog niet gezocht, niet gevonden, nog bezig) kan aanmelden niet.
/// Een ongecontroleerde keuze (PDOK even weg) mag wel; de server markeert hem.
String? valideerAdresKeuze(AdresKeuze? keuze) =>
    keuze == null ? TekstenAdresNl.validatieVerplicht : null;

/// B3 (antwoord Ibrahim 4 okt): van de ouder van een helper onder 18 vraagt
/// de app alleen nog het e-mailadres (sms kan nog niet). Een eerder bewaard
/// ouder_telefoon blijft op de server staan. Niet je eigen adres.
String? valideerOuderEmail(String invoer, {String? eigenEmail}) {
  final schoon = invoer.trim().toLowerCase();
  if (schoon.isEmpty) return TekstenAanmeldenNl.validatieOuderVerplicht;
  if (!_emailPatroon.hasMatch(schoon)) {
    return TekstenAanmeldenNl.validatieOuderOngeldig;
  }
  if (eigenEmail != null && schoon == eigenEmail.trim().toLowerCase()) {
    return TekstenAanmeldenNl.validatieOuderEigen;
  }
  return null;
}

/// Alles wat een aanmelding naar de server stuurt naast naam, e-mail,
/// wachtwoord, rol en taal. Geen telefoon meer: de chat loopt in de app.
@immutable
sealed class HhAanmelding {
  const HhAanmelding({required this.email, required this.wachtwoord});

  final String email;
  final String wachtwoord;

  HhRol get rol;
  String get naam;

  /// De extra hh_users-velden.
  Map<String, Object> get velden;
}

/// Bewoner (rol hulpvrager). Het adres komt uit de adres-suggestie (ADRES,
/// 4 okt): postcode, huisnummer, toevoeging en, als PDOK het vond, straat en
/// plaats. De server zoekt het zelf ook op en overschrijft straat/plaats.
final class BewonerAanmelding extends HhAanmelding {
  const BewonerAanmelding({
    required this.naam,
    required super.email,
    required super.wachtwoord,
    required this.adres,
  });

  @override
  final String naam;
  final AdresKeuze adres;

  @override
  HhRol get rol => HhRol.hulpvrager;

  @override
  Map<String, Object> get velden => adres.velden;
}

/// Helper (rol jongere), vanaf 10 jaar. Onder 18 met [ouderEmail].
final class HelperAanmelding extends HhAanmelding {
  const HelperAanmelding({
    required this.voornaam,
    required super.email,
    required super.wachtwoord,
    required this.geboortedatum,
    required this.adres,
    this.ouderEmail,
  });

  final String voornaam;
  final DateTime geboortedatum;
  final AdresKeuze adres;
  final String? ouderEmail;

  @override
  HhRol get rol => HhRol.jongere;

  @override
  String get naam => voornaam.trim();

  @override
  Map<String, Object> get velden => {
    'geboortedatum': datumVoorServer(geboortedatum),
    ...adres.velden,
    if ((ouderEmail ?? '').trim().isNotEmpty)
      'ouder_email': (ouderEmail ?? '').trim().toLowerCase(),
  };
}

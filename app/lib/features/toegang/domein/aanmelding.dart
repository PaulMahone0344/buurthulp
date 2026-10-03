import 'package:flutter/foundation.dart';

import '../../../l10n/teksten_aanmelden_nl.dart';
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

final _postcodePatroon = RegExp(r'^([1-9]\d{3})\s*([A-Za-z]{2})$');
final _huisnummerPatroon = RegExp(r'^\d+[0-9A-Za-z\- ]{0,9}$');
final _emailPatroon = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? valideerPostcode(String waarde) {
  if (waarde.trim().isEmpty) {
    return TekstenAanmeldenNl.validatiePostcodeVerplicht;
  }
  return _postcodePatroon.hasMatch(waarde.trim())
      ? null
      : TekstenAanmeldenNl.validatiePostcodeOngeldig;
}

/// "4003ab" -> "4003 AB". Alleen voor een geldige postcode.
String normaliseerPostcode(String waarde) {
  final match = _postcodePatroon.firstMatch(waarde.trim());
  if (match == null) return waarde.trim();
  return '${match.group(1)} ${match.group(2)!.toUpperCase()}';
}

String? valideerHuisnummer(String waarde) {
  final schoon = waarde.trim();
  if (schoon.isEmpty) return TekstenAanmeldenNl.validatieHuisnummerVerplicht;
  return _huisnummerPatroon.hasMatch(schoon)
      ? null
      : TekstenAanmeldenNl.validatieHuisnummerOngeldig;
}

String? valideerStraat(String waarde) =>
    waarde.trim().isEmpty ? TekstenAanmeldenNl.validatieStraatVerplicht : null;

String? valideerPlaats(String waarde) =>
    waarde.trim().isEmpty ? TekstenAanmeldenNl.validatiePlaatsVerplicht : null;

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

/// Bewoner (rol hulpvrager). hh_users.adres blijft "straat + huisnummer"
/// zoals sinds M4 (voorvullen van de hulpvraag); huisnummer staat er sinds
/// B1 ook los.
final class BewonerAanmelding extends HhAanmelding {
  const BewonerAanmelding({
    required this.naam,
    required super.email,
    required super.wachtwoord,
    required this.straat,
    required this.huisnummer,
    required this.postcode,
    required this.plaats,
  });

  @override
  final String naam;
  final String straat;
  final String huisnummer;
  final String postcode;
  final String plaats;

  @override
  HhRol get rol => HhRol.hulpvrager;

  @override
  Map<String, Object> get velden => {
    'adres': '${straat.trim()} ${huisnummer.trim()}',
    'huisnummer': huisnummer.trim(),
    'postcode': normaliseerPostcode(postcode),
    'plaats': plaats.trim(),
  };
}

/// Helper (rol jongere), vanaf 10 jaar. Onder 18 met [ouderEmail].
final class HelperAanmelding extends HhAanmelding {
  const HelperAanmelding({
    required this.voornaam,
    required super.email,
    required super.wachtwoord,
    required this.geboortedatum,
    required this.postcode,
    required this.huisnummer,
    this.ouderEmail,
  });

  final String voornaam;
  final DateTime geboortedatum;
  final String postcode;
  final String huisnummer;
  final String? ouderEmail;

  @override
  HhRol get rol => HhRol.jongere;

  @override
  String get naam => voornaam.trim();

  @override
  Map<String, Object> get velden => {
    'geboortedatum': datumVoorServer(geboortedatum),
    'postcode': normaliseerPostcode(postcode),
    'huisnummer': huisnummer.trim(),
    if ((ouderEmail ?? '').trim().isNotEmpty)
      'ouder_email': (ouderEmail ?? '').trim().toLowerCase(),
  };
}

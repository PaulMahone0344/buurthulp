import 'package:flutter/foundation.dart';

import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../jongere/datum_invoer.dart';
import '../model/hh_rol.dart';

/// B2: aanmelden in één scherm per rol. Pure regels (leeftijd, adres,
/// ouder-contact) en wat er naar hh_users gaat. De client-controle is voor
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

/// Het contact van de ouder van een helper onder 18: een e-mailadres of
/// een mobiel nummer (06). Eén veld; de app herkent wat het is.
@immutable
sealed class OuderContact {
  const OuderContact();

  /// Wat naar hh_users gaat (ouder_email of ouder_telefoon).
  Map<String, String> get velden;
}

final class OuderEmail extends OuderContact {
  const OuderEmail(this.email);

  final String email;

  @override
  Map<String, String> get velden => {'ouder_email': email};

  @override
  bool operator ==(Object other) => other is OuderEmail && other.email == email;

  @override
  int get hashCode => email.hashCode;
}

final class OuderTelefoon extends OuderContact {
  const OuderTelefoon(this.nummer);

  /// Altijd als 06xxxxxxxx.
  final String nummer;

  @override
  Map<String, String> get velden => {'ouder_telefoon': nummer};

  @override
  bool operator ==(Object other) =>
      other is OuderTelefoon && other.nummer == nummer;

  @override
  int get hashCode => nummer.hashCode;
}

/// Null als het geen e-mailadres en geen Nederlands mobiel nummer is.
OuderContact? herkenOuderContact(String invoer) {
  final schoon = invoer.trim();
  if (schoon.isEmpty) return null;
  if (schoon.contains('@')) {
    return _emailPatroon.hasMatch(schoon) ? OuderEmail(schoon) : null;
  }
  var cijfers = schoon.replaceAll(RegExp(r'[\s\-().]'), '');
  if (cijfers.startsWith('+31')) cijfers = '0${cijfers.substring(3)}';
  if (cijfers.startsWith('0031')) cijfers = '0${cijfers.substring(4)}';
  return RegExp(r'^06\d{8}$').hasMatch(cijfers) ? OuderTelefoon(cijfers) : null;
}

String? valideerOuderContact(String invoer) {
  if (invoer.trim().isEmpty) return TekstenAanmeldenNl.validatieOuderVerplicht;
  return herkenOuderContact(invoer) == null
      ? TekstenAanmeldenNl.validatieOuderOngeldig
      : null;
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

/// Helper (rol jongere), vanaf 10 jaar. Onder 18 met [ouder].
final class HelperAanmelding extends HhAanmelding {
  const HelperAanmelding({
    required this.voornaam,
    required super.email,
    required super.wachtwoord,
    required this.geboortedatum,
    required this.postcode,
    required this.huisnummer,
    this.ouder,
  });

  final String voornaam;
  final DateTime geboortedatum;
  final String postcode;
  final String huisnummer;
  final OuderContact? ouder;

  @override
  HhRol get rol => HhRol.jongere;

  @override
  String get naam => voornaam.trim();

  @override
  Map<String, Object> get velden => {
    'geboortedatum': datumVoorServer(geboortedatum),
    'postcode': normaliseerPostcode(postcode),
    'huisnummer': huisnummer.trim(),
    ...?ouder?.velden,
  };
}

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../adres/domein/adres_invoer.dart' as adres_invoer;
import '../domein/werkgebied.dart';
import 'hh_rol.dart';

/// De talen die hh_users.taal kent. Vertalingen komen later; nu wordt de
/// keuze alleen opgeslagen.
enum HhTaal {
  nl('nl'),
  ar('ar'),
  tr('tr'),
  en('en');

  const HhTaal(this.code);

  final String code;

  static HhTaal vanCode(String? code) {
    for (final taal in values) {
      if (taal.code == code) return taal;
    }
    return HhTaal.nl;
  }
}

/// Een ingelogd HeitjeHulp-account (hh_users). Onveranderlijk; een
/// wijziging levert via [copyWith] een nieuw object.
@immutable
class HhGebruiker {
  const HhGebruiker({
    required this.id,
    required this.naam,
    required this.email,
    required this.rol,
    this.taal = HhTaal.nl,
    this.telefoon,
    this.isBevestigd = false,
    this.wijkId = '',
    this.werkgebiedStatus = HhWerkgebiedStatus.onbepaald,
    this.postcode = '',
    this.huisnummer = '',
  });

  final String id;
  final String naam;
  final String email;
  final HhRol rol;
  final HhTaal taal;
  final String? telefoon;

  /// hh_users.verified: e-mailadres bevestigd via de PocketBase-mail.
  final bool isBevestigd;

  /// B2: hh_users.wijk en werkgebied_status (zet de server uit de postcode).
  final String wijkId;
  final HhWerkgebiedStatus werkgebiedStatus;

  /// ADRES (4 okt): hh_users.postcode en huisnummer, alleen om te zien of
  /// een bestaand account zijn adres moet aanvullen (gele balk).
  final String postcode;
  final String huisnummer;

  /// Heeft een bewoner of helper een volledig adres (6-tekens-postcode en
  /// een huisnummer)? Andere rollen hebben geen adres nodig.
  bool get heeftVolledigAdres =>
      (rol != HhRol.hulpvrager && rol != HhRol.jongere) ||
      adres_invoer.heeftVolledigAdres(postcode, huisnummer);

  /// Een bewoner zonder wijk woont buiten het werkgebied (of zijn adres is
  /// nog niet gevonden): dan kan hij geen klus plaatsen.
  bool get magKlusPlaatsen => wijkId.isNotEmpty;

  /// Leest een hh_users-record. Gooit een [FormatException] bij een
  /// onbekende rol; de gateway vertaalt dat naar een nette fout.
  factory HhGebruiker.vanRecord(RecordModel record) {
    final rol = HhRol.vanCode(record.getStringValue('rol'));
    if (rol == null) {
      throw FormatException('onbekende rol in hh_users: ${record.id}');
    }
    final telefoon = record.getStringValue('telefoon');
    return HhGebruiker(
      id: record.id,
      naam: record.getStringValue('naam'),
      email: record.getStringValue('email'),
      rol: rol,
      taal: HhTaal.vanCode(record.getStringValue('taal')),
      telefoon: telefoon.isEmpty ? null : telefoon,
      isBevestigd: record.getBoolValue('verified'),
      wijkId: record.getStringValue('wijk'),
      werkgebiedStatus: HhWerkgebiedStatus.vanCode(
        record.getStringValue('werkgebied_status'),
      ),
      postcode: record.getStringValue('postcode'),
      huisnummer: record.getStringValue('huisnummer'),
    );
  }

  HhGebruiker copyWith({
    String? naam,
    String? email,
    HhRol? rol,
    HhTaal? taal,
    String? Function()? telefoon,
    bool? isBevestigd,
    String? wijkId,
    HhWerkgebiedStatus? werkgebiedStatus,
    String? postcode,
    String? huisnummer,
  }) {
    return HhGebruiker(
      id: id,
      naam: naam ?? this.naam,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      taal: taal ?? this.taal,
      telefoon: telefoon != null ? telefoon() : this.telefoon,
      isBevestigd: isBevestigd ?? this.isBevestigd,
      wijkId: wijkId ?? this.wijkId,
      werkgebiedStatus: werkgebiedStatus ?? this.werkgebiedStatus,
      postcode: postcode ?? this.postcode,
      huisnummer: huisnummer ?? this.huisnummer,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhGebruiker &&
      other.id == id &&
      other.naam == naam &&
      other.email == email &&
      other.rol == rol &&
      other.taal == taal &&
      other.telefoon == telefoon &&
      other.isBevestigd == isBevestigd &&
      other.wijkId == wijkId &&
      other.werkgebiedStatus == werkgebiedStatus &&
      other.postcode == postcode &&
      other.huisnummer == huisnummer;

  @override
  int get hashCode => Object.hash(
    id,
    naam,
    email,
    rol,
    taal,
    telefoon,
    isBevestigd,
    wijkId,
    werkgebiedStatus,
    postcode,
    huisnummer,
  );
}

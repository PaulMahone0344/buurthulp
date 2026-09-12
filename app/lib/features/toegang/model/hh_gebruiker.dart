import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

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
  });

  final String id;
  final String naam;
  final String email;
  final HhRol rol;
  final HhTaal taal;
  final String? telefoon;

  /// hh_users.verified: e-mailadres bevestigd via de PocketBase-mail.
  final bool isBevestigd;

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
    );
  }

  HhGebruiker copyWith({
    String? naam,
    String? email,
    HhRol? rol,
    HhTaal? taal,
    String? Function()? telefoon,
    bool? isBevestigd,
  }) {
    return HhGebruiker(
      id: id,
      naam: naam ?? this.naam,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      taal: taal ?? this.taal,
      telefoon: telefoon != null ? telefoon() : this.telefoon,
      isBevestigd: isBevestigd ?? this.isBevestigd,
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
      other.isBevestigd == isBevestigd;

  @override
  int get hashCode =>
      Object.hash(id, naam, email, rol, taal, telefoon, isBevestigd);
}

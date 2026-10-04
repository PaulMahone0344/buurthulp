import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// De eigen gegevens van de oudere uit hh_users die O4 en O12 nodig hebben:
/// naam, telefoon, adres en contactpersoon. Los van [HhGebruiker] (de
/// sessie), zodat M4 het sessiemodel van M2 niet hoeft te wijzigen.
@immutable
class HhGegevens {
  const HhGegevens({
    required this.id,
    required this.naam,
    this.telefoon = '',
    this.adres = '',
    this.huisnummer = '',
    this.toevoeging = '',
    this.postcode = '',
    this.plaats = '',
    this.contactNaam = '',
    this.contactTelefoon = '',
  });

  final String id;
  final String naam;
  final String telefoon;
  final String adres;

  /// ADRES (4 okt): los huisnummer en toevoeging (sinds B1/ADRES op hh_users).
  final String huisnummer;
  final String toevoeging;
  final String postcode;
  final String plaats;
  final String contactNaam;
  final String contactTelefoon;

  /// Veldnamen op de server, ook gebruikt om alleen gewijzigde velden te
  /// sturen.
  static const veldNaam = 'naam';
  static const veldTelefoon = 'telefoon';
  static const veldAdres = 'adres';
  static const veldHuisnummer = 'huisnummer';
  static const veldToevoeging = 'toevoeging';
  static const veldPostcode = 'postcode';
  static const veldPlaats = 'plaats';
  static const veldContactNaam = 'contact_naam';
  static const veldContactTelefoon = 'contact_telefoon';

  factory HhGegevens.vanRecord(RecordModel record) {
    return HhGegevens(
      id: record.id,
      naam: record.getStringValue(veldNaam),
      telefoon: record.getStringValue(veldTelefoon),
      adres: record.getStringValue(veldAdres),
      huisnummer: record.getStringValue(veldHuisnummer),
      toevoeging: record.getStringValue(veldToevoeging),
      postcode: record.getStringValue(veldPostcode),
      plaats: record.getStringValue(veldPlaats),
      contactNaam: record.getStringValue(veldContactNaam),
      contactTelefoon: record.getStringValue(veldContactTelefoon),
    );
  }

  /// Is er een adres bekend om O4 mee voor te vullen?
  bool get heeftAdres =>
      adres.trim().isNotEmpty &&
      postcode.trim().isNotEmpty &&
      plaats.trim().isNotEmpty;

  /// Alle velden als map, zoals de server ze kent.
  Map<String, String> get alsVelden => {
    veldNaam: naam,
    veldTelefoon: telefoon,
    veldAdres: adres,
    veldHuisnummer: huisnummer,
    veldToevoeging: toevoeging,
    veldPostcode: postcode,
    veldPlaats: plaats,
    veldContactNaam: contactNaam,
    veldContactTelefoon: contactTelefoon,
  };

  /// Alleen de velden waarin [nieuw] afwijkt van deze gegevens. Leeg als
  /// er niets is gewijzigd (dan hoeft er niets naar de server).
  Map<String, dynamic> gewijzigdeVelden(Map<String, String> nieuw) {
    final huidig = alsVelden;
    return {
      for (final veld in nieuw.entries)
        if (huidig[veld.key] != veld.value) veld.key: veld.value,
    };
  }

  HhGegevens metVelden(Map<String, dynamic> velden) {
    return HhGegevens(
      id: id,
      naam: (velden[veldNaam] as String?) ?? naam,
      telefoon: (velden[veldTelefoon] as String?) ?? telefoon,
      adres: (velden[veldAdres] as String?) ?? adres,
      huisnummer: (velden[veldHuisnummer] as String?) ?? huisnummer,
      toevoeging: (velden[veldToevoeging] as String?) ?? toevoeging,
      postcode: (velden[veldPostcode] as String?) ?? postcode,
      plaats: (velden[veldPlaats] as String?) ?? plaats,
      contactNaam: (velden[veldContactNaam] as String?) ?? contactNaam,
      contactTelefoon:
          (velden[veldContactTelefoon] as String?) ?? contactTelefoon,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhGegevens &&
      other.id == id &&
      other.naam == naam &&
      other.telefoon == telefoon &&
      other.adres == adres &&
      other.huisnummer == huisnummer &&
      other.toevoeging == toevoeging &&
      other.postcode == postcode &&
      other.plaats == plaats &&
      other.contactNaam == contactNaam &&
      other.contactTelefoon == contactTelefoon;

  @override
  int get hashCode => Object.hash(
    id,
    naam,
    telefoon,
    adres,
    huisnummer,
    toevoeging,
    postcode,
    plaats,
    contactNaam,
    contactTelefoon,
  );
}

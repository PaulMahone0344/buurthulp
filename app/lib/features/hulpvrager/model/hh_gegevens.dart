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
    this.woningType = '',
    this.verdieping = '',
    this.lift = '',
    this.trap = '',
    this.bereikbaarheid = '',
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

  /// Feedbackronde 1 punt F: de woning, zodat de strijder weet wat hem
  /// wacht. Leeg = niet ingevuld. [woningType] is huis, appartement of
  /// anders; [lift] en [trap] zijn ja of nee.
  final String woningType;
  final String verdieping;
  final String lift;
  final String trap;
  final String bereikbaarheid;

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
  static const veldWoningType = 'woning_type';
  static const veldVerdieping = 'verdieping';
  static const veldLift = 'lift';
  static const veldTrap = 'trap';
  static const veldBereikbaarheid = 'bereikbaarheid';

  static const woningHuis = 'huis';
  static const woningAppartement = 'appartement';
  static const woningAnders = 'anders';
  static const ja = 'ja';
  static const nee = 'nee';

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
      woningType: record.getStringValue(veldWoningType),
      verdieping: record.getStringValue(veldVerdieping),
      lift: record.getStringValue(veldLift),
      trap: record.getStringValue(veldTrap),
      bereikbaarheid: record.getStringValue(veldBereikbaarheid),
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
    veldWoningType: woningType,
    veldVerdieping: verdieping,
    veldLift: lift,
    veldTrap: trap,
    veldBereikbaarheid: bereikbaarheid,
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
      woningType: (velden[veldWoningType] as String?) ?? woningType,
      verdieping: (velden[veldVerdieping] as String?) ?? verdieping,
      lift: (velden[veldLift] as String?) ?? lift,
      trap: (velden[veldTrap] as String?) ?? trap,
      bereikbaarheid: (velden[veldBereikbaarheid] as String?) ?? bereikbaarheid,
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
      other.contactTelefoon == contactTelefoon &&
      other.woningType == woningType &&
      other.verdieping == verdieping &&
      other.lift == lift &&
      other.trap == trap &&
      other.bereikbaarheid == bereikbaarheid;

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
    woningType,
    verdieping,
    lift,
    trap,
    bereikbaarheid,
  );
}

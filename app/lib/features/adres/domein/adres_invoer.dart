import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/hh_adres.dart';

/// Pure regels voor postcode, huisnummer en toevoeging, gelijk aan de server
/// (backend/pb_hooks/hh_adres_hulp.js). De server blijft de waarheid; dit is
/// alleen om netjes te vragen en niet onnodig op te zoeken.

/// Opzoeken pas na zoveel rust in het typen.
const adresZoekWachttijd = Duration(milliseconds: 400);

final _postcodePatroon = RegExp(r'^([1-9]\d{3})\s*([A-Za-z]{2})$');
final _huisnummerPatroon = RegExp(r'^\d{1,5}$');
final _toevoegingPatroon = RegExp(
  r'^[A-Za-z0-9](?:[A-Za-z0-9 -]*[A-Za-z0-9])?$',
);

bool isVolledigePostcode(String waarde) =>
    _postcodePatroon.hasMatch(waarde.trim());

/// "4001ma" -> "4001 MA"; anders ongewijzigd (getrimd).
String normaliseerPostcode(String waarde) {
  final m = _postcodePatroon.firstMatch(waarde.trim());
  return m == null
      ? waarde.trim()
      : '${m.group(1)} ${m.group(2)!.toUpperCase()}';
}

bool isGeldigHuisnummer(String waarde) {
  final schoon = waarde.trim();
  return _huisnummerPatroon.hasMatch(schoon) && int.parse(schoon) > 0;
}

/// Leeg mag; anders letters/cijfers, samen hooguit 6 tekens.
bool isGeldigeToevoeging(String waarde) {
  final schoon = waarde.trim().replaceFirst(RegExp(r'^-+'), '').trim();
  if (schoon.isEmpty) return true;
  return schoon.length <= 6 && _toevoegingPatroon.hasMatch(schoon);
}

/// Genoeg ingevuld om op te zoeken.
bool kanZoeken(String postcode, String huisnummer, String toevoeging) =>
    isVolledigePostcode(postcode) &&
    isGeldigHuisnummer(huisnummer) &&
    isGeldigeToevoeging(toevoeging);

/// Heeft een bestaand account een volledig adres (6-tekens-postcode en een
/// huisnummer)? Anders de gele balk "Vul je adres aan".
bool heeftVolledigAdres(String postcode, String huisnummer) =>
    isVolledigePostcode(postcode) && huisnummer.trim().isNotEmpty;

/// Postcode tijdens het typen: eerst hooguit 4 cijfers (niet 0 vooraan),
/// dan hooguit 2 letters in hoofdletters, met een spatie ertussen.
class PostcodeFormatter extends TextInputFormatter {
  const PostcodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cijfers = StringBuffer();
    final letters = StringBuffer();
    for (final teken in newValue.text.toUpperCase().split('')) {
      if (cijfers.length < 4) {
        if (RegExp(r'\d').hasMatch(teken)) cijfers.write(teken);
      } else if (letters.length < 2 && RegExp('[A-Z]').hasMatch(teken)) {
        letters.write(teken);
      }
    }
    final tekst = letters.isEmpty ? '$cijfers' : '$cijfers $letters';
    return TextEditingValue(
      text: tekst,
      selection: TextSelection.collapsed(offset: tekst.length),
    );
  }
}

/// Het adres dat een formulier opslaat: door PDOK bevestigd, of (als PDOK
/// even niet bereikbaar was) alleen wat er getypt is; de server markeert dat
/// dan als "ongecontroleerd".
@immutable
class AdresKeuze {
  const AdresKeuze.bevestigd(HhAdres this.adres)
    : _postcode = '',
      _huisnummer = '',
      _toevoeging = '';

  const AdresKeuze.ongecontroleerd({
    required String postcode,
    required String huisnummer,
    String toevoeging = '',
  }) : adres = null,
       _postcode = postcode,
       _huisnummer = huisnummer,
       _toevoeging = toevoeging;

  final HhAdres? adres;
  final String _postcode;
  final String _huisnummer;
  final String _toevoeging;

  bool get isBevestigd => adres != null;

  String get postcode => adres?.postcode ?? normaliseerPostcode(_postcode);
  String get huisnummer => adres?.huisnummer ?? _huisnummer.trim();
  String get toevoeging => adres?.toevoeging ?? _toevoeging.trim();

  /// De hh_users-velden. Straat en plaats alleen als PDOK ze gaf (de server
  /// overschrijft ze toch; zo klopt het ook met een oudere server).
  Map<String, String> get velden => {
    'postcode': postcode,
    'huisnummer': huisnummer,
    'toevoeging': toevoeging,
    if (adres != null) 'adres': adres!.adres,
    if (adres != null) 'plaats': adres!.plaats,
  };

  @override
  bool operator ==(Object other) =>
      other is AdresKeuze &&
      other.adres == adres &&
      other.postcode == postcode &&
      other.huisnummer == huisnummer &&
      other.toevoeging == toevoeging;

  @override
  int get hashCode => Object.hash(adres, postcode, huisnummer, toevoeging);
}

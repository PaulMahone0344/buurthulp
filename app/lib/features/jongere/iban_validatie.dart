import '../../l10n/teksten_jongere_nl.dart';

/// Nederlandse IBAN: NL + 2 controlecijfers + 4 letters bankcode + 10
/// cijfers, 18 tekens, geldig volgens mod-97 (ISO 7064). Spaties en kleine
/// letters in de invoer zijn toegestaan; [normaliseerIban] haalt ze weg.
const _nlIbanLengte = 18;
final _nlIbanVorm = RegExp(r'^NL\d{2}[A-Z]{4}\d{10}$');

String normaliseerIban(String invoer) =>
    invoer.replaceAll(RegExp(r'\s+'), '').toUpperCase();

bool isGeldigNlIban(String invoer) {
  final iban = normaliseerIban(invoer);
  if (iban.length != _nlIbanLengte || !_nlIbanVorm.hasMatch(iban)) {
    return false;
  }
  return _mod97(iban) == 1;
}

/// Verplaatst de eerste vier tekens naar achteren, zet letters om in
/// getallen (A=10 ... Z=35) en rekent de rest bij deling door 97 uit in
/// stukken, zodat het getal nooit te groot wordt voor een int.
int _mod97(String iban) {
  final herschikt = iban.substring(4) + iban.substring(0, 4);
  final cijfers = StringBuffer();
  for (final teken in herschikt.codeUnits) {
    if (teken >= 0x41 && teken <= 0x5A) {
      cijfers.write(teken - 0x41 + 10);
    } else {
      cijfers.writeCharCode(teken);
    }
  }
  var rest = 0;
  for (final cijfer in cijfers.toString().codeUnits) {
    rest = (rest * 10 + (cijfer - 0x30)) % 97;
  }
  return rest;
}

/// Groepjes van vier voor de weergave: NL91 ABNA 0417 1643 00.
String toonIban(String iban) {
  final schoon = normaliseerIban(iban);
  final delen = <String>[];
  for (var i = 0; i < schoon.length; i += 4) {
    delen.add(
      schoon.substring(i, i + 4 > schoon.length ? schoon.length : i + 4),
    );
  }
  return delen.join(' ');
}

String? valideerIban(String invoer) {
  if (normaliseerIban(invoer).isEmpty) {
    return TekstenJongereNl.validatieIbanVerplicht;
  }
  if (!isGeldigNlIban(invoer)) return TekstenJongereNl.validatieIbanOngeldig;
  return null;
}

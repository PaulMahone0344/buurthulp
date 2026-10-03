import '../../../../l10n/teksten_klussen_nl.dart';

DateTime _dag(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

String _tweeCijfers(int n) => n.toString().padLeft(2, '0');

/// "14:00".
String tijdTekst(DateTime moment) {
  final lokaal = moment.toLocal();
  return '${_tweeCijfers(lokaal.hour)}:${_tweeCijfers(lokaal.minute)}';
}

/// "vandaag", "morgen" of "donderdag 17 september" (lokale dag).
String dagTekst(DateTime moment, DateTime nu) {
  final dag = _dag(moment.toLocal());
  final vandaag = _dag(nu.toLocal());
  if (dag == vandaag) return TekstenKlussenNl.vandaag;
  if (dag == DateTime(vandaag.year, vandaag.month, vandaag.day + 1)) {
    return TekstenKlussenNl.morgen;
  }
  final weekdag = TekstenKlussenNl.weekdagen[dag.weekday - DateTime.monday];
  final maand = TekstenKlussenNl.maanden[dag.month - DateTime.january];
  return '$weekdag ${dag.day} $maand';
}

/// "morgen van 14:00 tot 15:30", "vandaag om 10:00", of leeg zonder
/// begintijd. Alles in lokale tijd; de server bewaart UTC.
String wanneerTekst(DateTime? van, DateTime? tot, DateTime nu) {
  if (van == null) return '';
  final dag = dagTekst(van, nu);
  if (tot == null || !tot.isAfter(van)) {
    return TekstenKlussenNl.wanneerZonderEind(dag, tijdTekst(van));
  }
  return TekstenKlussenNl.wanneerMetTijd(dag, tijdTekst(van), tijdTekst(tot));
}

/// "boodschappen" -> "Boodschappen"; de klustypes op de server zijn klein
/// geschreven en staan hier als kop.
String metHoofdletter(String tekst) {
  if (tekst.isEmpty) return tekst;
  return tekst[0].toUpperCase() + tekst.substring(1);
}

/// Centen -> "€ 10,00".
String euroTekst(int centen) {
  final euro = centen ~/ 100;
  final rest = (centen % 100).toString().padLeft(2, '0');
  return '€ $euro,$rest';
}

/// Wat de helper bij de vergoeding ziet: "Je verdient € 10,00", of
/// "Vergoeding volgt" zolang er nog geen bedrag is (0).
String vergoedingVoorHelper(int centen) => centen <= 0
    ? TekstenKlussenNl.vergoedingVolgt
    : TekstenKlussenNl.vergoeding(euroTekst(centen));

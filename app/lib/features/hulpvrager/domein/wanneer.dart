import '../../../l10n/teksten_klus_nl.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../model/hulpvraag_concept.dart';

/// Alleen de datum van [moment], om middernacht in lokale tijd.
DateTime alleenDag(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// De dag die bij een keuze op O3 hoort. "Morgen" telt via de Dart-
/// datumrekening door over een maand- en jaargrens (31 december + 1 =
/// 1 januari). Voor [HhDagKeuze.andereDag] kiest de gebruiker zelf; deze
/// functie geeft dan null.
DateTime? dagVoorKeuze(HhDagKeuze keuze, DateTime nu) {
  final vandaag = alleenDag(nu);
  return switch (keuze) {
    HhDagKeuze.vandaag => vandaag,
    HhDagKeuze.morgen => DateTime(vandaag.year, vandaag.month, vandaag.day + 1),
    HhDagKeuze.andereDag => null,
  };
}

const _minutenPerUur = 60;

/// De laatste begintijd die het tijdwiel aanbiedt (23:45; kwartieren).
const laatsteVanafMinuten = 23 * _minutenPerUur + 45;

/// Standaard begintijd op een andere dag dan vandaag.
const _standaardVanafMinuten = 10 * _minutenPerUur;

/// Hoeveel hele uren na nu het tijdwiel vandaag begint.
const _urenVooruitVandaag = 2;

/// [dag] om [minuten] na middernacht, lokale tijd.
DateTime momentOp(DateTime dag, int minuten) {
  final d = alleenDag(dag);
  return DateTime(
    d.year,
    d.month,
    d.day,
    minuten ~/ _minutenPerUur,
    minuten % _minutenPerUur,
  );
}

/// Waar het tijdwiel "Vanaf" begint als de dag gekozen wordt: vandaag twee
/// hele uren na nu (hooguit 23:45), een andere dag 10:00.
int standaardVanaf(DateTime dag, DateTime nu) {
  if (alleenDag(dag) != alleenDag(nu)) return _standaardVanafMinuten;
  final minuten = (nu.hour + _urenVooruitVandaag) * _minutenPerUur;
  return minuten > laatsteVanafMinuten ? laatsteVanafMinuten : minuten;
}

/// Een begintijd die al voorbij is heeft geen zin meer.
bool isVoorbij(DateTime dag, int vanafMinuten, DateTime nu) =>
    !momentOp(dag, vanafMinuten).isAfter(nu);

/// "14:00" (24-uursklok).
String tijdTekst(int minuten) {
  String twee(int n) => n.toString().padLeft(2, '0');
  return '${twee(minuten ~/ _minutenPerUur)}:${twee(minuten % _minutenPerUur)}';
}

/// De eerstvolgende [aantal] dagen vanaf vandaag (vandaag meegerekend), voor
/// de eigen dagkiezer op O3.
List<DateTime> komendeDagen(DateTime nu, int aantal) {
  final vandaag = alleenDag(nu);
  return [
    for (var i = 0; i < aantal; i++)
      DateTime(vandaag.year, vandaag.month, vandaag.day + i),
  ];
}

/// "vandaag", "morgen" of "donderdag 17 september".
String dagTekst(DateTime dag, DateTime nu) {
  final d = alleenDag(dag);
  if (d == dagVoorKeuze(HhDagKeuze.vandaag, nu)) {
    return TekstenHulpvragerNl.vandaag;
  }
  if (d == dagVoorKeuze(HhDagKeuze.morgen, nu)) {
    return TekstenHulpvragerNl.morgen;
  }
  return datumTekst(d);
}

/// "donderdag 17 september" (zonder jaar: dat is voor de oudere ruis).
String datumTekst(DateTime dag) {
  final weekdag = TekstenHulpvragerNl.weekdagen[dag.weekday - DateTime.monday];
  final maand = TekstenHulpvragerNl.maanden[dag.month - DateTime.january];
  return '$weekdag ${dag.day} $maand';
}

/// "morgen vanaf 14:00" of "vrijdag 18 september van 09:00 tot 11:30".
String wanneerTekst(DateTime dag, int vanaf, int? tot, DateTime nu) {
  final welkeDag = dagTekst(dag, nu);
  if (tot == null || tot <= vanaf) {
    return TekstenKlusNl.wanneerVanaf(welkeDag, tijdTekst(vanaf));
  }
  return TekstenKlusNl.wanneerVanTot(
    welkeDag,
    tijdTekst(vanaf),
    tijdTekst(tot),
  );
}

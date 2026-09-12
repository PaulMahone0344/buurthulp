import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../model/hulpvraag_concept.dart';

/// Een begin en een eind, lokale tijd.
typedef HhTijdvak = ({DateTime van, DateTime tot});

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

/// Dag plus dagdeel wordt wanneer_van en wanneer_tot.
HhTijdvak tijdvakVoor(DateTime dag, HhDagdeel dagdeel) {
  final d = alleenDag(dag);
  return (
    van: DateTime(d.year, d.month, d.day, dagdeel.vanUur),
    tot: DateTime(d.year, d.month, d.day, dagdeel.totUur),
  );
}

/// Waar: een dagdeel dat helemaal achter ons ligt heeft geen zin meer.
bool isVoorbij(DateTime dag, HhDagdeel dagdeel, DateTime nu) =>
    !tijdvakVoor(dag, dagdeel).tot.isAfter(nu);

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

/// "in de ochtend (van 9 tot 12 uur)".
String dagdeelTekst(HhDagdeel dagdeel) {
  final woord = switch (dagdeel) {
    HhDagdeel.ochtend => TekstenHulpvragerNl.inDeOchtend,
    HhDagdeel.middag => TekstenHulpvragerNl.inDeMiddag,
    HhDagdeel.avond => TekstenHulpvragerNl.inDeAvond,
  };
  return '$woord (${TekstenHulpvragerNl.vanTotUur(dagdeel.vanUur, dagdeel.totUur)})';
}

/// "morgen in de ochtend (van 9 tot 12 uur)", voor O5.
String wanneerTekst(DateTime dag, HhDagdeel dagdeel, DateTime nu) =>
    '${dagTekst(dag, nu)} ${dagdeelTekst(dagdeel)}';

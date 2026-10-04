import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../../jongere/klussen/model/hh_klus.dart';
import '../model/hh_reactie.dart';

/// B5: de regels rond reageren en kiezen die de app zelf toont. De server
/// beslist altijd (hh_reacties_hulp.js); dit spiegelt alleen wat de app
/// vooraf laat zien (vinkje, tip, teksten).

/// De eerste letter van de voornaam, voor de initialen-avatar (geen foto's
/// van mensen). Zonder naam een vraagteken.
String initialen(String voornaam) {
  final t = voornaam.trim();
  if (t.isEmpty) return '?';
  return t.substring(0, 1).toUpperCase();
}

/// "4,8 (12)", of "Nog geen beoordeling".
String sterrenKort(double sterren, int aantal) {
  if (aantal <= 0) return TekstenReactiesNl.nogGeenBeoordeling;
  final tekst = sterren.toStringAsFixed(1).replaceAll('.', ',');
  return TekstenReactiesNl.sterrenAantal(tekst, aantal);
}

/// Leeftijd in hele jaren op [dag] (lokale datum), of null zonder datum.
int? leeftijdOp(DateTime? geboortedatum, DateTime dag) {
  if (geboortedatum == null) return null;
  final g = geboortedatum.toUtc();
  var jaren = dag.year - g.year;
  if (dag.month < g.month || (dag.month == g.month && dag.day < g.day)) {
    jaren--;
  }
  return jaren;
}

/// Statussen waarmee een helper al eens echt bij deze bewoner was (of op
/// weg is). Zelfde regel als de server (isEersteKlusBij).
const _alEensBij = {
  HhKlusStatus.geaccepteerd,
  HhKlusStatus.onderweg,
  HhKlusStatus.bezig,
  HhKlusStatus.afgerond,
  HhKlusStatus.probleem,
};

/// Is dit de eerste klus van de helper bij deze bewoner? Kijkt naar de
/// eigen (toegewezen) klussen van de helper.
bool isEersteKlusBij(List<HhKlus> mijnKlussen, String hulpvragerId) =>
    !mijnKlussen.any(
      (k) => k.hulpvragerId == hulpvragerId && _alEensBij.contains(k.status),
    );

/// Punt 10: helper van 10 t/m 12 jaar, eerste klus bij deze bewoner: het
/// vinkje "Mijn ouder gaat mee" is verplicht.
bool moetOuderMeeVinkje({required int? leeftijd, required bool isEerste}) =>
    isEerste && leeftijd != null && leeftijd >= 10 && leeftijd <= 12;

/// Punt 10: 13 t/m 17 jaar, eerste klus: alleen een tip.
bool toonOuderMeeTip({required int? leeftijd, required bool isEerste}) =>
    isEerste && leeftijd != null && leeftijd >= 13 && leeftijd < 18;

/// Wat het tabblad Gereageerd toont: eerst wat nog loopt (nieuwste eerst),
/// dan wat niet doorging (hooguit [maxAfgelopen]). Gekozen staat bij
/// Gepland (dat is een klus geworden); zelf ingetrokken laat de app weg.
List<HhReactie> gereageerdLijst(
  List<HhReactie> reacties, {
  int maxAfgelopen = 10,
}) {
  int nieuwste(HhReactie a, HhReactie b) {
    final ta = a.gemaakt;
    final tb = b.gemaakt;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  }

  final actief = [
    for (final r in reacties)
      if (r.status.isActief) r,
  ]..sort(nieuwste);
  final afgelopen = [
    for (final r in reacties)
      if (r.status == HhReactieStatus.afgewezen ||
          r.status == HhReactieStatus.vervallen)
        r,
  ]..sort(nieuwste);
  return List.unmodifiable([...actief, ...afgelopen.take(maxAfgelopen)]);
}

/// De stand van een reactie in gewone taal (pil op de tegel).
String reactieStand(HhReactie r) => switch (r.status) {
  HhReactieStatus.wachtOpOuder => TekstenReactiesNl.standWachtOuder,
  HhReactieStatus.open => TekstenReactiesNl.standWachtBewoner,
  HhReactieStatus.afgewezen =>
    r.isDoorOuderAfgewezen
        ? TekstenReactiesNl.standOuderNee
        : TekstenReactiesNl.standNietGekozen,
  HhReactieStatus.vervallen ||
  HhReactieStatus.ingetrokken ||
  HhReactieStatus.gekozen ||
  HhReactieStatus.onbekend => TekstenReactiesNl.standVervallen,
};

/// Kleur van de pil: loopt nog = accent, voorbij = gedempt.
bool reactieLooptNog(HhReactie r) => r.status.isActief;

/// Staat "Ik kan nu helpen" aan?
bool isNuBeschikbaar(DateTime? tot, DateTime nu) =>
    tot != null && tot.isAfter(nu);

/// "15:30" in lokale tijd.
String tijdKort(DateTime moment) {
  final l = moment.toLocal();
  final mm = l.minute < 10 ? '0${l.minute}' : '${l.minute}';
  return '${l.hour}:$mm';
}

/// De kleur van de initialen-avatar: vast per naam, uit de eigen palette
/// (geen gezicht, geen foto).
int avatarKleurIndex(String naam, int aantal) {
  var h = 0;
  for (final c in naam.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return aantal <= 0 ? 0 : h % aantal;
}

/// Achtergrondkleuren voor de avatar (contrast met witte letter >= 4.5).
const avatarKleuren = [
  HhKleuren.primair,
  HhKleuren.info,
  HhKleuren.succes,
  HhKleuren.waarschuwing,
];

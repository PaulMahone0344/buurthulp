import '../../../theme.dart';
import '../../jongere/klussen/model/hh_klus.dart';

/// B10: de periode van "Aankomende klussen" op de Start van de bewoner.
enum AgendaPeriode { dag, week, maand }

DateTime _dag(DateTime m) {
  final l = m.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Statussen die nog moeten gebeuren (geen concept, niet klaar/geannuleerd).
const _komend = {
  HhKlusStatus.open,
  HhKlusStatus.geaccepteerd,
  HhKlusStatus.onderweg,
  HhKlusStatus.bezig,
};

/// Wat nog komt: open of gepland, vandaag of later (een klus zonder datum
/// telt mee, achteraan). Eerstvolgende bovenaan.
List<HhKlus> aankomendeKlussen(List<HhKlus> klussen, DateTime nu) {
  final vandaag = _dag(nu);
  final uit =
      klussen.where((k) {
        if (!_komend.contains(k.status)) return false;
        final van = k.wanneerVan;
        return van == null || !_dag(van).isBefore(vandaag);
      }).toList()..sort((a, b) {
        final x = a.wanneerVan;
        final y = b.wanneerVan;
        if (x == null) return y == null ? 0 : 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
  return List.unmodifiable(uit);
}

/// De zeven dagen (ma t/m zo) van de week waarin [nu] valt.
List<DateTime> weekVan(DateTime nu) {
  final vandaag = _dag(nu);
  final maandag = DateTime(
    vandaag.year,
    vandaag.month,
    vandaag.day - (vandaag.weekday - DateTime.monday),
  );
  return [
    for (var i = 0; i < 7; i++)
      DateTime(maandag.year, maandag.month, maandag.day + i),
  ];
}

/// Valt [klus] in de periode? Dag = [gekozen] dag, week = de week van
/// [gekozen], maand = de kalendermaand van [gekozen]. Zonder datum: alleen in
/// "maand" (dan zie je hem in elk geval ergens).
bool inPeriode(HhKlus klus, AgendaPeriode periode, DateTime gekozen) {
  final van = klus.wanneerVan;
  if (van == null) return periode == AgendaPeriode.maand;
  final d = _dag(van);
  final g = _dag(gekozen);
  return switch (periode) {
    AgendaPeriode.dag => d == g,
    AgendaPeriode.week => weekVan(g).contains(d),
    AgendaPeriode.maand => d.year == g.year && d.month == g.month,
  };
}

/// Hoeveel aankomende klussen er op [dag] vallen (stip in de weekstrook).
int aantalOpDag(List<HhKlus> klussen, DateTime dag) => klussen
    .where((k) => k.wanneerVan != null && _dag(k.wanneerVan!) == _dag(dag))
    .length;

/// Alle nieuwe (open) reacties op de open klussen van de bewoner samen.
int nieuweReacties(List<HhKlus> klussen) => klussen
    .where((k) => k.status == HhKlusStatus.open)
    .fold(0, (som, k) => som + k.reactiesAantal);

/// Het woord bij een aankomende klus (mockup Main): Bevestigd, Zoekt helper,
/// Wordt nagekeken of Bezig.
enum AgendaStatus { bevestigd, zoektHelper, wordtNagekeken, bezig }

AgendaStatus agendaStatus(HhKlus klus) {
  if (klus.status == HhKlusStatus.open) {
    return klus.wordtNagekeken
        ? AgendaStatus.wordtNagekeken
        : AgendaStatus.zoektHelper;
  }
  if (klus.status == HhKlusStatus.onderweg ||
      klus.status == HhKlusStatus.bezig) {
    return AgendaStatus.bezig;
  }
  return AgendaStatus.bevestigd;
}

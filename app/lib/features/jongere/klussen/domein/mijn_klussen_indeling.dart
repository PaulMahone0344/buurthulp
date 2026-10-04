import '../../../../l10n/teksten_reacties_nl.dart';
import '../../../../theme.dart';
import '../model/hh_klus.dart';

/// De drie tabbladen van HMijnKlussen (B5): Gereageerd (reacties die nog
/// lopen, uit hh_reacties), Gepland (klussen waarvoor de bewoner jou koos)
/// en Klaar.
enum MijnKlussenTab {
  gereageerd,
  gepland,
  klaar;

  String get naam => switch (this) {
    MijnKlussenTab.gereageerd => TekstenReactiesNl.tabGereageerd,
    MijnKlussenTab.gepland => TekstenReactiesNl.tabGepland,
    MijnKlussenTab.klaar => TekstenReactiesNl.tabKlaar,
  };
}

/// Statussen waarmee een klus voorbij is, wat de datum ook zegt.
const _voorbij = {
  HhKlusStatus.afgerond,
  HhKlusStatus.geannuleerd,
  HhKlusStatus.probleem,
};

DateTime _dag(DateTime moment) {
  final lokaal = moment.toLocal();
  return DateTime(lokaal.year, lokaal.month, lokaal.day);
}

/// In welk tabblad een (toegewezen) klus van de helper hoort. Klaar als hij
/// afgerond, geannuleerd of probleem is, of als zijn dag (LOKAAL; de server
/// bewaart UTC) voor vandaag ligt. Anders gepland (ook vandaag, en zonder
/// datum). Gereageerd vult het scherm uit de reacties, niet uit de klussen.
MijnKlussenTab indelingVan(HhKlus klus, DateTime nu) {
  if (_voorbij.contains(klus.status)) return MijnKlussenTab.klaar;
  final van = klus.wanneerVan;
  if (van == null) return MijnKlussenTab.gepland;
  if (_dag(van).isBefore(_dag(nu))) return MijnKlussenTab.klaar;
  return MijnKlussenTab.gepland;
}

int _opTijd(HhKlus a, HhKlus b) {
  final ta = a.wanneerVan;
  final tb = b.wanneerVan;
  if (ta == null && tb == null) return 0;
  if (ta == null) return 1;
  if (tb == null) return -1;
  return ta.compareTo(tb);
}

/// Deelt de klussen in per tabblad. Gepland loopt op in de tijd (eerste
/// eerst), klaar loopt af (laatste eerst); gereageerd blijft leeg.
Map<MijnKlussenTab, List<HhKlus>> deelIn(List<HhKlus> klussen, DateTime nu) {
  final per = {for (final tab in MijnKlussenTab.values) tab: <HhKlus>[]};
  for (final klus in klussen) {
    per[indelingVan(klus, nu)]!.add(klus);
  }
  per[MijnKlussenTab.gepland]!.sort(_opTijd);
  per[MijnKlussenTab.klaar]!.sort((a, b) => _opTijd(b, a));
  return {for (final e in per.entries) e.key: List.unmodifiable(e.value)};
}

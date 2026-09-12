import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../theme.dart';
import '../model/hh_klus.dart';

/// De drie tabbladen van J14.
enum MijnKlussenTab {
  vandaag,
  gepland,
  historie;

  String get naam => switch (this) {
    MijnKlussenTab.vandaag => TekstenKlussenNl.j14TabVandaag,
    MijnKlussenTab.gepland => TekstenKlussenNl.j14TabGepland,
    MijnKlussenTab.historie => TekstenKlussenNl.j14TabHistorie,
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

/// In welk tabblad een klus van de jongere hoort. Een klus is historie als
/// hij afgerond, geannuleerd of probleem is, of als zijn dag (LOKAAL; de
/// server bewaart UTC) voor vandaag ligt. Zonder datum en nog actief:
/// gepland.
MijnKlussenTab indelingVan(HhKlus klus, DateTime nu) {
  if (_voorbij.contains(klus.status)) return MijnKlussenTab.historie;
  final van = klus.wanneerVan;
  if (van == null) return MijnKlussenTab.gepland;
  final dag = _dag(van);
  final vandaag = _dag(nu);
  if (dag.isBefore(vandaag)) return MijnKlussenTab.historie;
  if (dag.isAtSameMomentAs(vandaag)) return MijnKlussenTab.vandaag;
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

/// Deelt de klussen in per tabblad. Vandaag en gepland lopen op in de tijd
/// (eerste eerst), historie loopt af (laatste eerst).
Map<MijnKlussenTab, List<HhKlus>> deelIn(List<HhKlus> klussen, DateTime nu) {
  final per = {for (final tab in MijnKlussenTab.values) tab: <HhKlus>[]};
  for (final klus in klussen) {
    per[indelingVan(klus, nu)]!.add(klus);
  }
  per[MijnKlussenTab.vandaag]!.sort(_opTijd);
  per[MijnKlussenTab.gepland]!.sort(_opTijd);
  per[MijnKlussenTab.historie]!.sort((a, b) => _opTijd(b, a));
  return {for (final e in per.entries) e.key: List.unmodifiable(e.value)};
}

import '../../../../l10n/teksten_klussen_nl.dart';

/// De drie dagdelen waarop een helper zijn klussenlijst filtert (J11). Tot
/// B4 koos de bewoner ook een dagdeel; sinds het tijdwiel (B4) staat het
/// enum hier, bij de enige plek die het nog gebruikt.
enum HhDagdeel { ochtend, middag, avond }

/// Grens tussen ochtend en middag, en tussen middag en avond (lokale
/// wandkloktijd). Een klus die om 12:30 begint valt onder de middag.
const _middagVanaf = 12;
const _avondVanaf = 18;

/// Het dagdeel waarin een klus begint, afgeleid van wanneer_van in LOKALE
/// tijd (de server bewaart UTC). Null zonder begintijd.
HhDagdeel? dagdeelVan(DateTime? wanneerVan) {
  if (wanneerVan == null) return null;
  final uur = wanneerVan.toLocal().hour;
  if (uur < _middagVanaf) return HhDagdeel.ochtend;
  if (uur < _avondVanaf) return HhDagdeel.middag;
  return HhDagdeel.avond;
}

String dagdeelNaam(HhDagdeel dagdeel) => switch (dagdeel) {
  HhDagdeel.ochtend => TekstenKlussenNl.dagdeelOchtend,
  HhDagdeel.middag => TekstenKlussenNl.dagdeelMiddag,
  HhDagdeel.avond => TekstenKlussenNl.dagdeelAvond,
};

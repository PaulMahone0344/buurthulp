import '../../../hulpvrager/model/hulpvraag_concept.dart';
import '../../../../l10n/teksten_klussen_nl.dart';

/// Grens tussen ochtend en middag, en tussen middag en avond (lokale
/// wandkloktijd). De oudere kiest op O3 uit 9-12, 13-17 en 18-20; een klus
/// die de meldkamer om 12:30 plant valt hier onder de middag.
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

import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../jongere/klussen/model/hh_klus.dart';
import '../../../../l10n/teksten_klus_nl.dart';

/// De drie tabbladen van O8. Voor de oudere in gewone woorden: wat nog open
/// staat, wat gepland is, en wat klaar is.
enum HulpvraagTab {
  open,
  gepland,
  afgerond;

  String get naam => switch (this) {
    HulpvraagTab.open => TekstenUitvoerenNl.o8TabOpen,
    HulpvraagTab.gepland => TekstenUitvoerenNl.o8TabGepland,
    HulpvraagTab.afgerond => TekstenUitvoerenNl.o8TabAfgerond,
  };
}

/// In welk tabblad een hulpvraag hoort. Puur op status, niet op datum: de
/// oudere denkt in "er komt iemand" of "het is klaar", niet in dagen.
HulpvraagTab indelingVanHulpvraag(HhKlus klus) => switch (klus.status) {
  HhKlusStatus.concept || HhKlusStatus.open => HulpvraagTab.open,
  HhKlusStatus.geaccepteerd ||
  HhKlusStatus.onderweg ||
  HhKlusStatus.bezig => HulpvraagTab.gepland,
  HhKlusStatus.afgerond ||
  HhKlusStatus.geannuleerd ||
  HhKlusStatus.probleem => HulpvraagTab.afgerond,
};

int _opTijd(HhKlus a, HhKlus b) {
  final ta = a.wanneerVan;
  final tb = b.wanneerVan;
  if (ta == null && tb == null) return 0;
  if (ta == null) return 1;
  if (tb == null) return -1;
  return ta.compareTo(tb);
}

/// Deelt de hulpvragen in per tabblad. Open en gepland lopen op in de tijd
/// (eerstvolgende bovenaan), afgerond loopt af (laatste bovenaan).
Map<HulpvraagTab, List<HhKlus>> deelHulpvragenIn(List<HhKlus> klussen) {
  final per = {for (final tab in HulpvraagTab.values) tab: <HhKlus>[]};
  for (final klus in klussen) {
    per[indelingVanHulpvraag(klus)]!.add(klus);
  }
  per[HulpvraagTab.open]!.sort(_opTijd);
  per[HulpvraagTab.gepland]!.sort(_opTijd);
  per[HulpvraagTab.afgerond]!.sort((a, b) => _opTijd(b, a));
  return {for (final e in per.entries) e.key: List.unmodifiable(e.value)};
}

/// De zin die de oudere op O7 en O8 leest, in gewone taal. [voornaam] is
/// leeg zolang er nog niemand gevonden is.
String statusZin(HhKlus klus) {
  final naam = klus.jongereVoornaam;
  // B4: eerst de meldkamer.
  if (klus.wachtOpBelletje) return TekstenKlusNl.wachtOpBelletje;
  if (klus.wordtNagekeken) return TekstenKlusNl.wordtNagekeken;
  if (klus.afkeurReden.isNotEmpty) return TekstenKlusNl.afgekeurd;
  if (naam.isEmpty) {
    return switch (klus.status) {
      HhKlusStatus.concept => TekstenUitvoerenNl.o7Concept,
      HhKlusStatus.geannuleerd => TekstenUitvoerenNl.o7Geannuleerd,
      HhKlusStatus.probleem => TekstenUitvoerenNl.o7Probleem,
      _ => TekstenUitvoerenNl.o7GeenJongere,
    };
  }
  return switch (klus.status) {
    HhKlusStatus.geaccepteerd => TekstenUitvoerenNl.o7Aangenomen(naam),
    HhKlusStatus.onderweg => TekstenUitvoerenNl.o7Onderweg(naam),
    HhKlusStatus.bezig => TekstenUitvoerenNl.o7Bezig(naam),
    HhKlusStatus.afgerond => TekstenUitvoerenNl.o7Afgerond(naam),
    HhKlusStatus.geannuleerd => TekstenUitvoerenNl.o7Geannuleerd,
    HhKlusStatus.probleem => TekstenUitvoerenNl.o7Probleem,
    HhKlusStatus.concept => TekstenUitvoerenNl.o7Concept,
    HhKlusStatus.open => TekstenUitvoerenNl.o7GeenJongere,
  };
}

/// Punt A: de categorie Overig krijgt bij het keuren een eigen uitleg.
bool isOverigeKlus(HhKlus klus) =>
    klus.klustypeNaam.trim().toLowerCase() == 'overig';

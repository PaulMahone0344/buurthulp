import '../../../l10n/teksten_chat_nl.dart';
import '../../../l10n/teksten_meldingen_nl.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../chat/paden_chat.dart';
import '../../coordinator/paden_coordinator.dart';
import '../../hulpvrager/status/paden_status.dart';
import '../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../jongere/klussen/paden_klussen.dart';
import '../../jongere/uitvoeren/paden_uitvoeren.dart';
import '../../reacties/paden_reacties.dart';
import '../../toegang/model/hh_rol.dart';
import '../model/hh_melding.dart';

/// De titel die de app toont. De hook geeft altijd een titel mee; deze
/// terugval per soort en rol is er voor een melding die zonder komt.
String titelVan(HhMelding melding, HhRol rol) {
  if (melding.titel.trim().isNotEmpty) return melding.titel;
  final isOudere = rol == HhRol.hulpvrager;
  return switch (melding.soort) {
    HhMeldingSoort.nieuweKlus => TekstenMeldingenNl.soortNieuweKlus,
    HhMeldingSoort.toegewezen => switch (rol) {
      HhRol.hulpvrager => TekstenMeldingenNl.soortToegewezenOudere,
      HhRol.jongere => TekstenMeldingenNl.soortToegewezenJongere,
      _ => TekstenMeldingenNl.soortToegewezenAnder,
    },
    HhMeldingSoort.onderweg =>
      isOudere
          ? TekstenMeldingenNl.soortOnderwegOudere
          : TekstenMeldingenNl.soortOnderwegAnder,
    HhMeldingSoort.afgerond =>
      rol == HhRol.jongere
          ? TekstenMeldingenNl.soortAfgerondJongere
          : TekstenMeldingenNl.soortAfgerondOudere,
    HhMeldingSoort.geannuleerd =>
      rol == HhRol.jongere
          ? TekstenMeldingenNl.soortGeannuleerdJongere
          : TekstenMeldingenNl.soortGeannuleerdOudere,
    HhMeldingSoort.incident => TekstenMeldingenNl.soortIncident,
    HhMeldingSoort.bericht => TekstenChatNl.meldingTitel,
    HhMeldingSoort.reactie => TekstenReactiesNl.kiesTitel,
    HhMeldingSoort.onbekend => TekstenMeldingenNl.soortOnbekend,
  };
}

/// Waar een tik op de melding naartoe gaat, of null als er geen scherm bij
/// hoort.
String? doelVan(HhMelding melding, HhRol rol) {
  final klus = melding.klusId;
  // B6: een chatbericht opent de chat (bewoner en helper).
  if (melding.soort == HhMeldingSoort.bericht &&
      klus.isNotEmpty &&
      (rol == HhRol.jongere || rol == HhRol.hulpvrager)) {
    return HhPadenChat.chat(klus);
  }
  // B5: een reactie-melding. De bewoner gaat naar KiesHelper (zolang de klus
  // open is laat dat scherm de helpers zien), de helper naar Mijn klussen.
  if (melding.soort == HhMeldingSoort.reactie) {
    if (rol == HhRol.hulpvrager && klus.isNotEmpty) {
      return HhPadenReacties.kies(klus);
    }
    if (rol == HhRol.jongere) return HhPadenKlussen.mijnKlussen;
  }
  switch (rol) {
    case HhRol.jongere:
      if (klus.isEmpty) return null;
      return switch (melding.soort) {
        HhMeldingSoort.toegewezen ||
        HhMeldingSoort.onderweg ||
        HhMeldingSoort.afgerond => HhPadenUitvoeren.uitvoeren(klus),
        _ => HhPadenKlussen.klusDetail(klus),
      };
    case HhRol.hulpvrager:
      return klus.isEmpty ? null : HhPadenStatus.hulpvraag(klus);
    case HhRol.coordinator:
      if (melding.incidentId.isNotEmpty) {
        return HhPadenCoordinator.incidentDetail(melding.incidentId);
      }
      return klus.isEmpty ? null : HhPadenCoordinator.klusDetail(klus);
  }
}

int ongelezenAantal(List<HhMelding> meldingen) =>
    meldingen.where((m) => !m.isGelezen).length;

/// Een melding uit realtime in de lijst zetten: een bestaande (zelfde id)
/// wordt vervangen, een nieuwe erbij; nieuwste bovenaan.
List<HhMelding> voegIn(List<HhMelding> lijst, HhMelding melding) {
  final nieuw = [
    for (final m in lijst)
      if (m.id != melding.id) m,
    melding,
  ];
  nieuw.sort((a, b) {
    final ta = a.gemaakt;
    final tb = b.gemaakt;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  });
  return List.unmodifiable(nieuw);
}

/// "vandaag 10:05" of "zondag 13 september 09:00", in lokale tijd.
String meldingTijd(DateTime moment, DateTime nu) =>
    TekstenMeldingenNl.tijd(dagTekst(moment, nu), tijdTekst(moment));

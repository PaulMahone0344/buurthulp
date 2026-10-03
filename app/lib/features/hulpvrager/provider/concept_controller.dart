import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/teksten_klus_nl.dart';
import '../../jongere/foto_kiezer.dart';
import '../domein/wanneer.dart';
import '../model/hh_klustype.dart';
import '../model/hulpvraag_concept.dart';
import 'hulpvrager_providers.dart';

/// Hoeveel minuten de eindtijd standaard na de begintijd ligt.
const _standaardDuurMinuten = 60;

/// De ene bron van waarheid voor de klus in wording op "Klus plaatsen".
/// Elk deel van de pagina zet zijn eigen stukje; [wis] na het plaatsen of
/// het verlaten.
class ConceptController extends Notifier<HulpvraagConcept> {
  @override
  HulpvraagConcept build() => const HulpvraagConcept();

  void kiesKlustype(HhKlustype klustype) {
    state = state.copyWith(klustype: () => klustype);
  }

  /// Hooguit [TekstenKlusNl.omschrijvingMax] tekens; de rest valt weg.
  void zetOmschrijving(String tekst) {
    final max = TekstenKlusNl.omschrijvingMax;
    state = state.copyWith(
      omschrijving: tekst.length > max ? tekst.substring(0, max) : tekst,
    );
  }

  void zetFoto(HhFoto? foto) => state = state.copyWith(foto: () => foto);

  /// Vandaag of morgen: de dag volgt uit de klok. Een andere dag komt
  /// apart via [kiesDag].
  void kiesDagKeuze(HhDagKeuze keuze) {
    final dag = dagVoorKeuze(keuze, ref.read(klokProvider)());
    _zetDag(keuze, dag ?? (keuze == HhDagKeuze.andereDag ? state.dag : null));
  }

  void kiesDag(DateTime dag) => _zetDag(HhDagKeuze.andereDag, alleenDag(dag));

  /// Bij de eerste dag krijgt het tijdwiel een begintijd; een gekozen tijd
  /// blijft staan als je daarna een andere dag kiest.
  void _zetDag(HhDagKeuze keuze, DateTime? dag) {
    final vanaf =
        state.vanafMinuten ??
        (dag == null ? null : standaardVanaf(dag, ref.read(klokProvider)()));
    state = state.copyWith(
      dagKeuze: () => keuze,
      dag: () => dag,
      vanafMinuten: () => vanaf,
    );
  }

  void zetVanaf(int minuten) {
    state = state.copyWith(vanafMinuten: () => minuten);
  }

  /// Aan: de eindtijd begint een uur na de begintijd (hooguit 23:45).
  void zetEindtijd(bool aan) {
    final vanaf = state.vanafMinuten;
    final tot =
        state.totMinuten ??
        (vanaf == null
            ? null
            : (vanaf + _standaardDuurMinuten).clamp(0, laatsteVanafMinuten));
    state = state.copyWith(heeftEindtijd: aan, totMinuten: () => tot);
  }

  void zetTot(int minuten) {
    state = state.copyWith(totMinuten: () => minuten);
  }

  void zetNeeLijstAkkoord(bool akkoord) {
    state = state.copyWith(isNeeLijstAkkoord: akkoord);
  }

  void zetWaar({
    required String adres,
    required String postcode,
    required String plaats,
  }) {
    state = state.copyWith(
      adres: () => adres,
      postcode: () => postcode,
      plaats: () => plaats,
    );
  }

  void wis() => state = const HulpvraagConcept();
}

final conceptProvider = NotifierProvider<ConceptController, HulpvraagConcept>(
  ConceptController.new,
);

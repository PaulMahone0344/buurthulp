import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domein/wanneer.dart';
import '../model/hh_klustype.dart';
import '../model/hulpvraag_concept.dart';
import 'hulpvrager_providers.dart';

/// De ene bron van waarheid voor de hulpvraag in wording (O2-O5). Elke
/// stap zet zijn eigen stukje; terug-navigatie leest gewoon de state, dus
/// er gaat niets verloren. [wis] na het versturen of het verlaten.
class ConceptController extends Notifier<HulpvraagConcept> {
  @override
  HulpvraagConcept build() => const HulpvraagConcept();

  void kiesKlustype(HhKlustype klustype) {
    state = state.copyWith(klustype: () => klustype);
  }

  /// Vandaag of morgen: de dag volgt uit de klok. Een andere dag komt
  /// apart via [kiesDag].
  void kiesDagKeuze(HhDagKeuze keuze) {
    final dag = dagVoorKeuze(keuze, ref.read(klokProvider)());
    state = state.copyWith(
      dagKeuze: () => keuze,
      dag: () => dag ?? (keuze == HhDagKeuze.andereDag ? state.dag : null),
    );
  }

  void kiesDag(DateTime dag) {
    state = state.copyWith(
      dagKeuze: () => HhDagKeuze.andereDag,
      dag: () => alleenDag(dag),
    );
  }

  void kiesDagdeel(HhDagdeel dagdeel) {
    state = state.copyWith(dagdeel: () => dagdeel);
  }

  void zetWaar({
    required String adres,
    required String postcode,
    required String plaats,
    required String toelichting,
  }) {
    state = state.copyWith(
      adres: () => adres,
      postcode: () => postcode,
      plaats: () => plaats,
      toelichting: toelichting,
    );
  }

  void wis() => state = const HulpvraagConcept();
}

final conceptProvider = NotifierProvider<ConceptController, HulpvraagConcept>(
  ConceptController.new,
);

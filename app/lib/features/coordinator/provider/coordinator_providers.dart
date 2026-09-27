import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/coordinator_gateway.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/result.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/incident_lijst.dart';
import '../domein/kandidaat_sortering.dart';
import '../model/hh_coordinator_klus.dart';
import '../model/hh_incident.dart';
import '../model/hh_kandidaat.dart';

/// De echte coordinator-gateway; tests overriden hem met een
/// [FakeCoordinatorGateway]. Staat hier en niet in gateway_providers.dart,
/// zodat M10 dat gedeelde bestand niet hoeft te raken (zelfde keuze als M4
/// en M5).
final coordinatorGatewayProvider = Provider<CoordinatorGateway>(
  (ref) => PocketBaseCoordinatorGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// Het trilsignaal bij een noodmelding. Losse provider zodat tests hem
/// vervangen en er nooit een plugin-aanroep in een test zit.
final trilProvider = Provider<Future<void> Function()>(
  (ref) => HapticFeedback.heavyImpact,
);

/// Alleen een ingelogde coordinator haalt iets op; anders leeg zonder
/// verzoek naar de server.
bool _isCoordinator(Ref ref) =>
    ref.watch(huidigeGebruikerProvider)?.rol == HhRol.coordinator;

Future<T> _uit<T>(Ref ref, Future<Result<T>> Function() actie) async {
  final result = await actie();
  switch (result) {
    case Ok<T>(:final waarde):
      return waarde;
    case Err<T>(:final fout):
      if (fout.soort == HhFoutSoort.nietIngelogd) {
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      }
      throw fout;
  }
}

/// Alle meldingen (C1), met de realtime-verbinding erop. Een nieuwe rij van
/// de server komt binnen enkele seconden bovenaan te staan zonder dat de
/// coordinator iets doet; bij een noodmelding trilt het toestel.
///
/// Echte push naar een GESLOTEN app hoort bij M8 laag 2 en is er nog niet
/// (OPEN-PUNTEN-M10 punt 1): dit werkt zolang de app open staat.
class IncidentenController extends AsyncNotifier<List<HhIncident>> {
  StreamSubscription<IncidentWijziging>? _abonnement;

  @override
  Future<List<HhIncident>> build() async {
    if (!_isCoordinator(ref)) return const [];
    ref.onDispose(() {
      _abonnement?.cancel();
      _abonnement = null;
    });
    _luister();
    return _uit(ref, () => ref.read(coordinatorGatewayProvider).incidenten());
  }

  void _luister() {
    _abonnement?.cancel();
    _abonnement = ref
        .read(coordinatorGatewayProvider)
        .incidentStroom()
        .listen(
          _verwerk,
          // Een haperende verbinding mag de lijst nooit leegmaken; de
          // coordinator houdt wat hij had en kan verversen.
          onError: (Object _) {},
        );
  }

  void _verwerk(IncidentWijziging wijziging) {
    final huidige = state.value;
    if (huidige == null) return;
    if (wijziging.soort == IncidentWijzigingSoort.verwijderd) {
      state = AsyncData(zonderIncident(huidige, wijziging.id));
      return;
    }
    final incident = wijziging.incident;
    if (incident == null) return;
    final isNieuw = !huidige.any((bestaand) => bestaand.id == incident.id);
    state = AsyncData(metIncident(huidige, incident));
    if (isNieuw && incident.isNood && !incident.isAfgehandeld) {
      unawaited(ref.read(trilProvider)());
    }
  }

  Future<void> vernieuw() async {
    if (!_isCoordinator(ref)) return;
    state = await AsyncValue.guard(
      () => _uit(ref, () => ref.read(coordinatorGatewayProvider).incidenten()),
    );
  }

  /// Zet de afhandeling (C1-detail). De lijst neemt de nieuwe rij meteen
  /// over, zodat het tabblad en de filter kloppen zonder extra verzoek.
  Future<Result<HhIncident>> handelAf(String id, String afhandeling) async {
    final result = await ref
        .read(coordinatorGatewayProvider)
        .handelAf(id, afhandeling);
    switch (result) {
      case Ok<HhIncident>(:final waarde):
        final huidige = state.value;
        if (huidige != null) state = AsyncData(metIncident(huidige, waarde));
      case Err<HhIncident>(:final fout):
        if (fout.soort == HhFoutSoort.nietIngelogd) {
          await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
        }
    }
    return result;
  }
}

final incidentenProvider =
    AsyncNotifierProvider<IncidentenController, List<HhIncident>>(
      IncidentenController.new,
    );

/// Welke meldingen C1 laat zien.
class IncidentFilterController extends Notifier<IncidentFilter> {
  @override
  IncidentFilter build() => IncidentFilter.open;

  void zet(IncidentFilter filter) => state = filter;
}

final incidentFilterProvider =
    NotifierProvider<IncidentFilterController, IncidentFilter>(
      IncidentFilterController.new,
    );

/// De meldingen na de filterbalk: wat de lijst toont.
final gefilterdeIncidentenProvider = Provider<AsyncValue<List<HhIncident>>>((
  ref,
) {
  final filter = ref.watch(incidentFilterProvider);
  return ref
      .watch(incidentenProvider)
      .whenData((incidenten) => filterIncidenten(incidenten, filter));
});

/// Het enige getal in de app van de coordinator: hoeveel meldingen er nog
/// open staan, als teller op het tabblad.
final openIncidentenTellerProvider = Provider<int>((ref) {
  return switch (ref.watch(incidentenProvider)) {
    AsyncData<List<HhIncident>>(:final value) => telOpenIncidenten(value),
    _ => 0,
  };
});

/// Eén melding voor het detail; komt uit de lijst die er al is, zodat een
/// tik geen extra verzoek kost en de realtime-wijziging meteen doorwerkt.
final incidentProvider = Provider.family<HhIncident?, String>((ref, id) {
  final incidenten = ref.watch(incidentenProvider).value;
  if (incidenten == null) return null;
  for (final incident in incidenten) {
    if (incident.id == id) return incident;
  }
  return null;
});

/// De open klussen, oudste eerst (C2).
class CoordinatorKlussenController
    extends AsyncNotifier<List<HhCoordinatorKlus>> {
  @override
  Future<List<HhCoordinatorKlus>> build() async {
    if (!_isCoordinator(ref)) return const [];
    return _uit(ref, () => ref.read(coordinatorGatewayProvider).openKlussen());
  }

  Future<void> vernieuw() async {
    if (!_isCoordinator(ref)) return;
    state = await AsyncValue.guard(
      () => _uit(ref, () => ref.read(coordinatorGatewayProvider).openKlussen()),
    );
  }
}

final coordinatorKlussenProvider =
    AsyncNotifierProvider<
      CoordinatorKlussenController,
      List<HhCoordinatorKlus>
    >(CoordinatorKlussenController.new);

/// Eén klus voor het C2-detail. Wordt na koppelen en vrijgeven ongeldig
/// gemaakt, zodat het scherm de nieuwe status en de jongere toont.
final coordinatorKlusProvider = FutureProvider.autoDispose
    .family<HhCoordinatorKlus, String>((ref, id) {
      return _uit(ref, () => ref.read(coordinatorGatewayProvider).klus(id));
    });

/// De goedgekeurde jongeren voor de koppellijst.
final kandidatenProvider = FutureProvider<List<HhKandidaat>>((ref) {
  if (!_isCoordinator(ref)) return Future.value(const []);
  return _uit(
    ref,
    () => ref.read(coordinatorGatewayProvider).goedgekeurdeJongeren(),
  );
});

/// Het zoekwoord in de koppellijst.
class KandidaatZoekController extends Notifier<String> {
  @override
  String build() => '';

  void zet(String zoek) => state = zoek;
  void wis() => state = '';
}

final kandidaatZoekProvider =
    NotifierProvider<KandidaatZoekController, String>(
      KandidaatZoekController.new,
    );

/// De koppellijst voor één klus: gezocht op naam, eigen wijk eerst.
final kandidatenVoorKlusProvider = Provider.family<
  AsyncValue<List<HhKandidaat>>,
  String
>((ref, wijkId) {
  final zoek = ref.watch(kandidaatZoekProvider);
  return ref
      .watch(kandidatenProvider)
      .whenData((lijst) => kandidatenVoorKlus(lijst, wijkId, zoek));
});

/// Koppelen (C2). Na een 200 worden het detail en de lijst ververst; na een
/// weigering alleen de lijst, zodat het detail met de melding blijft staan.
Future<KoppelUitkomst> koppelKlus(
  Ref ref,
  String klusId,
  String jongereId,
) async {
  final uitkomst = await ref
      .read(coordinatorGatewayProvider)
      .koppelen(klusId, jongereId);
  await _naAfloop(ref, klusId, uitkomst);
  return uitkomst;
}

/// Vrijgeven (C2). Zelfde afhandeling: de klus staat daarna weer open en
/// komt dus terug in de lijst.
Future<KoppelUitkomst> geefKlusVrij(
  Ref ref,
  String klusId,
  String reden,
) async {
  final uitkomst = await ref
      .read(coordinatorGatewayProvider)
      .vrijgeven(klusId, reden);
  await _naAfloop(ref, klusId, uitkomst);
  return uitkomst;
}

Future<void> _naAfloop(
  Ref ref,
  String klusId,
  KoppelUitkomst uitkomst,
) async {
  switch (uitkomst) {
    case KoppelGelukt():
      ref.invalidate(coordinatorKlusProvider(klusId));
      ref.invalidate(coordinatorKlussenProvider);
    case KoppelGeweigerd():
      ref.invalidate(coordinatorKlusProvider(klusId));
      ref.invalidate(coordinatorKlussenProvider);
    case KoppelFout(:final fout):
      if (fout.soort == HhFoutSoort.nietIngelogd) {
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      }
  }
}

final koppelProvider =
    Provider<Future<KoppelUitkomst> Function(String, String)>(
      (ref) => (klusId, jongereId) => koppelKlus(ref, klusId, jongereId),
    );

final vrijgeefProvider =
    Provider<Future<KoppelUitkomst> Function(String, String)>(
      (ref) => (klusId, reden) => geefKlusVrij(ref, klusId, reden),
    );

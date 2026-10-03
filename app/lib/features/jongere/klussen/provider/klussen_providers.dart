import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/hh_fout.dart';
import '../../../../core/pb/fake_klussen_gateway.dart';
import '../../../../core/pb/gateway_providers.dart';
import '../../../../core/pb/klussen_gateway.dart';
import '../../../../core/result.dart';
import '../domein/dagdeel.dart';
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../model/screening_stap.dart';
import '../../provider/screening_providers.dart';
import '../domein/klus_filter.dart';
import '../model/hh_klus.dart';

/// De echte klussen-gateway; tests overriden hem met een
/// [FakeKlussenGateway]. Staat hier en niet in gateway_providers.dart, zodat
/// M5 dat gedeelde bestand niet hoeft te raken (zelfde keuze als M4).
final klussenGatewayProvider = Provider<KlussenGateway>(
  (ref) => PocketBaseKlussenGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// Tegels van de kaart (J12). De echte app haalt ze van OpenStreetMap;
/// tests geven een provider mee die geen netwerk raakt.
final kaartTegelsProvider = Provider<TileProvider Function()>(
  (ref) => NetworkTileProvider.new,
);

/// Alleen een ingelogde jongere heeft klussen; anders leeg zonder verzoek.
String? _jongereId(Ref ref) {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null || gebruiker.rol != HhRol.jongere) return null;
  return gebruiker.id;
}

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

/// De open klussen in de wijk van de jongere (J11/J12). Een [HhFout] wordt
/// een AsyncError; de schermen tonen fout.melding.
class OpenKlussenController extends AsyncNotifier<List<HhKlus>> {
  @override
  Future<List<HhKlus>> build() async {
    if (_jongereId(ref) == null) return const [];
    return _uit(ref, () => ref.read(klussenGatewayProvider).openKlussen());
  }

  /// Pull-to-refresh en na een 409: opnieuw van de server.
  Future<void> vernieuw() async {
    if (_jongereId(ref) == null) return;
    state = await AsyncValue.guard(
      () => _uit(ref, () => ref.read(klussenGatewayProvider).openKlussen()),
    );
  }
}

final openKlussenProvider =
    AsyncNotifierProvider<OpenKlussenController, List<HhKlus>>(
      OpenKlussenController.new,
    );

/// De klussen die aan de jongere zijn toegewezen (J14).
class MijnKlussenController extends AsyncNotifier<List<HhKlus>> {
  @override
  Future<List<HhKlus>> build() async {
    final id = _jongereId(ref);
    if (id == null) return const [];
    return _uit(ref, () => ref.read(klussenGatewayProvider).mijnKlussen(id));
  }

  Future<void> vernieuw() async {
    final id = _jongereId(ref);
    if (id == null) return;
    state = await AsyncValue.guard(
      () => _uit(ref, () => ref.read(klussenGatewayProvider).mijnKlussen(id)),
    );
  }
}

final mijnKlussenProvider =
    AsyncNotifierProvider<MijnKlussenController, List<HhKlus>>(
      MijnKlussenController.new,
    );

/// Een klus voor J13. Wordt na accepteren ongeldig gemaakt zodat het scherm
/// naam en adres van de oudere ophaalt.
final klusDetailProvider = FutureProvider.autoDispose.family<HhKlus, String>((
  ref,
  id,
) {
  return _uit(ref, () => ref.read(klussenGatewayProvider).klus(id));
});

/// De filterbalk van J11. Blijft staan als de jongere naar J13 en terug gaat.
class KlusFilterController extends Notifier<KlusFilter> {
  @override
  KlusFilter build() => const KlusFilter();

  void zetKlustypes(Set<String> ids) =>
      state = state.copyWith(klustypeIds: Set.unmodifiable(ids));

  void zetDagdelen(Set<HhDagdeel> dagdelen) =>
      state = state.copyWith(dagdelen: Set.unmodifiable(dagdelen));

  void wis() => state = const KlusFilter();
}

final klusFilterProvider = NotifierProvider<KlusFilterController, KlusFilter>(
  KlusFilterController.new,
);

/// De straal uit het profiel van de jongere (J6); 0 zolang het profiel
/// laadt of niet kon laden (dan geen straalfilter).
final straalKmProvider = Provider<int>((ref) {
  return switch (ref.watch(screeningControllerProvider)) {
    AsyncData<ScreeningGegevens>(:final value) => value.profiel?.straalKm ?? 0,
    _ => 0,
  };
});

/// Open klussen na filterbalk en straal: wat lijst en kaart tonen.
final gefilterdeKlussenProvider = Provider<AsyncValue<GefilterdeKlussen>>((
  ref,
) {
  final filter = ref.watch(klusFilterProvider);
  final straal = ref.watch(straalKmProvider);
  return ref
      .watch(openKlussenProvider)
      .whenData((klussen) => filterKlussen(klussen, filter, straalKm: straal));
});

/// Accepteren (J13). Na een 200 worden het detail (naam en adres van de
/// oudere komen nu mee) en beide lijsten ververst. Na een weigering (409:
/// iemand anders was eerder) alleen de lijsten: het detail blijft staan
/// met de melding erboven; de klus zelf is voor deze jongere niet meer
/// op te halen (rule geeft 404).
Future<AccepteerUitkomst> accepteerKlus(Ref ref, String klusId) async {
  final uitkomst = await ref.read(klussenGatewayProvider).accepteren(klusId);
  switch (uitkomst) {
    case Geaccepteerd():
      ref.invalidate(klusDetailProvider(klusId));
      ref.invalidate(openKlussenProvider);
      ref.invalidate(mijnKlussenProvider);
    case Geweigerd():
      ref.invalidate(openKlussenProvider);
      ref.invalidate(mijnKlussenProvider);
    case AccepteerFout(:final fout):
      if (fout.soort == HhFoutSoort.nietIngelogd) {
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      }
  }
  return uitkomst;
}

final accepteerProvider = Provider<Future<AccepteerUitkomst> Function(String)>(
  (ref) =>
      (id) => accepteerKlus(ref, id),
);

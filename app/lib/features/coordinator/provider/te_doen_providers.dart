import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/pb/meldkamer_gateway.dart';
import '../../../core/result.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../model/hh_te_doen.dart';

/// B11: de echte meldkamer-gateway; tests overriden hem met een
/// [FakeMeldkamerGateway].
final meldkamerGatewayProvider = Provider<MeldkamerGateway>(
  (ref) => PocketBaseMeldkamerGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// Tabblad "Te doen": bellen, helpers keuren, ouders vrijgeven, klussen
/// keuren. Alleen een ingelogde coordinator haalt iets op. Na elke gelukte
/// handeling wordt de lijst opnieuw geladen (de server is de waarheid).
class TeDoenController extends AsyncNotifier<HhTeDoen> {
  bool get _isCoordinator =>
      ref.read(huidigeGebruikerProvider)?.rol == HhRol.coordinator;

  @override
  Future<HhTeDoen> build() async {
    if (ref.watch(huidigeGebruikerProvider)?.rol != HhRol.coordinator) {
      return const HhTeDoen();
    }
    return _laad();
  }

  Future<HhTeDoen> _laad() async {
    final result = await ref.read(meldkamerGatewayProvider).teDoen();
    switch (result) {
      case Ok<HhTeDoen>(:final waarde):
        return waarde;
      case Err<HhTeDoen>(:final fout):
        await _misschienVerlopen(fout);
        throw fout;
    }
  }

  Future<void> vernieuw() async {
    if (!_isCoordinator) return;
    state = await AsyncValue.guard(_laad);
  }

  Future<void> _misschienVerlopen(HhFout fout) async {
    if (fout.soort == HhFoutSoort.nietIngelogd) {
      await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
    }
  }

  /// Voert een handeling uit; bij Ok de lijst verversen.
  Future<Result<T>> _doe<T>(
    Future<Result<T>> Function(MeldkamerGateway) actie,
  ) async {
    final result = await actie(ref.read(meldkamerGatewayProvider));
    switch (result) {
      case Ok<T>():
        await vernieuw();
      case Err<T>(:final fout):
        await _misschienVerlopen(fout);
    }
    return result;
  }

  Future<Result<KennismakingUitkomst>> kennismaking(
    String bewonerId,
    KennismakingBesluit besluit,
    String notitie,
  ) => _doe((g) => g.kennismaking(bewonerId, besluit, notitie));

  Future<Result<void>> beoordeelHelper(
    String profielId, {
    required bool goedkeuren,
    required String notitie,
  }) => _doe(
    (g) =>
        g.beoordeelHelper(profielId, goedkeuren: goedkeuren, notitie: notitie),
  );

  Future<Result<void>> ouderVrijgeven(String helperId) =>
      _doe((g) => g.ouderVrijgeven(helperId));

  Future<Result<void>> keurKlus(
    String klusId, {
    required bool goedkeuren,
    String reden = '',
  }) => _doe((g) => g.keurKlus(klusId, goedkeuren: goedkeuren, reden: reden));
}

final teDoenProvider = AsyncNotifierProvider<TeDoenController, HhTeDoen>(
  TeDoenController.new,
);

/// Het getal naast het tabblad "Te doen" (0 = geen getal).
final teDoenTellerProvider = Provider<int>(
  (ref) => ref.watch(teDoenProvider).value?.totaal ?? 0,
);

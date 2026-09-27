import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/pb/meldingen_gateway.dart';
import '../../../core/pb/push_registratie.dart';
import '../../../core/result.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../toegang/provider/sessie_providers.dart';
import '../domein/melding_domein.dart';
import '../model/hh_melding.dart';

/// De echte meldingen-gateway; tests overriden hem met een
/// [FakeMeldingenGateway]. Staat hier en niet in gateway_providers.dart, zodat
/// M8 dat gedeelde bestand niet hoeft te raken (zelfde keuze als M5-M7).
final meldingenGatewayProvider = Provider<MeldingenGateway>(
  (ref) => PocketBaseMeldingenGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// Laag 2 (push naar het toestel) is niet gebouwd: tot die tijd de lege
/// registratie. Laag 2 wisselt alleen deze provider.
final pushRegistratieProvider = Provider<PushRegistratie>(
  (ref) => const LegePushRegistratie(),
);

/// De opslag in hh_push_tokens, klaar voor laag 2. Laag 1 gebruikt hem niet.
final pushTokenOpslagProvider = Provider<PushTokenOpslag>(
  (ref) => PocketBasePushTokenOpslag(ref.watch(pocketBaseGatewayProvider)),
);

/// De meldingen van de ingelogde gebruiker, live gevolgd. Een melding die
/// de hook maakt, komt via realtime binnen en staat meteen bovenaan. Zonder
/// sessie leeg, zonder verzoek.
class MeldingenController extends AsyncNotifier<List<HhMelding>> {
  @override
  Future<List<HhMelding>> build() async {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    if (gebruiker == null) return const [];
    final gateway = ref.watch(meldingenGatewayProvider);

    final abonnement = gateway.volg(gebruiker.id).listen((melding) {
      final huidige = state.value;
      if (huidige != null) state = AsyncData(voegIn(huidige, melding));
    }, onError: (Object _) {});
    ref.onDispose(abonnement.cancel);

    return _laad(gebruiker.id);
  }

  Future<List<HhMelding>> _laad(String ontvangerId) async {
    final result = await ref
        .read(meldingenGatewayProvider)
        .meldingen(ontvangerId);
    switch (result) {
      case Ok<List<HhMelding>>(:final waarde):
        return List.unmodifiable(waarde);
      case Err<List<HhMelding>>(:final fout):
        if (fout.soort == HhFoutSoort.nietIngelogd) {
          await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
        }
        throw fout;
    }
  }

  /// Pull-to-refresh en "opnieuw proberen".
  Future<void> vernieuw() async {
    final gebruiker = ref.read(huidigeGebruikerProvider);
    if (gebruiker == null) return;
    state = await AsyncValue.guard(() => _laad(gebruiker.id));
  }

  /// Zet gelezen_op. Mislukt het, dan blijft de stip gewoon staan; de tik
  /// gaat toch door naar de klus.
  Future<void> markeerGelezen(HhMelding melding) async {
    if (melding.isGelezen) return;
    final nu = ref.read(klokProvider)();
    final result = await ref
        .read(meldingenGatewayProvider)
        .markeerGelezen(melding.id, nu);
    if (result case Ok<HhMelding>(:final waarde)) {
      final huidige = state.value;
      if (huidige != null) state = AsyncData(voegIn(huidige, waarde));
    }
  }
}

final meldingenProvider =
    AsyncNotifierProvider<MeldingenController, List<HhMelding>>(
      MeldingenController.new,
    );

/// Voor het belletje. Zolang de lijst laadt of niet laadt: 0.
final ongelezenAantalProvider = Provider<int>(
  (ref) => ongelezenAantal(ref.watch(meldingenProvider).value ?? const []),
);

/// Voor de regel bovenaan O1: de nieuwste melding, of null.
final laatsteMeldingProvider = Provider<HhMelding?>((ref) {
  final lijst = ref.watch(meldingenProvider).value ?? const <HhMelding>[];
  return lijst.isEmpty ? null : lijst.first;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/chat_gateway.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/result.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../toegang/provider/sessie_providers.dart';
import '../domein/chat_regels.dart';
import '../model/hh_bericht.dart';

/// De echte chat-gateway; tests overriden hem met een [FakeChatGateway].
/// Staat hier en niet in gateway_providers.dart (gedeeld bestand B3/B4/B6).
final chatGatewayProvider = Provider<ChatGateway>(
  (ref) => PocketBaseChatGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// Welk gesprek: de klus en de helper van dat gesprek (een nieuwe helper
/// begint een nieuw gesprek; de server laat hem het oude niet lezen).
typedef ChatSleutel = ({String klusId, String helperId});

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

/// Het gesprek bij één klus, live gevolgd. Een bericht van de ander komt
/// via realtime binnen; een eigen bericht staat er na versturen meteen in.
/// Valt de verbinding weg, dan ververst het scherm bij terugkomen (het
/// invalideert deze provider; zie ChatScreen).
class ChatController extends AsyncNotifier<List<HhBericht>> {
  ChatController(this.sleutel);

  /// Riverpod 3 geeft het familie-argument aan de constructor mee.
  final ChatSleutel sleutel;

  @override
  Future<List<HhBericht>> build() async {
    final gateway = ref.watch(chatGatewayProvider);
    final abonnement = gateway.volg(sleutel.klusId).listen((bericht) {
      if (bericht.helperId != sleutel.helperId) return;
      final huidige = state.value;
      if (huidige != null) state = AsyncData(voegBerichtIn(huidige, bericht));
    }, onError: (Object _) {});
    ref.onDispose(abonnement.cancel);

    return _uit(
      ref,
      () => gateway.berichten(sleutel.klusId, helperId: sleutel.helperId),
    );
  }

  /// "Opnieuw proberen".
  Future<void> vernieuw() async {
    state = await AsyncValue.guard(
      () => _uit(
        ref,
        () => ref
            .read(chatGatewayProvider)
            .berichten(sleutel.klusId, helperId: sleutel.helperId),
      ),
    );
  }

  /// Verstuurt een bericht (typen of snelknop). Lege tekst: niets.
  Future<VerstuurUitkomst?> verstuur(
    String tekst, {
    HhBerichtSoort soort = HhBerichtSoort.tekst,
  }) async {
    final schoon = tekst.trim();
    final gebruiker = ref.read(huidigeGebruikerProvider);
    if (schoon.isEmpty || gebruiker == null) return null;
    final uitkomst = await ref
        .read(chatGatewayProvider)
        .verstuur(
          klusId: sleutel.klusId,
          afzenderId: gebruiker.id,
          tekst: schoon.length > HhBericht.maxTekst
              ? schoon.substring(0, HhBericht.maxTekst)
              : schoon,
          soort: soort,
        );
    if (uitkomst case Verstuurd(:final bericht)) {
      final huidige = state.value ?? const <HhBericht>[];
      state = AsyncData(voegBerichtIn(huidige, bericht));
    }
    if (uitkomst case VerstuurFout(
      :final fout,
    ) when fout.soort == HhFoutSoort.nietIngelogd) {
      await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
    }
    return uitkomst;
  }

  /// Zet gelezen_op op elk bericht van de ander dat nog ongelezen is.
  /// Mislukt het, dan blijft de teller staan; het gesprek blijft gewoon.
  Future<void> markeerGelezen() async {
    final gebruiker = ref.read(huidigeGebruikerProvider);
    final huidige = state.value;
    if (gebruiker == null || huidige == null) return;
    final nu = ref.read(klokProvider)();
    for (final bericht in ongelezenVoor(huidige, gebruiker.id)) {
      final result = await ref
          .read(chatGatewayProvider)
          .markeerGelezen(bericht.id, nu);
      if (result case Ok<HhBericht>(:final waarde)) {
        final lijst = state.value;
        if (lijst != null) state = AsyncData(voegBerichtIn(lijst, waarde));
      }
    }
  }
}

final chatProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, List<HhBericht>, ChatSleutel>(ChatController.new);

/// Ongelezen berichten per klus voor de ingelogde gebruiker, live: elke
/// wijziging in een bericht dat ik mag zien telt opnieuw. Zonder sessie
/// leeg, zonder verzoek.
class OngelezenController extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    if (gebruiker == null) return const {};
    final gateway = ref.watch(chatGatewayProvider);
    final abonnement = gateway.volgAlle().listen((_) async {
      final result = await gateway.ongelezenPerKlus(gebruiker.id);
      if (!ref.mounted) return;
      if (result case Ok<Map<String, int>>(:final waarde)) {
        state = AsyncData(waarde);
      }
    }, onError: (Object _) {});
    ref.onDispose(abonnement.cancel);
    return _uit(ref, () => gateway.ongelezenPerKlus(gebruiker.id));
  }
}

final ongelezenChatProvider =
    AsyncNotifierProvider<OngelezenController, Map<String, int>>(
      OngelezenController.new,
    );

/// De teller op de Chat-knop van één klus; 0 zolang het laadt of mislukt.
final ongelezenVoorKlusProvider = Provider.family<int, String>(
  (ref, klusId) => ref.watch(ongelezenChatProvider).value?[klusId] ?? 0,
);

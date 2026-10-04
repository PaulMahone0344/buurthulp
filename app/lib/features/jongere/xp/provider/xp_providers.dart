import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/hh_fout.dart';
import '../../../../core/pb/gateway_providers.dart';
import '../../../../core/pb/xp_gateway.dart';
import '../../../../core/result.dart';
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../model/hh_xp.dart';

/// De echte XP-gateway (B9); tests overriden hem met een [FakeXpGateway].
/// Staat hier en niet in gateway_providers.dart (zelfde keuze als M5-M7).
final xpGatewayProvider = Provider<XpGateway>(
  (ref) => PocketBaseXpGateway(ref.watch(pocketBaseGatewayProvider)),
);

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

/// Het overzicht voor Profiel, Start en "Mijn verdiensten". Alleen voor een
/// helper; voor iedereen anders leeg, zonder verzoek.
final xpOverzichtProvider = FutureProvider<HhXpOverzicht>((ref) async {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null || gebruiker.rol != HhRol.jongere) {
    return const HhXpOverzicht();
  }
  return _uit(ref, () => ref.read(xpGatewayProvider).mijnOverzicht());
});

/// "Verklaring van inzet" aanvragen (knop op het Profiel).
final maakVerklaringProvider =
    Provider<Future<Result<HhVerklaring>> Function()>(
      (ref) => () async {
        final result = await ref.read(xpGatewayProvider).maakVerklaring();
        if (result case Err<HhVerklaring>(:final fout)) {
          if (fout.soort == HhFoutSoort.nietIngelogd) {
            await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
          }
        }
        return result;
      },
    );

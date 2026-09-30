import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/familie_gateway.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/result.dart';
import '../../jongere/klussen/model/hh_klus.dart';
import '../../jongere/uitvoeren/provider/uitvoeren_providers.dart';
import '../../meldingen/model/hh_melding.dart';
import '../../meldingen/provider/meldingen_providers.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../model/hh_koppeling.dart';

/// De echte familie-gateway; tests overriden hem met een
/// [FakeFamilieGateway]. Staat hier en niet in gateway_providers.dart, zodat
/// M9 dat gedeelde bestand niet hoeft te raken.
final familieGatewayProvider = Provider<FamilieGateway>(
  (ref) => PocketBaseFamilieGateway(ref.watch(pocketBaseGatewayProvider)),
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

String? _idAls(Ref ref, HhRol rol) {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null || gebruiker.rol != rol) return null;
  return gebruiker.id;
}

/// F1: de koppelingen van het ingelogde familielid.
final mijnKoppelingenProvider = FutureProvider<List<HhKoppeling>>((ref) async {
  final id = _idAls(ref, HhRol.familie);
  if (id == null) return const [];
  final gateway = ref.watch(familieGatewayProvider);
  return _uit(ref, () => gateway.vanFamilielid(id));
});

/// F3: de koppeling met één oudere, of null als die er (niet meer) is.
final koppelingMetProvider = Provider.family<AsyncValue<HhKoppeling?>, String>(
  (ref, oudereId) => ref.watch(mijnKoppelingenProvider).whenData((lijst) {
    for (final k in lijst) {
      if (k.oudereId == oudereId) return k;
    }
    return null;
  }),
);

/// F3: de hulpvragen van de oudere (de rules geven ze alleen bij een actieve
/// koppeling met recht meekijken).
final hulpvragenVanOudereProvider = FutureProvider.autoDispose
    .family<List<HhKlus>, String>((ref, oudereId) async {
      final gateway = ref.watch(uitvoerGatewayProvider);
      return _uit(ref, () => gateway.hulpvragen(oudereId));
    });

/// Hoeveel meldingen van de oudere F3 toont.
const f3MeldingenLimiet = 5;

/// F3: de laatste meldingen van de oudere. Besluit 30 sep 2026: meekijken =
/// ook de meldingen zien. De rule op hh_meldingen (script 44) geeft ze
/// alleen bij een actieve koppeling met recht meekijken.
final meldingenVanOudereProvider = FutureProvider.autoDispose
    .family<List<HhMelding>, String>((ref, oudereId) async {
      final gateway = ref.watch(meldingenGatewayProvider);
      return _uit(
        ref,
        () => gateway.meldingen(oudereId, limiet: f3MeldingenLimiet),
      );
    });

/// Aanvragen; daarna de lijst opnieuw laden (een nieuwe aanvraag staat dan
/// bij "wacht op toestemming").
final aanvragenProvider = Provider<Future<AanvraagUitkomst> Function(String)>(
  (ref) => (email) async {
    final uitkomst = await ref.read(familieGatewayProvider).aanvragen(email);
    if (uitkomst case AanvraagVerstuurd()) {
      ref.invalidate(mijnKoppelingenProvider);
    }
    if (uitkomst case AanvraagFout(
      :final fout,
    ) when fout.soort == HhFoutSoort.nietIngelogd) {
      await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
    }
    return uitkomst;
  },
);

/// O12 bij de oudere: wie van de familie meekijkt of wil meekijken.
final familieVanMijProvider = FutureProvider<List<HhKoppeling>>((ref) async {
  final id = _idAls(ref, HhRol.hulpvrager);
  if (id == null) return const [];
  final gateway = ref.watch(familieGatewayProvider);
  return _uit(ref, () => gateway.vanOudere(id));
});

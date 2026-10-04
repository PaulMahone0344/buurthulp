import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/fake_reactie_gateway.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/pb/reactie_gateway.dart';
import '../../../core/result.dart';
import '../../hulpvrager/status/provider/status_providers.dart';
import '../../jongere/klussen/provider/klussen_providers.dart';
import '../../jongere/model/screening_stap.dart';
import '../../jongere/provider/screening_providers.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../model/hh_reactie.dart';

/// De echte reactie-gateway; tests overriden hem met een
/// [FakeReactieGateway]. Staat hier en niet in gateway_providers.dart (zelfde
/// keuze als M5), zodat B5 dat gedeelde bestand niet hoeft te raken.
final reactieGatewayProvider = Provider<ReactieGateway>(
  (ref) => PocketBaseReactieGateway(ref.watch(pocketBaseGatewayProvider)),
);

String? _idVoor(Ref ref, HhRol rol) {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null || gebruiker.rol != rol) return null;
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

/// De eigen reacties van de helper (HMijnKlussen, tab Gereageerd).
class MijnReactiesController extends AsyncNotifier<List<HhReactie>> {
  @override
  Future<List<HhReactie>> build() async {
    final id = _idVoor(ref, HhRol.jongere);
    if (id == null) return const [];
    return _uit(ref, () => ref.read(reactieGatewayProvider).mijnReacties(id));
  }

  Future<void> vernieuw() async {
    final id = _idVoor(ref, HhRol.jongere);
    if (id == null) return;
    state = await AsyncValue.guard(
      () => _uit(ref, () => ref.read(reactieGatewayProvider).mijnReacties(id)),
    );
  }
}

final mijnReactiesProvider =
    AsyncNotifierProvider<MijnReactiesController, List<HhReactie>>(
      MijnReactiesController.new,
    );

/// KiesHelper: de kaarten voor één klus van de bewoner.
final reactiesVoorKlusProvider = FutureProvider.autoDispose
    .family<List<HhReactieKaart>, String>((ref, klusId) {
      return _uit(
        ref,
        () => ref.read(reactieGatewayProvider).reactiesVoorKlus(klusId),
      );
    });

/// "Ik wil helpen". Na elke uitkomst de lijsten en het detail verversen
/// (het detail laat dan "Je hebt gereageerd" zien).
Future<ReageerUitkomst> reageerOpKlus(
  Ref ref,
  String klusId, {
  String bericht = '',
  bool ouderGaatMee = false,
}) async {
  final uitkomst = await ref
      .read(reactieGatewayProvider)
      .reageren(klusId, bericht: bericht, ouderGaatMee: ouderGaatMee);
  switch (uitkomst) {
    case Gereageerd():
    case ReageerGeweigerd():
      ref.invalidate(mijnReactiesProvider);
      ref.invalidate(klusDetailProvider(klusId));
      ref.invalidate(openKlussenProvider);
    case ReageerFout(:final fout):
      if (fout.soort == HhFoutSoort.nietIngelogd) {
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      }
  }
  return uitkomst;
}

final reageerProvider =
    Provider<
      Future<ReageerUitkomst> Function(
        String klusId, {
        String bericht,
        bool ouderGaatMee,
      })
    >(
      (ref) =>
          (klusId, {bericht = '', ouderGaatMee = false}) => reageerOpKlus(
            ref,
            klusId,
            bericht: bericht,
            ouderGaatMee: ouderGaatMee,
          ),
    );

/// Reactie intrekken (vóór de keuze van de bewoner).
Future<Result<void>> trekReactieIn(
  Ref ref,
  String reactieId,
  String klusId,
) async {
  final result = await ref.read(reactieGatewayProvider).intrekken(reactieId);
  ref.invalidate(mijnReactiesProvider);
  ref.invalidate(klusDetailProvider(klusId));
  return result;
}

final intrekProvider =
    Provider<Future<Result<void>> Function(String reactieId, String klusId)>(
      (ref) =>
          (reactieId, klusId) => trekReactieIn(ref, reactieId, klusId),
    );

/// "Kies [naam]": daarna de hulpvragen en de kaarten opnieuw laden.
Future<KiesUitkomst> kiesHelper(
  Ref ref,
  String klusId,
  String reactieId,
) async {
  final uitkomst = await ref
      .read(reactieGatewayProvider)
      .kiezen(klusId, reactieId);
  switch (uitkomst) {
    case Gekozen():
    case KiesGeweigerd():
      ref.invalidate(mijnHulpvragenProvider);
      ref.invalidate(reactiesVoorKlusProvider(klusId));
    case KiesFout(:final fout):
      if (fout.soort == HhFoutSoort.nietIngelogd) {
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      }
  }
  return uitkomst;
}

final kiesProvider =
    Provider<Future<KiesUitkomst> Function(String klusId, String reactieId)>(
      (ref) =>
          (klusId, reactieId) => kiesHelper(ref, klusId, reactieId),
    );

/// "Ik kan nu helpen": tot wanneer hij aan staat. Begint bij wat het profiel
/// zegt; na de schakelaar wat de server teruggaf.
class BeschikbaarController extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    return switch (ref.watch(screeningControllerProvider)) {
      AsyncData<ScreeningGegevens>(:final value) =>
        value.profiel?.beschikbaarTot,
      _ => null,
    };
  }

  /// Zet hem aan of uit; true als het lukte.
  Future<bool> zet(bool aan) async {
    final result = await ref.read(reactieGatewayProvider).zetBeschikbaar(aan);
    switch (result) {
      case Ok<DateTime?>(:final waarde):
        state = waarde;
        return true;
      case Err<DateTime?>(:final fout):
        if (fout.soort == HhFoutSoort.nietIngelogd) {
          await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
        }
        return false;
    }
  }
}

final beschikbaarProvider = NotifierProvider<BeschikbaarController, DateTime?>(
  BeschikbaarController.new,
);

/// De vraag voor "N helpers kunnen nu" bij het plaatsen.
@immutable
class BeschikbaarVraag {
  const BeschikbaarVraag({required this.klustypeId, this.van, this.tot});

  final String klustypeId;
  final DateTime? van;
  final DateTime? tot;

  @override
  bool operator ==(Object other) =>
      other is BeschikbaarVraag &&
      other.klustypeId == klustypeId &&
      other.van == van &&
      other.tot == tot;

  @override
  int get hashCode => Object.hash(klustypeId, van, tot);
}

/// Alleen een aantal; null = (nog) niet bekend, dan toont de app niets.
final aantalBeschikbaarProvider = FutureProvider.autoDispose
    .family<int?, BeschikbaarVraag>((ref, vraag) async {
      if (vraag.klustypeId.isEmpty) return null;
      final result = await ref
          .read(reactieGatewayProvider)
          .aantalBeschikbaar(
            klustypeId: vraag.klustypeId,
            van: vraag.van,
            tot: vraag.tot,
          );
      return switch (result) {
        Ok<int>(:final waarde) => waarde,
        Err<int>() => null,
      };
    });

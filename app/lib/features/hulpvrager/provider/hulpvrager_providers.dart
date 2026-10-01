import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/pb/klus_gateway.dart';
import '../../../core/result.dart';
import '../../familie/provider/hulpvraag_namens.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../model/hh_gegevens.dart';
import '../model/hh_klustype.dart';

/// De echte klus-gateway; tests overriden hem met een [FakeKlusGateway].
/// Staat hier en niet in gateway_providers.dart, zodat M4 dat gedeelde
/// bestand niet hoeft te raken.
final klusGatewayProvider = Provider<KlusGateway>(
  (ref) => PocketBaseKlusGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// Klok, los te vervangen in tests ("morgen" over een maandgrens).
final klokProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// De soorten hulp van de server. Een [HhFout] wordt als AsyncError
/// doorgegeven; het scherm toont de Nederlandse melding.
final klustypesProvider = FutureProvider<List<HhKlustype>>((ref) async {
  final result = await ref.watch(klusGatewayProvider).klustypes();
  return switch (result) {
    Ok<List<HhKlustype>>(:final waarde) => waarde,
    Err<List<HhKlustype>>(:final fout) => throw fout,
  };
});

/// De eigen gegevens (adres, contactpersoon) van de ingelogde oudere.
/// Laadt bij het eerste gebruik; [bijwerken] stuurt alleen gewijzigde
/// velden en vervangt de state met het antwoord.
class GegevensController extends AsyncNotifier<HhGegevens> {
  @override
  Future<HhGegevens> build() async {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    if (gebruiker == null) throw const HhFout(HhFoutSoort.nietIngelogd);
    // M9 (F2): namens een oudere komt het adres uit diens gegevens.
    final namens = ref.watch(actieveNamensProvider);
    final result = await ref
        .read(klusGatewayProvider)
        .mijnGegevens(namens?.oudereId ?? gebruiker.id);
    return switch (result) {
      Ok<HhGegevens>(:final waarde) => waarde,
      Err<HhGegevens>(:final fout) => throw fout,
    };
  }

  Future<Result<void>> bijwerken(Map<String, dynamic> velden) async {
    final gebruiker = ref.read(huidigeGebruikerProvider);
    if (gebruiker == null) {
      return Result.err(const HhFout(HhFoutSoort.nietIngelogd));
    }
    if (velden.isEmpty) return Result.ok(null);
    final result = await ref
        .read(klusGatewayProvider)
        .gegevensBijwerken(gebruiker.id, velden);
    switch (result) {
      case Ok<HhGegevens>(:final waarde):
        state = AsyncData(waarde);
        return Result.ok(null);
      case Err<HhGegevens>(:final fout):
        await verwerkSessieFout(ref, fout);
        return Result.err(fout);
    }
  }
}

final gegevensProvider = AsyncNotifierProvider<GegevensController, HhGegevens>(
  GegevensController.new,
);

/// App OPEN-PUNT 19: een 401 buiten de toegangslaag logt uit met de melding
/// "sessie verlopen".
Future<void> verwerkSessieFout(Ref ref, HhFout fout) async {
  if (fout.soort == HhFoutSoort.nietIngelogd) {
    await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/hh_fout.dart';
import '../../../../core/pb/gateway_providers.dart';
import '../../../../core/pb/uitvoer_gateway.dart';
import '../../../../core/result.dart';
import '../../../../theme.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../klussen/model/hh_klus.dart';
import '../../klussen/provider/klussen_providers.dart';
import '../model/hh_klus_logregel.dart';

/// De echte uitvoer-gateway; tests overriden hem met een
/// [FakeUitvoerGateway]. Staat hier en niet in gateway_providers.dart, zodat
/// M6 dat gedeelde bestand niet hoeft te raken (zelfde keuze als M4 en M5).
final uitvoerGatewayProvider = Provider<UitvoerGateway>(
  (ref) => PocketBaseUitvoerGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// Wat J15 en O7 samen op het scherm zetten: de klus en zijn logregels.
@immutable
class KlusMetGeschiedenis {
  const KlusMetGeschiedenis({required this.klus, required this.logregels});

  final HhKlus klus;
  final List<HhKlusLogregel> logregels;

  /// Wanneer de klus voor het eerst op [status] kwam te staan; null als die
  /// stap nog niet gezet is. Voor de tijd per stap in de stappenbalk.
  DateTime? tijdVan(HhKlusStatus status) {
    for (final regel in logregels) {
      if (regel.naar == status) return regel.wanneer;
    }
    return null;
  }

  /// De laatste regel met een toelichting: de reden van een annulering.
  String get laatsteToelichting {
    for (final regel in logregels.reversed) {
      if (regel.heeftToelichting) return regel.toelichting;
    }
    return '';
  }

  KlusMetGeschiedenis metKlus(HhKlus nieuwe) =>
      KlusMetGeschiedenis(klus: nieuwe, logregels: logregels);
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

/// Eén klus met zijn logregels, live gevolgd. De realtime-stroom werkt de
/// klus bij zodra de server iets wijzigt; valt hij weg, dan blijven
/// "Vernieuwen" en pull-to-refresh werken.
class KlusVolgerController extends AsyncNotifier<KlusMetGeschiedenis> {
  KlusVolgerController(this.klusId);

  /// Riverpod 3 geeft het familie-argument aan de constructor mee.
  final String klusId;

  @override
  Future<KlusMetGeschiedenis> build() async {
    final gateway = ref.watch(uitvoerGatewayProvider);

    final abonnement = gateway.volgKlus(klusId).listen((klus) {
      final huidige = state;
      if (huidige is AsyncData<KlusMetGeschiedenis>) {
        state = AsyncData(huidige.value.metKlus(klus));
        // De logregels lopen achter op de klus; die halen we erbij.
        unawaited(_ververeLogregels(klusId));
      }
    }, onError: (Object _) {});
    ref.onDispose(abonnement.cancel);

    return _laad(klusId);
  }

  Future<KlusMetGeschiedenis> _laad(String klusId) async {
    final gateway = ref.read(uitvoerGatewayProvider);
    final klus = await _uit(ref, () => gateway.klus(klusId));
    final logregels = await _uit(ref, () => gateway.logregels(klusId));
    return KlusMetGeschiedenis(klus: klus, logregels: logregels);
  }

  Future<void> _ververeLogregels(String klusId) async {
    final result = await ref.read(uitvoerGatewayProvider).logregels(klusId);
    final huidige = state;
    if (result case Ok<List<HhKlusLogregel>>(:final waarde)) {
      if (huidige is AsyncData<KlusMetGeschiedenis>) {
        state = AsyncData(
          KlusMetGeschiedenis(klus: huidige.value.klus, logregels: waarde),
        );
      }
    }
  }

  /// Knop "Vernieuwen" en pull-to-refresh.
  Future<void> vernieuw() async {
    state = await AsyncValue.guard(() => _laad(klusId));
  }
}

final klusVolgerProvider = AsyncNotifierProvider.autoDispose
    .family<KlusVolgerController, KlusMetGeschiedenis, String>(
      KlusVolgerController.new,
    );

/// Eén stap vooruit (J15). Na afloop worden het volgscherm en de lijsten van
/// M5 ververst, zodat "Mijn klussen" meteen klopt.
Future<UitvoerUitkomst> zetKlusStatus(
  Ref ref,
  String klusId,
  HhKlusStatus naar,
) async {
  final uitkomst = await ref
      .read(uitvoerGatewayProvider)
      .zetStatus(klusId, naar);
  await _naEenWissel(ref, klusId, uitkomst);
  return uitkomst;
}

/// Annuleren met reden (J15 en O7).
Future<UitvoerUitkomst> annuleerKlus(
  Ref ref,
  String klusId,
  String reden,
) async {
  final uitkomst = await ref
      .read(uitvoerGatewayProvider)
      .annuleer(klusId, reden);
  await _naEenWissel(ref, klusId, uitkomst);
  return uitkomst;
}

Future<void> _naEenWissel(
  Ref ref,
  String klusId,
  UitvoerUitkomst uitkomst,
) async {
  switch (uitkomst) {
    case UitvoerGelukt():
    case UitvoerGeweigerd():
      // Ook na een weigering opnieuw laden: de server weet het beter.
      ref.invalidate(klusVolgerProvider(klusId));
      ref.invalidate(klusDetailProvider(klusId));
      ref.invalidate(mijnKlussenProvider);
      ref.invalidate(openKlussenProvider);
    case UitvoerFout(:final fout):
      if (fout.soort == HhFoutSoort.nietIngelogd) {
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      }
  }
}

/// Het telefoonnummer ophalen (J16 en O7). De app toont het nummer nooit als
/// tekst; het gaat rechtstreeks naar de kiezer.
Future<BelUitkomst> haalBelNummer(Ref ref, String klusId) async {
  final uitkomst = await ref.read(uitvoerGatewayProvider).belNummer(klusId);
  if (uitkomst case BelFout(:final fout)) {
    if (fout.soort == HhFoutSoort.nietIngelogd) {
      await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
    }
  }
  return uitkomst;
}

final zetStatusProvider =
    Provider<Future<UitvoerUitkomst> Function(String, HhKlusStatus)>(
      (ref) =>
          (id, naar) => zetKlusStatus(ref, id, naar),
    );

final annuleerProvider =
    Provider<Future<UitvoerUitkomst> Function(String, String)>(
      (ref) =>
          (id, reden) => annuleerKlus(ref, id, reden),
    );

final belNummerProvider = Provider<Future<BelUitkomst> Function(String)>(
  (ref) =>
      (id) => haalBelNummer(ref, id),
);

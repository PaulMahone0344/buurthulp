import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/hh_fout.dart';
import '../../../../core/pb/beoordeling_gateway.dart';
import '../../../../core/pb/gateway_providers.dart';
import '../../../../core/result.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../klussen/model/hh_klus.dart';
import '../../uitvoeren/provider/uitvoeren_providers.dart';
import '../model/hh_beoordeling.dart';

/// De echte beoordeling-gateway; tests overriden hem met een
/// [FakeBeoordelingGateway]. Staat hier en niet in gateway_providers.dart,
/// zodat M7 dat gedeelde bestand niet hoeft te raken (zelfde keuze als M5 en
/// M6). O9 bij de oudere gebruikt dezelfde provider.
final beoordelingGatewayProvider = Provider<BeoordelingGateway>(
  (ref) => PocketBaseBeoordelingGateway(ref.watch(pocketBaseGatewayProvider)),
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

/// De beoordelingen die de ingelogde gebruiker gaf, per klus-id. Voor "Nog
/// beoordelen" (J14, O8), de knop op J15/O7 en het voorvullen bij wijzigen.
/// Zonder sessie leeg, zonder verzoek.
final gegevenBeoordelingenProvider = FutureProvider<Map<String, HhBeoordeling>>(
  (ref) async {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    if (gebruiker == null) return const {};
    final gateway = ref.watch(beoordelingGatewayProvider);
    final lijst = await _uit(ref, () => gateway.gegevenDoor(gebruiker.id));
    return {for (final b in lijst) b.klusId: b};
  },
);

/// Wat J19 laat zien: de reputatie zoals de server hem uitrekende, en de
/// laatste beoordelingen met tekst.
@immutable
class MijnReputatie {
  const MijnReputatie({required this.reputatie, required this.laatste});

  final HhReputatie reputatie;
  final List<HhBeoordeling> laatste;
}

final mijnReputatieProvider = FutureProvider<MijnReputatie>((ref) async {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null) {
    return const MijnReputatie(reputatie: HhReputatie(), laatste: []);
  }
  final gateway = ref.watch(beoordelingGatewayProvider);
  final reputatie = await _uit(ref, () => gateway.reputatie(gebruiker.id));
  final laatste = await _uit(ref, () => gateway.ontvangen(gebruiker.id));
  return MijnReputatie(reputatie: reputatie, laatste: laatste);
});

/// Wat J17 en O9 nodig hebben: de klus en, als die er al is, de eigen
/// beoordeling (dan wordt het wijzigen).
@immutable
class TeBeoordelen {
  const TeBeoordelen({required this.klus, this.bestaande});

  final HhKlus klus;
  final HhBeoordeling? bestaande;

  /// Wie [ikId] beoordeelt: de oudere beoordeelt de toegewezen jongere, de
  /// jongere de oudere. Leeg als [ikId] geen deelnemer is.
  String naarVoor(String ikId) {
    if (ikId.isEmpty) return '';
    if (ikId == klus.hulpvragerId) return klus.toegewezenJongereId;
    if (klus.isToegewezenAan(ikId)) return klus.hulpvragerId;
    return '';
  }
}

final teBeoordelenProvider = FutureProvider.autoDispose
    .family<TeBeoordelen, String>((ref, klusId) async {
      final klus = await _uit(
        ref,
        () => ref.read(uitvoerGatewayProvider).klus(klusId),
      );
      final gegeven = await ref.watch(gegevenBeoordelingenProvider.future);
      return TeBeoordelen(klus: klus, bestaande: gegeven[klusId]);
    });

/// Opslaan vanuit J17 en O9: nieuw als er nog niets is, anders wijzigen.
/// Daarna (ook na een weigering: de server weet het beter) de lijsten en de
/// reputatie opnieuw laden, zodat J14, O8 en J19 meteen kloppen.
Future<BeoordelingUitkomst> slaBeoordelingOp(
  Ref ref,
  TeBeoordelen doel, {
  required int sterren,
  required String tekst,
  bool? allesInOrde,
  String geheimToelichting = '',
}) async {
  final gateway = ref.read(beoordelingGatewayProvider);
  final ikId = ref.read(huidigeGebruikerProvider)?.id ?? '';
  final bestaande = doel.bestaande;
  final uitkomst = bestaande != null
      ? await gateway.wijzig(
          bestaande.id,
          sterren: sterren,
          tekst: tekst,
          allesInOrde: allesInOrde,
          geheimToelichting: geheimToelichting,
        )
      : await gateway.geef(
          klusId: doel.klus.id,
          vanId: ikId,
          naarId: doel.naarVoor(ikId),
          sterren: sterren,
          tekst: tekst,
          allesInOrde: allesInOrde,
          geheimToelichting: geheimToelichting,
        );
  switch (uitkomst) {
    case BeoordelingOpgeslagen():
    case BeoordelingGeweigerd():
      ref.invalidate(gegevenBeoordelingenProvider);
      ref.invalidate(mijnReputatieProvider);
    case BeoordelingFout(:final fout):
      if (fout.soort == HhFoutSoort.nietIngelogd) {
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      }
  }
  return uitkomst;
}

final slaBeoordelingOpProvider =
    Provider<
      Future<BeoordelingUitkomst> Function(
        TeBeoordelen doel, {
        required int sterren,
        required String tekst,
        bool? allesInOrde,
        String geheimToelichting,
      })
    >(
      (ref) =>
          (
            doel, {
            required sterren,
            required tekst,
            allesInOrde,
            geheimToelichting = '',
          }) => slaBeoordelingOp(
            ref,
            doel,
            sterren: sterren,
            tekst: tekst,
            allesInOrde: allesInOrde,
            geheimToelichting: geheimToelichting,
          ),
    );

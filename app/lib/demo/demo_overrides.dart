// DEMO — alle gateways vervangen door fakes met nepgegevens. Zelfde rijtje
// als toegangOverrides in de tests, maar met gevulde fakes. Fakes die
// weten wie er kijkt (ikBenId, jongereId) worden opnieuw gemaakt zodra
// een andere demo-rol inlogt.

import '../core/key_value_store.dart';
import '../core/pb/fake_adres_gateway.dart';
import '../core/pb/fake_auth_gateway.dart';
import '../core/pb/fake_beoordeling_gateway.dart';
import '../core/pb/fake_chat_gateway.dart';
import '../core/pb/fake_coordinator_gateway.dart';
import '../core/pb/fake_incident_gateway.dart';
import '../core/pb/fake_klus_gateway.dart';
import '../core/pb/fake_klussen_gateway.dart';
import '../core/pb/fake_meldingen_gateway.dart';
import '../core/pb/fake_meldkamer_gateway.dart';
import '../core/pb/fake_ouder_gateway.dart';
import '../core/pb/fake_profiel_gateway.dart';
import '../core/pb/fake_reactie_gateway.dart';
import '../core/pb/fake_uitvoer_gateway.dart';
import '../core/pb/fake_xp_gateway.dart';
import '../core/pb/gateway_providers.dart';
import '../features/chat/provider/chat_providers.dart';
import '../features/coordinator/provider/coordinator_providers.dart';
import '../features/coordinator/provider/te_doen_providers.dart';
import '../features/hulpvrager/provider/hulpvrager_providers.dart';
import '../features/hulpvrager/veiligheid/provider/veiligheid_providers.dart';
import '../features/jongere/klussen/provider/klussen_providers.dart';
import '../features/jongere/ouder/model/hh_ouder_stand.dart';
import '../features/jongere/reputatie/provider/beoordeling_providers.dart';
import '../features/jongere/uitvoeren/provider/uitvoeren_providers.dart';
import '../features/jongere/xp/provider/xp_providers.dart';
import '../features/meldingen/provider/meldingen_providers.dart';
import '../features/reacties/provider/reactie_providers.dart';
import '../features/toegang/model/hh_rol.dart';
import '../features/toegang/provider/sessie_providers.dart';
import 'demo_data.dart';

FakeAuthGateway _demoAuth() => FakeAuthGateway(
  accounts: [
    for (final rol in HhRol.values)
      FakeAccount(
        gebruiker: demoGebruiker(rol),
        wachtwoord: demoWachtwoord,
        token: 'demo-token-${rol.code}',
      ),
  ],
);

/// Riverpod 3 exporteert het type Override niet, dus dynamic (zoals in
/// test/support/hh_toegang_wikkel.dart).
List<dynamic> demoOverrides() {
  final nu = DateTime.now();
  final alle = demoAlleKlussen(nu);

  return [
    authGatewayProvider.overrideWithValue(_demoAuth()),
    // Elke start uitgelogd: niets in de echte Keychain.
    keyValueStoreProvider.overrideWithValue(GeheugenKeyValueStore()),
    profielGatewayProvider.overrideWithValue(
      FakeProfielGateway.goedgekeurd(demoStrijderId),
    ),
    ouderGatewayProvider.overrideWithValue(
      FakeOuderGateway(
        stand: const HhOuderStand(
          status: HhOuderStatus.verstuurd,
          ouderEmail: 'ouder@demo.heitjehulp',
          nogTeSturen: 2,
        ),
      ),
    ),
    adresGatewayProvider.overrideWithValue(FakeAdresGateway()),
    klusGatewayProvider.overrideWithValue(
      FakeKlusGateway(
        klustypes: demoKlustypes,
        gegevens: {demoBewonerId: demoGegevens},
      ),
    ),
    klussenGatewayProvider.overrideWith(
      (ref) => FakeKlussenGateway(
        klussen: alle,
        jongereId: ref.watch(huidigeGebruikerProvider)?.id ?? '',
      ),
    ),
    uitvoerGatewayProvider.overrideWith((ref) {
      final fake = FakeUitvoerGateway(
        klussen: alle,
        logregels: [for (final k in alle) ...demoLogregels(k, nu)],
        ikBenId: ref.watch(huidigeGebruikerProvider)?.id ?? '',
        klok: nu,
      );
      ref.onDispose(fake.sluit);
      return fake;
    }),
    beoordelingGatewayProvider.overrideWith(
      (ref) => FakeBeoordelingGateway(
        klussen: alle,
        ikBenId: ref.watch(huidigeGebruikerProvider)?.id ?? '',
        klok: nu.toUtc(),
      ),
    ),
    meldingenGatewayProvider.overrideWith((ref) {
      final id = ref.watch(huidigeGebruikerProvider)?.id ?? '';
      final fake = FakeMeldingenGateway(meldingen: demoMeldingen(id, nu));
      ref.onDispose(fake.sluit);
      return fake;
    }),
    chatGatewayProvider.overrideWith((ref) {
      final fake = FakeChatGateway(
        berichten: demoBerichten(nu),
        helperVanKlus: {
          for (final k in alle)
            if (k.toegewezenJongereId.isNotEmpty) k.id: k.toegewezenJongereId,
        },
        klok: nu.toUtc(),
      );
      ref.onDispose(fake.sluit);
      return fake;
    }),
    reactieGatewayProvider.overrideWith(
      (ref) => FakeReactieGateway(
        helperId: ref.watch(huidigeGebruikerProvider)?.id ?? '',
      ),
    ),
    xpGatewayProvider.overrideWithValue(FakeXpGateway(overzicht: demoXp())),
    incidentGatewayProvider.overrideWithValue(FakeIncidentGateway()),
    coordinatorGatewayProvider.overrideWith((ref) {
      final fake = FakeCoordinatorGateway(
        incidenten: demoIncidenten(nu),
        klussen: demoCoordinatorKlussen(nu),
        jongeren: demoKandidaten,
        coordinatorId: demoCoordinatorId,
      );
      ref.onDispose(fake.sluitStroom);
      return fake;
    }),
    meldkamerGatewayProvider.overrideWithValue(FakeMeldkamerGateway()),
  ];
}

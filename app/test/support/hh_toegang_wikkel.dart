import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/chat_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_chat_gateway.dart';
import 'package:heitjehulp_app/features/chat/provider/chat_providers.dart';
import 'package:heitjehulp_app/core/pb/coordinator_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_coordinator_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_incident_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_familie_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/core/pb/gateway_providers.dart';
import 'package:heitjehulp_app/core/pb/incident_gateway.dart';
import 'package:heitjehulp_app/core/pb/familie_gateway.dart';
import 'package:heitjehulp_app/core/pb/klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/profiel_gateway.dart';
import 'package:heitjehulp_app/core/pb/uitvoer_gateway.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/coordinator/provider/coordinator_providers.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/provider/veiligheid_providers.dart';
import 'package:heitjehulp_app/features/meldingen/provider/meldingen_providers.dart';
import 'package:heitjehulp_app/features/familie/provider/familie_providers.dart';
import 'package:heitjehulp_app/features/jongere/klussen/provider/klussen_providers.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/provider/beoordeling_providers.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/provider/uitvoeren_providers.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';
import 'package:heitjehulp_app/features/toegang/screen/hulp_screen.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/theme.dart';

/// Wachtwoord van de nep-accounts. Alleen voor de fake; bestaat nergens
/// op een server.
const testWachtwoord = 'testwachtwoord';

/// Een nep-account per rol, met een vast token zodat herstel te testen is.
/// Bewoner en helper wonen standaard in het werkgebied (B2: wijk gezet).
HhGebruiker testGebruiker(
  HhRol rol, {
  bool isBevestigd = true,
  String? wijkId,
}) => HhGebruiker(
  id: 'id-${rol.code}',
  naam: 'Test ${rol.naam}',
  email: 'test-${rol.code}@voorbeeld.nl',
  rol: rol,
  isBevestigd: isBevestigd,
  wijkId:
      wijkId ??
      (rol == HhRol.hulpvrager || rol == HhRol.jongere ? 'wijk-west' : ''),
);

String testToken(HhRol rol) => 'token-${rol.code}';

FakeAuthGateway fakeMetAlleRollen() => FakeAuthGateway(
  accounts: [
    for (final rol in HhRol.values)
      FakeAccount(
        gebruiker: testGebruiker(rol),
        wachtwoord: testWachtwoord,
        token: testToken(rol),
      ),
  ],
);

/// Sessie die meteen in een vaste toestand staat, zonder herstel bij het
/// opstarten. Voor schermtests die een ingelogde gebruiker nodig hebben.
class VasteSessie extends SessieController {
  VasteSessie(this.begin);

  final SessieState begin;

  @override
  SessieState build() => begin;
}

class _VasteRol extends GekozenRolController {
  _VasteRol(this.rol);

  final HhRol? rol;

  @override
  HhRol? build() => rol;
}

/// De overrides die elke test deelt: fake gateway, geheugenopslag, een
/// url-opener die nooit een plugin raakt, en de M3/M5-fakes. Apart van de
/// container zodat een feature-wikkel er eigen overrides bij kan leggen.
/// (Riverpod 3 exporteert het type Override niet, dus dynamic.)
List<dynamic> toegangOverrides({
  required FakeAuthGateway gateway,
  GeheugenKeyValueStore? opslag,
  SessieState? sessie,
  HhRol? gekozenRol,
  bool urlOpenerLukt = true,
  ProfielGateway? profielGateway,
  FotoKiezer? fotoKiezer,
  KlussenGateway? klussenGateway,
  UitvoerGateway? uitvoerGateway,
  CoordinatorGateway? coordinatorGateway,
  BeoordelingGateway? beoordelingGateway,
  MeldingenGateway? meldingenGateway,
  IncidentGateway? incidentGateway,
  FamilieGateway? familieGateway,
  ChatGateway? chatGateway,
}) => [
  authGatewayProvider.overrideWithValue(gateway),
  keyValueStoreProvider.overrideWithValue(opslag ?? GeheugenKeyValueStore()),
  urlOpenerProvider.overrideWithValue((_) async => urlOpenerLukt),
  // M3: screening van de jongere. Standaard een goedgekeurd profiel voor
  // de test-jongere, zodat de landing /jongere bereikbaar blijft; de
  // screeningtests geven hun eigen fake mee.
  profielGatewayProvider.overrideWithValue(
    profielGateway ??
        FakeProfielGateway.goedgekeurd(testGebruiker(HhRol.jongere).id),
  ),
  fotoKiezerProvider.overrideWithValue(fotoKiezer ?? FakeFotoKiezer()),
  // M5: klussen van de jongere. Standaard een lege fake zonder netwerk;
  // de klussentests geven hun eigen fake mee.
  klussenGatewayProvider.overrideWithValue(
    klussenGateway ?? FakeKlussenGateway(),
  ),
  // M6: uitvoeren (J15, J16) en de status bij de oudere (O7, O8).
  uitvoerGatewayProvider.overrideWithValue(
    uitvoerGateway ?? FakeUitvoerGateway(),
  ),
  // M10: de landing /coordinator (C1) praat meteen met de server en zet
  // een realtime-verbinding op. Standaard een lege fake zonder netwerk; de
  // coordinatortests geven hun eigen fake mee.
  coordinatorGatewayProvider.overrideWithValue(
    coordinatorGateway ?? FakeCoordinatorGateway(),
  ),
  // M7: J14, J15, O7 en O8 vragen welke klussen al beoordeeld zijn.
  // Standaard een lege fake zonder netwerk.
  beoordelingGatewayProvider.overrideWithValue(
    beoordelingGateway ?? FakeBeoordelingGateway(),
  ),
  // M8: het belletje en de regel op O1 vragen meteen de meldingen op, en
  // O11 meldt incidenten. Standaard lege fakes zonder netwerk.
  meldingenGatewayProvider.overrideWithValue(
    meldingenGateway ?? FakeMeldingenGateway(),
  ),
  incidentGatewayProvider.overrideWithValue(
    incidentGateway ?? FakeIncidentGateway(),
  ),
  // M9: F1 en het blok op O12 vragen meteen de koppelingen op. Standaard
  // een lege fake zonder netwerk.
  familieGatewayProvider.overrideWithValue(
    familieGateway ?? FakeFamilieGateway(),
  ),
  // B6: de Chat-knoppen (J13, J14, O7) tellen meteen de ongelezen
  // berichten. Standaard een lege fake zonder netwerk.
  chatGatewayProvider.overrideWithValue(chatGateway ?? FakeChatGateway()),
  if (sessie != null)
    sessieControllerProvider.overrideWith(() => VasteSessie(sessie)),
  if (gekozenRol != null)
    gekozenRolProvider.overrideWith(() => _VasteRol(gekozenRol)),
];

/// Een ProviderContainer met [toegangOverrides]. Wordt na de test
/// opgeruimd.
ProviderContainer toegangContainer({
  required FakeAuthGateway gateway,
  GeheugenKeyValueStore? opslag,
  SessieState? sessie,
  HhRol? gekozenRol,
  bool urlOpenerLukt = true,
  ProfielGateway? profielGateway,
  FotoKiezer? fotoKiezer,
  KlussenGateway? klussenGateway,
  UitvoerGateway? uitvoerGateway,
}) {
  final container = ProviderContainer(
    // Geen automatische retry (Riverpod 3): een fake die bewust faalt zou
    // anders een Timer achterlaten na het einde van de test.
    retry: (_, _) => null,
    overrides: [
      ...toegangOverrides(
        gateway: gateway,
        opslag: opslag,
        sessie: sessie,
        gekozenRol: gekozenRol,
        urlOpenerLukt: urlOpenerLukt,
        profielGateway: profielGateway,
        fotoKiezer: fotoKiezer,
        klussenGateway: klussenGateway,
        uitvoerGateway: uitvoerGateway,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Een los scherm (met eigen Scaffold) in het thema, met providers,
/// zonder go_router. Anders dan hhWikkel geen scrollwikkel eromheen:
/// een scherm regelt zijn eigen hoogte en scrollen.
Widget hhToegangWikkel(
  Widget scherm, {
  required FakeAuthGateway gateway,
  GeheugenKeyValueStore? opslag,
  SessieState? sessie,
  HhRol? gekozenRol,
  bool urlOpenerLukt = true,
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) {
  return UncontrolledProviderScope(
    container: toegangContainer(
      gateway: gateway,
      opslag: opslag,
      sessie: sessie,
      gekozenRol: gekozenRol,
      urlOpenerLukt: urlOpenerLukt,
    ),
    child: MaterialApp(
      theme: hhThema(dichtheid),
      builder: (context, kind) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(tekstschaal)),
        child: HhDichtheidScope(dichtheid: dichtheid, child: kind!),
      ),
      home: scherm,
    ),
  );
}

/// De hele app met router en guard, voor de stroomtests.
Future<ProviderContainer> pompApp(
  WidgetTester tester, {
  required FakeAuthGateway gateway,
  GeheugenKeyValueStore? opslag,
}) async {
  final container = toegangContainer(gateway: gateway, opslag: opslag);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const HeitjeHulpApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

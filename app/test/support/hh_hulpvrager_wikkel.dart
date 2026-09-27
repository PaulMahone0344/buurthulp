import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_incident_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klus_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/core/pb/gateway_providers.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_gegevens.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_klustype.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/provider/veiligheid_providers.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/provider/uitvoeren_providers.dart';
import 'package:heitjehulp_app/features/meldingen/provider/meldingen_providers.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';
import 'package:heitjehulp_app/features/toegang/screen/hulp_screen.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_toegang_wikkel.dart';

/// Een vaste "nu" voor de M4-tests: dinsdag 15 september 2026, 10:00.
final testNu = DateTime(2026, 9, 15, 10);

/// Zes soorten hulp, gelijk aan de seed op de server.
const testKlustypes = [
  HhKlustype(
    id: 'kt-boodschappen',
    naam: 'boodschappen',
    icoon: 'shopping_cart',
    richtduurMinuten: 60,
    richtvergoedingCenten: 1000,
  ),
  HhKlustype(
    id: 'kt-tuin',
    naam: 'tuin',
    icoon: 'yard',
    richtduurMinuten: 90,
    richtvergoedingCenten: 1500,
  ),
  HhKlustype(
    id: 'kt-klusje',
    naam: 'klusje in huis',
    icoon: 'handyman',
    richtduurMinuten: 60,
    richtvergoedingCenten: 1250,
  ),
  HhKlustype(
    id: 'kt-tablet',
    naam: 'telefoon/tablet-hulp',
    icoon: 'devices',
    richtduurMinuten: 45,
    richtvergoedingCenten: 750,
  ),
  HhKlustype(
    id: 'kt-wandelen',
    naam: 'wandelen/gezelschap',
    icoon: 'directions_walk',
    richtduurMinuten: 60,
    richtvergoedingCenten: 750,
  ),
  HhKlustype(
    id: 'kt-vervoer',
    naam: 'vervoer',
    icoon: 'directions_car',
    richtduurMinuten: 90,
    richtvergoedingCenten: 1500,
  ),
];

/// Een zevende soort, om "Meer" te testen.
const testExtraKlustype = HhKlustype(
  id: 'kt-huisdier',
  naam: 'huisdier',
  icoon: 'pets',
  richtduurMinuten: 30,
  richtvergoedingCenten: 500,
);

/// De gegevens van de nep-hulpvrager, met of zonder adres.
HhGegevens testGegevens({bool metAdres = true}) => HhGegevens(
  id: testGebruiker(HhRol.hulpvrager).id,
  naam: testGebruiker(HhRol.hulpvrager).naam,
  telefoon: '0344-100001',
  adres: metAdres ? 'Prins Bernhardlaan 12' : '',
  postcode: metAdres ? '4003 AB' : '',
  plaats: metAdres ? 'Tiel' : '',
  contactNaam: metAdres ? 'Dochter Jansen' : '',
  contactTelefoon: metAdres ? '0612345678' : '',
);

FakeKlusGateway fakeKlusGateway({
  List<HhKlustype> klustypes = testKlustypes,
  bool metAdres = true,
}) => FakeKlusGateway(
  klustypes: klustypes,
  gegevens: {
    testGebruiker(HhRol.hulpvrager).id: testGegevens(metAdres: metAdres),
  },
);

/// Zoals toegangContainer, plus de klus-fake en een vaste klok.
ProviderContainer hulpvragerContainer({
  required FakeKlusGateway klusGateway,
  FakeAuthGateway? authGateway,
  GeheugenKeyValueStore? opslag,
  SessieState? sessie,
  DateTime? nu,
  bool urlOpenerLukt = true,
  FakeUitvoerGateway? uitvoerGateway,
  FakeMeldingenGateway? meldingenGateway,
  FakeIncidentGateway? incidentGateway,
}) {
  final container = ProviderContainer(
    // Geen automatische retry (Riverpod 3): een fake die bewust faalt zou
    // anders een Timer achterlaten na het einde van de test.
    retry: (_, _) => null,
    overrides: [
      authGatewayProvider.overrideWithValue(authGateway ?? fakeMetAlleRollen()),
      klusGatewayProvider.overrideWithValue(klusGateway),
      uitvoerGatewayProvider.overrideWithValue(
        uitvoerGateway ?? FakeUitvoerGateway(),
      ),
      // M8: de regel op O1 en O11. Standaard lege fakes zonder netwerk.
      meldingenGatewayProvider.overrideWithValue(
        meldingenGateway ?? FakeMeldingenGateway(),
      ),
      incidentGatewayProvider.overrideWithValue(
        incidentGateway ?? FakeIncidentGateway(),
      ),
      klokProvider.overrideWithValue(() => nu ?? testNu),
      keyValueStoreProvider.overrideWithValue(
        opslag ?? GeheugenKeyValueStore(),
      ),
      urlOpenerProvider.overrideWithValue((_) async => urlOpenerLukt),
      if (sessie != null)
        sessieControllerProvider.overrideWith(() => VasteSessie(sessie)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Een los M4-scherm in het thema, ingelogd als hulpvrager (tenzij anders),
/// zonder go_router. Voor navigatie-knoppen gebruik je pompHulpvragerApp.
Widget hhHulpvragerWikkel(
  Widget scherm, {
  required FakeKlusGateway klusGateway,
  SessieState? sessie,
  HhDichtheid dichtheid = HhDichtheid.groot,
  double tekstschaal = 1.0,
  bool urlOpenerLukt = true,
  ProviderContainer? container,
  FakeUitvoerGateway? uitvoerGateway,
}) {
  return UncontrolledProviderScope(
    container:
        container ??
        hulpvragerContainer(
          klusGateway: klusGateway,
          sessie: sessie ?? SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
          urlOpenerLukt: urlOpenerLukt,
          uitvoerGateway: uitvoerGateway,
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

/// De hele app met router en guard, ingelogd als hulpvrager via een
/// bewaard token. Landt op O1.
Future<ProviderContainer> pompHulpvragerApp(
  WidgetTester tester, {
  required FakeKlusGateway klusGateway,
  DateTime? nu,
  FakeUitvoerGateway? uitvoerGateway,
}) async {
  final opslag = GeheugenKeyValueStore({
    'hh_auth_token': testToken(HhRol.hulpvrager),
  });
  final container = hulpvragerContainer(
    klusGateway: klusGateway,
    opslag: opslag,
    nu: nu,
    uitvoerGateway: uitvoerGateway,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const HeitjeHulpApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

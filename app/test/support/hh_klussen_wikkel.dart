import 'package:heitjehulp_app/core/pb/fake_reactie_gateway.dart';
import 'package:heitjehulp_app/features/reacties/reacties_routes.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import 'package:heitjehulp_app/features/jongere/jongere_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/klussen_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/klussen/provider/klussen_providers.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/uitvoeren_routes.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:heitjehulp_app/core/pb/fake_xp_gateway.dart';

import 'hh_jongere_wikkel.dart';
import 'hh_toegang_wikkel.dart';

/// Een vaste "nu" voor de M5-tests: dinsdag 15 september 2026, 10:00 lokaal.
final klussenNu = DateTime(2026, 9, 15, 10);

/// Het middelpunt van de testwijk (Tiel-West); alle klussen met locatie
/// liggen hier omheen.
const wijkLat = 51.8865;
const wijkLon = 5.4126;

/// Klussen zoals de seed ze kent. [afstandKm] is een ruwe verschuiving in
/// breedtegraad: 0.009 graden is ongeveer 1 km.
HhKlus testKlus({
  required String id,
  String klustypeId = 'type-boodschappen',
  String klustypeNaam = 'boodschappen',
  String klustypeIcoon = 'shopping_cart',
  DateTime? wanneerVan,
  DateTime? wanneerTot,
  double? afstandKm = 0.5,
  HhKlusStatus status = HhKlusStatus.open,
  String toegewezenJongereId = '',
  int vergoedingCenten = 1000,
  String omschrijving = 'Weekboodschappen bij de Jumbo',
  String klusFotoUrl = '',
}) {
  final van = wanneerVan ?? klussenNu.add(const Duration(hours: 4));
  return HhKlus(
    id: id,
    hulpvragerId: 'id-oudere',
    status: status,
    klustypeId: klustypeId,
    klustypeNaam: klustypeNaam,
    klustypeIcoon: klustypeIcoon,
    richtduurMinuten: 60,
    omschrijving: omschrijving,
    adres: 'Prins Bernhardlaan 12, 4003 AB Tiel',
    lat: afstandKm == null ? null : wijkLat + afstandKm * 0.009,
    lon: afstandKm == null ? null : wijkLon,
    wanneerVan: van,
    wanneerTot: wanneerTot ?? van.add(const Duration(hours: 1)),
    vergoedingJongereCenten: vergoedingCenten,
    toegewezenJongereId: toegewezenJongereId,
    klusFotoUrl: klusFotoUrl,
  );
}

/// Drie open klussen (ochtend, middag, avond; boodschappen, tuin, tuin) plus
/// een zonder locatie, zoals de lijst ze op een gewone dag toont.
List<HhKlus> testOpenKlussen() => [
  testKlus(
    id: 'k-ochtend',
    wanneerVan: DateTime(2026, 9, 16, 9),
    afstandKm: 0.3,
  ),
  testKlus(
    id: 'k-middag',
    klustypeId: 'type-tuin',
    klustypeNaam: 'tuin',
    klustypeIcoon: 'yard',
    wanneerVan: DateTime(2026, 9, 16, 14),
    afstandKm: 1.2,
    vergoedingCenten: 1500,
    omschrijving: 'Heg knippen aan de voorkant',
  ),
  testKlus(
    id: 'k-avond',
    klustypeId: 'type-tuin',
    klustypeNaam: 'tuin',
    klustypeIcoon: 'yard',
    wanneerVan: DateTime(2026, 9, 17, 18, 30),
    afstandKm: 0.8,
    vergoedingCenten: 1500,
  ),
  testKlus(
    id: 'k-zonder-locatie',
    wanneerVan: DateTime(2026, 9, 18, 10),
    afstandKm: null,
    omschrijving: 'Nieuwe telefoon instellen',
  ),
];

/// Klussen van de test-jongere voor J14: vandaag, gepland, historie.
List<HhKlus> testMijnKlussen() => [
  testKlus(
    id: 'm-vandaag',
    status: HhKlusStatus.geaccepteerd,
    toegewezenJongereId: jongereId,
    wanneerVan: DateTime(2026, 9, 15, 15),
  ),
  testKlus(
    id: 'm-gepland',
    status: HhKlusStatus.geaccepteerd,
    toegewezenJongereId: jongereId,
    wanneerVan: DateTime(2026, 9, 20, 10),
    klustypeNaam: 'tuin',
    klustypeId: 'type-tuin',
  ),
  testKlus(
    id: 'm-historie',
    status: HhKlusStatus.afgerond,
    toegewezenJongereId: jongereId,
    wanneerVan: DateTime(2026, 9, 10, 10),
  ),
];

FakeKlussenGateway fakeKlussen({List<HhKlus>? open, List<HhKlus>? mijn}) =>
    FakeKlussenGateway(
      klussen: [...(open ?? testOpenKlussen()), ...(mijn ?? const [])],
      jongereId: jongereId,
    );

/// Kleinste geldige PNG (1x1), als "tegel" zodat de kaart in tests geen
/// netwerk raakt.
final Uint8List _tegelBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

class NepTegels extends TileProvider {
  NepTegels() : super();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_tegelBytes);
}

/// Zoals toegangContainer, plus de klussen-fake, nep-tegels en een vaste
/// klok. Ingelogd als goedgekeurde jongere tenzij anders.
ProviderContainer klussenContainer({
  required FakeKlussenGateway klussenGateway,
  FakeProfielGateway? profielGateway,
  GeheugenKeyValueStore? opslag,
  SessieState? sessie,
  DateTime? nu,
  FakeUitvoerGateway? uitvoerGateway,
  FakeBeoordelingGateway? beoordelingGateway,
  FakeReactieGateway? reactieGateway,
  FakeXpGateway? xpGateway,
}) {
  final container = ProviderContainer(
    // Geen automatische retry (Riverpod 3): een fake die bewust faalt zou
    // anders een Timer achterlaten na het einde van de test.
    retry: (_, _) => null,
    overrides: [
      ...toegangOverrides(
        gateway: fakeMetAlleRollen(),
        opslag: opslag,
        sessie: sessie,
        profielGateway:
            profielGateway ?? FakeProfielGateway.goedgekeurd(jongereId),
        klussenGateway: klussenGateway,
        uitvoerGateway: uitvoerGateway,
        beoordelingGateway: beoordelingGateway,
        reactieGateway: reactieGateway,
        xpGateway: xpGateway,
      ),
      klokProvider.overrideWithValue(() => nu ?? klussenNu),
      kaartTegelsProvider.overrideWithValue(NepTegels.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Een M5-scherm op zijn eigen route, met de echte jongere- en
/// klussenroutes en de landing op /jongere, zonder guard.
Widget hhKlussenWikkel(
  String pad, {
  required FakeKlussenGateway klussenGateway,
  FakeProfielGateway? profielGateway,
  SessieState? sessie,
  DateTime? nu,
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
  ProviderContainer? container,
  FakeUitvoerGateway? uitvoerGateway,
  FakeReactieGateway? reactieGateway,
}) {
  final router = GoRouter(
    initialLocation: pad,
    routes: [
      GoRoute(
        path: HhPaden.jongere,
        builder: (context, state) => const JongereStubScreen(),
      ),
      ...jongereRoutes(),
      ...klussenRoutes(),
      ...uitvoerenRoutes(),
      ...reactiesRoutes(),
    ],
  );
  return UncontrolledProviderScope(
    container:
        container ??
        klussenContainer(
          klussenGateway: klussenGateway,
          profielGateway: profielGateway,
          sessie: sessie ?? SessieIngelogd(testGebruiker(HhRol.jongere)),
          nu: nu,
          uitvoerGateway: uitvoerGateway,
          reactieGateway: reactieGateway,
        ),
    child: MaterialApp.router(
      theme: hhThema(dichtheid),
      routerConfig: router,
      builder: (context, kind) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(tekstschaal)),
        child: HhDichtheidScope(dichtheid: dichtheid, child: kind!),
      ),
    ),
  );
}

/// De hele app met router en guard, ingelogd als jongere via een bewaard
/// token. Landt op J11.
Future<ProviderContainer> pompKlussenApp(
  WidgetTester tester, {
  required FakeKlussenGateway klussenGateway,
  FakeProfielGateway? profielGateway,
  DateTime? nu,
  FakeUitvoerGateway? uitvoerGateway,
  FakeBeoordelingGateway? beoordelingGateway,
  FakeReactieGateway? reactieGateway,
}) async {
  final opslag = GeheugenKeyValueStore({
    'hh_auth_token': testToken(HhRol.jongere),
  });
  final container = klussenContainer(
    klussenGateway: klussenGateway,
    profielGateway: profielGateway,
    opslag: opslag,
    nu: nu,
    uitvoerGateway: uitvoerGateway,
    beoordelingGateway: beoordelingGateway,
    reactieGateway: reactieGateway,
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

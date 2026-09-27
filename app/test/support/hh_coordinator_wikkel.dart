import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_coordinator_gateway.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/coordinator/coordinator_routes.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_coordinator_klus.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_incident.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_kandidaat.dart';
import 'package:heitjehulp_app/features/coordinator/provider/coordinator_providers.dart';
import 'package:heitjehulp_app/features/coordinator/screen/coordinator_stub_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_toegang_wikkel.dart';

/// Een vaste "nu" voor de M10-tests: dinsdag 15 september 2026, 10:00 lokaal.
final coordinatorNu = DateTime(2026, 9, 15, 10);

/// De id's van de nep-wijken uit de M10-tests.
const wijkWestId = 'wijk-tiel-west';
const wijkPassewaaijId = 'wijk-passewaaij';
const wijkWestNaam = 'Tiel-West';
const wijkPassewaaijNaam = 'Passewaaij';

String get coordinatorId => testGebruiker(HhRol.coordinator).id;

HhIncident testIncident({
  required String id,
  HhIncidentSoort soort = HhIncidentSoort.probleem,
  DateTime? aangemaaktOp,
  String melderNaam = 'Daan Verhoeven',
  String melderTelefoon = '06-10000003',
  String klusId = '',
  String klusOmschrijving = '',
  String omschrijving = 'Tablet start niet op, oplader lijkt kapot.',
  String afhandeling = '',
}) => HhIncident(
  id: id,
  soort: soort,
  aangemaaktOp: aangemaaktOp ?? coordinatorNu.subtract(const Duration(hours: 1)),
  melderId: 'id-melder-$id',
  melderNaam: melderNaam,
  melderTelefoon: melderTelefoon,
  klusId: klusId,
  klusOmschrijving: klusOmschrijving,
  omschrijving: omschrijving,
  afhandeling: afhandeling,
);

/// Drie meldingen: een open probleem, een open noodmelding en een
/// afgehandelde.
List<HhIncident> testIncidenten() => [
  testIncident(
    id: 'i-probleem',
    aangemaaktOp: coordinatorNu.subtract(const Duration(hours: 2)),
    klusId: 'k-open-oud',
    klusOmschrijving: 'Heg knippen aan de voorkant',
  ),
  testIncident(
    id: 'i-nood',
    soort: HhIncidentSoort.nood,
    aangemaaktOp: coordinatorNu.subtract(const Duration(minutes: 20)),
    melderNaam: 'Mevrouw A. de Vries',
    melderTelefoon: '0344-100001',
    omschrijving: 'Gevallen in de gang, kan niet opstaan.',
  ),
  testIncident(
    id: 'i-afgehandeld',
    aangemaaktOp: coordinatorNu.subtract(const Duration(days: 1)),
    melderNaam: 'Sanne Bakker',
    omschrijving: 'Kon de deur niet vinden.',
    afhandeling: 'Gebeld, opgelost.',
  ),
];

HhCoordinatorKlus testCoordinatorKlus({
  required String id,
  HhKlusStatus status = HhKlusStatus.open,
  DateTime? aangemaaktOp,
  String klustypeNaam = 'boodschappen',
  String oudereNaam = 'Mevrouw A. de Vries',
  String oudereWijkId = wijkWestId,
  String oudereWijkNaam = wijkWestNaam,
  String toegewezenJongereId = '',
  String toegewezenJongereNaam = '',
  String omschrijving = 'Weekboodschappen bij de Jumbo',
}) => HhCoordinatorKlus(
  id: id,
  status: status,
  aangemaaktOp:
      aangemaaktOp ?? coordinatorNu.subtract(const Duration(days: 2)),
  klustypeNaam: klustypeNaam,
  omschrijving: omschrijving,
  adres: 'Prins Bernhardlaan 12, 4003 AB Tiel',
  wanneerVan: coordinatorNu.add(const Duration(days: 1, hours: 4)),
  wanneerTot: coordinatorNu.add(const Duration(days: 1, hours: 5)),
  oudereId: 'id-oudere',
  oudereNaam: oudereNaam,
  oudereWijkId: oudereWijkId,
  oudereWijkNaam: oudereWijkNaam,
  toegewezenJongereId: toegewezenJongereId,
  toegewezenJongereNaam: toegewezenJongereNaam,
);

/// Twee open klussen (de oudste eerst) en een die al is toegewezen.
List<HhCoordinatorKlus> testCoordinatorKlussen() => [
  testCoordinatorKlus(
    id: 'k-open-oud',
    aangemaaktOp: coordinatorNu.subtract(const Duration(days: 3)),
    klustypeNaam: 'tuin',
    omschrijving: 'Heg knippen aan de voorkant',
  ),
  testCoordinatorKlus(
    id: 'k-open-nieuw',
    aangemaaktOp: coordinatorNu.subtract(const Duration(hours: 4)),
    oudereNaam: 'Meneer B. Jansen',
    oudereWijkId: wijkPassewaaijId,
    oudereWijkNaam: wijkPassewaaijNaam,
  ),
  testCoordinatorKlus(
    id: 'k-toegewezen',
    status: HhKlusStatus.geaccepteerd,
    aangemaaktOp: coordinatorNu.subtract(const Duration(days: 1)),
    toegewezenJongereId: 'id-jongere-1',
    toegewezenJongereNaam: 'Yusuf el Amrani',
  ),
];

/// Drie goedgekeurde jongeren: twee in Tiel-West, een in Passewaaij.
List<HhKandidaat> testKandidaten() => const [
  HhKandidaat(
    id: 'id-jongere-1',
    naam: 'Yusuf el Amrani',
    wijkId: wijkWestId,
    wijkNaam: wijkWestNaam,
    klussenAantal: 3,
  ),
  HhKandidaat(
    id: 'id-jongere-2',
    naam: 'Sanne Bakker',
    wijkId: wijkWestId,
    wijkNaam: wijkWestNaam,
    klussenAantal: 1,
  ),
  HhKandidaat(
    id: 'id-jongere-3',
    naam: 'Daan Verhoeven',
    wijkId: wijkPassewaaijId,
    wijkNaam: wijkPassewaaijNaam,
  ),
];

FakeCoordinatorGateway fakeCoordinator({
  List<HhIncident>? incidenten,
  List<HhCoordinatorKlus>? klussen,
  List<HhKandidaat>? jongeren,
}) => FakeCoordinatorGateway(
  incidenten: incidenten ?? testIncidenten(),
  klussen: klussen ?? testCoordinatorKlussen(),
  jongeren: jongeren ?? testKandidaten(),
  coordinatorId: coordinatorId,
);

/// Houdt bij hoe vaak het toestel trilde, zonder een plugin aan te roepen.
class TrilTeller {
  int aantal = 0;

  Future<void> tril() async => aantal++;
}

/// Zoals toegangContainer, plus de coordinator-fake, een vaste klok en een
/// trilteller. Ingelogd als coordinator tenzij anders.
ProviderContainer coordinatorContainer({
  required FakeCoordinatorGateway gateway,
  TrilTeller? tril,
  GeheugenKeyValueStore? opslag,
  SessieState? sessie,
  DateTime? nu,
  bool urlOpenerLukt = true,
  /// False: geen vaste sessie, de app herstelt hem zelf uit [opslag]. Dat
  /// is wat de stroomtests nodig hebben, want daar moet de guard lopen.
  bool metVasteSessie = true,
}) {
  final container = ProviderContainer(
    // Geen automatische retry (Riverpod 3): een fake die bewust faalt zou
    // anders een Timer achterlaten na het einde van de test.
    retry: (_, _) => null,
    overrides: [
      ...toegangOverrides(
        gateway: fakeMetAlleRollen(),
        opslag: opslag,
        sessie: metVasteSessie
            ? (sessie ?? SessieIngelogd(testGebruiker(HhRol.coordinator)))
            : null,
        urlOpenerLukt: urlOpenerLukt,
        coordinatorGateway: gateway,
      ),
      trilProvider.overrideWithValue((tril ?? TrilTeller()).tril),
      klokProvider.overrideWithValue(() => nu ?? coordinatorNu),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(gateway.sluitStroom);
  return container;
}

/// Een M10-scherm op zijn eigen route, met de echte coordinatorroutes en de
/// landing op /coordinator, zonder guard.
Widget hhCoordinatorWikkel(
  String pad, {
  required FakeCoordinatorGateway gateway,
  TrilTeller? tril,
  SessieState? sessie,
  DateTime? nu,
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
  bool urlOpenerLukt = true,
  ProviderContainer? container,
}) {
  final router = GoRouter(
    initialLocation: pad,
    routes: [
      GoRoute(
        path: HhPaden.coordinator,
        builder: (context, state) => const CoordinatorStubScreen(),
      ),
      ...coordinatorRoutes(),
    ],
  );
  return UncontrolledProviderScope(
    container:
        container ??
        coordinatorContainer(
          gateway: gateway,
          tril: tril,
          sessie: sessie,
          nu: nu,
          urlOpenerLukt: urlOpenerLukt,
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

/// De hele app met router en guard, ingelogd als coordinator via een
/// bewaard token. Landt op C1.
Future<ProviderContainer> pompCoordinatorApp(
  WidgetTester tester, {
  required FakeCoordinatorGateway gateway,
  TrilTeller? tril,
  HhRol rol = HhRol.coordinator,
  DateTime? nu,
}) async {
  final opslag = GeheugenKeyValueStore({'hh_auth_token': testToken(rol)});
  final container = coordinatorContainer(
    gateway: gateway,
    tril: tril,
    opslag: opslag,
    nu: nu,
    metVasteSessie: false,
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

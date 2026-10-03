import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/status_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/klussen_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/uitvoeren_routes.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_hulpvrager_wikkel.dart';
import 'hh_jongere_wikkel.dart';
import 'hh_klussen_wikkel.dart';
import 'hh_toegang_wikkel.dart';

/// Een vaste "nu" voor de M6-tests: dinsdag 15 september 2026, 10:00 lokaal.
final uitvoerNu = DateTime(2026, 9, 15, 10);

String get oudereId => testGebruiker(HhRol.hulpvrager).id;

const testJongereNaam = 'Sanne Bakker';
const testOudereNaam = 'Mevrouw de Vries';
const testAdres = 'Prins Bernhardlaan 12, 4003 AB Tiel';

/// Een klus zoals J15 en O7 hem zien: van de test-oudere, toegewezen aan de
/// test-jongere (tenzij [metJongere] false).
HhKlus uitvoerKlus({
  String id = 'k-uitvoeren',
  HhKlusStatus status = HhKlusStatus.geaccepteerd,
  bool metJongere = true,
  DateTime? wanneerVan,
  String omschrijving = 'Weekboodschappen bij de Jumbo',
  String contactNaam = 'Dochter Jansen',
  bool wordtNagekeken = false,
  String afkeurReden = '',
}) {
  final van = wanneerVan ?? uitvoerNu.add(const Duration(hours: 4));
  return HhKlus(
    id: id,
    hulpvragerId: oudereId,
    status: status,
    klustypeId: 'type-boodschappen',
    klustypeNaam: 'boodschappen',
    klustypeIcoon: 'shopping_cart',
    richtduurMinuten: 60,
    omschrijving: omschrijving,
    adres: testAdres,
    wanneerVan: van,
    wanneerTot: van.add(const Duration(hours: 1)),
    vergoedingJongereCenten: 1000,
    toegewezenJongereId: metJongere ? jongereId : '',
    oudereNaam: testOudereNaam,
    oudereContactNaam: contactNaam,
    jongereNaam: metJongere ? testJongereNaam : '',
    wordtNagekeken: wordtNagekeken,
    afkeurReden: afkeurReden,
  );
}

/// De logregels die bij [status] horen: leeg -> open -> geaccepteerd -> ...
List<HhKlusLogregel> uitvoerLogregels(
  String klusId,
  HhKlusStatus status, {
  DateTime? begin,
}) {
  final start = begin ?? uitvoerNu;
  final reeks = <(HhKlusStatus?, HhKlusStatus)>[
    (null, HhKlusStatus.open),
    (HhKlusStatus.open, HhKlusStatus.geaccepteerd),
    if (status == HhKlusStatus.onderweg ||
        status == HhKlusStatus.bezig ||
        status == HhKlusStatus.afgerond)
      (HhKlusStatus.geaccepteerd, HhKlusStatus.onderweg),
    if (status == HhKlusStatus.bezig || status == HhKlusStatus.afgerond)
      (HhKlusStatus.onderweg, HhKlusStatus.bezig),
    if (status == HhKlusStatus.afgerond)
      (HhKlusStatus.bezig, HhKlusStatus.afgerond),
  ];
  return [
    for (var i = 0; i < reeks.length; i++)
      HhKlusLogregel(
        id: 'log-$klusId-$i',
        klusId: klusId,
        van: reeks[i].$1,
        naar: reeks[i].$2,
        doorId: reeks[i].$1 == null ? oudereId : jongereId,
        wanneer: start.add(Duration(minutes: 15 * i)),
      ),
  ];
}

/// Een uitvoer-fake met één klus en de bijbehorende logregels. [ikBen] is
/// wie de fake als ingelogde gebruiker ziet (standaard de jongere).
FakeUitvoerGateway fakeUitvoer({
  List<HhKlus>? klussen,
  HhKlusStatus status = HhKlusStatus.geaccepteerd,
  String? ikBen,
  String nummer = '06-10000001',
}) {
  final lijst = klussen ?? [uitvoerKlus(status: status)];
  final fake = FakeUitvoerGateway(
    klussen: lijst,
    logregels: [for (final k in lijst) ...uitvoerLogregels(k.id, k.status)],
    ikBenId: ikBen ?? jongereId,
    nummerVan: nummer,
    naamVan: testOudereNaam,
    klok: uitvoerNu,
  );
  addTearDown(fake.sluit);
  return fake;
}

/// Een M6-scherm van de JONGERE (J15) op zijn eigen route, met de echte
/// klussen- en uitvoerroutes, zonder guard.
Widget hhUitvoerenWikkel(
  String pad, {
  required FakeUitvoerGateway uitvoerGateway,
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) {
  final router = GoRouter(
    initialLocation: pad,
    routes: [
      GoRoute(
        path: HhPaden.jongere,
        builder: (context, state) => const JongereStubScreen(),
      ),
      ...klussenRoutes(),
      ...uitvoerenRoutes(),
    ],
  );
  return UncontrolledProviderScope(
    container: klussenContainer(
      klussenGateway: fakeKlussen(mijn: testMijnKlussen()),
      sessie: SessieIngelogd(testGebruiker(HhRol.jongere)),
      nu: uitvoerNu,
      uitvoerGateway: uitvoerGateway,
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

/// Een M6-scherm van de OUDERE (O7, O8) op zijn eigen route.
Widget hhStatusWikkel(
  String pad, {
  required FakeUitvoerGateway uitvoerGateway,
  HhDichtheid dichtheid = HhDichtheid.groot,
  double tekstschaal = 1.0,
}) {
  final router = GoRouter(initialLocation: pad, routes: statusRoutes());
  return UncontrolledProviderScope(
    container: hulpvragerContainer(
      klusGateway: fakeKlusGateway(),
      sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
      nu: uitvoerNu,
      uitvoerGateway: uitvoerGateway,
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

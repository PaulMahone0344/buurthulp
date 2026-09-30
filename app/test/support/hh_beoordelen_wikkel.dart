import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/hulpvrager/beoordelen/beoordelen_routes.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/status_routes.dart';
import 'package:heitjehulp_app/features/jongere/jongere_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/klussen_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/model/hh_beoordeling.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/reputatie_routes.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/uitvoeren_routes.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_hulpvrager_wikkel.dart';
import 'hh_jongere_wikkel.dart';
import 'hh_klussen_wikkel.dart';
import 'hh_toegang_wikkel.dart';
import 'hh_uitvoeren_wikkel.dart';

/// Een afgeronde klus van de test-oudere, gedaan door de test-jongere.
HhKlus afgerondeKlus({String id = 'k-uitvoeren'}) =>
    uitvoerKlus(id: id, status: HhKlusStatus.afgerond);

/// Een beoordeling-fake die de rules en de hook naspeelt, met [klussen] als
/// wat de server van de klussen weet. [ikBen] is wie er ingelogd is.
FakeBeoordelingGateway fakeBeoordeling({
  List<HhKlus>? klussen,
  List<HhBeoordeling> beoordelingen = const [],
  String? ikBen,
}) => FakeBeoordelingGateway(
  klussen: klussen ?? [afgerondeKlus()],
  beoordelingen: beoordelingen,
  ikBenId: ikBen ?? jongereId,
);

Widget _app(
  GoRouter router,
  ProviderContainer container,
  HhDichtheid dichtheid,
  double tekstschaal,
) => UncontrolledProviderScope(
  container: container,
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

/// Een M7-scherm van de JONGERE (J17, J19 via de tab Profiel) met de echte
/// klussen-, uitvoer- en reputatieroutes, zonder guard.
Widget hhReputatieWikkel(
  String pad, {
  required FakeUitvoerGateway uitvoerGateway,
  required FakeBeoordelingGateway beoordelingGateway,
  List<HhKlus>? mijnKlussen,
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
      ...jongereRoutes(),
      ...klussenRoutes(),
      ...uitvoerenRoutes(),
      ...reputatieRoutes(),
    ],
  );
  final container = klussenContainer(
    klussenGateway: fakeKlussen(mijn: mijnKlussen ?? testMijnKlussen()),
    sessie: SessieIngelogd(testGebruiker(HhRol.jongere)),
    nu: uitvoerNu,
    uitvoerGateway: uitvoerGateway,
    beoordelingGateway: beoordelingGateway,
  );
  return _app(router, container, dichtheid, tekstschaal);
}

/// Een M7-scherm van de OUDERE (O9, en O7/O8 met hun aanhaakpunt).
Widget hhBeoordelenWikkel(
  String pad, {
  required FakeUitvoerGateway uitvoerGateway,
  required FakeBeoordelingGateway beoordelingGateway,
  HhDichtheid dichtheid = HhDichtheid.groot,
  double tekstschaal = 1.0,
}) {
  final router = GoRouter(
    initialLocation: pad,
    routes: [...statusRoutes(), ...beoordelenRoutes()],
  );
  final container = hulpvragerContainer(
    klusGateway: fakeKlusGateway(),
    sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
    nu: uitvoerNu,
    uitvoerGateway: uitvoerGateway,
    beoordelingGateway: beoordelingGateway,
  );
  return _app(router, container, dichtheid, tekstschaal);
}

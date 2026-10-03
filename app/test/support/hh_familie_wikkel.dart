import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_familie_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klus_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/familie/familie_routes.dart';
import 'package:heitjehulp_app/features/familie/model/hh_koppeling.dart';
import 'package:heitjehulp_app/features/familie/screen/familie_stub_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/hulpvrager_routes.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_hulpvrager_wikkel.dart';
import 'hh_toegang_wikkel.dart';
import 'hh_uitvoeren_wikkel.dart';

String get familieId => testGebruiker(HhRol.familie).id;
String get familieNaam => testGebruiker(HhRol.familie).naam;
const testOudereEmail = 'oma@voorbeeld.nl';

/// Een koppeling van het test-familielid met de test-oudere.
HhKoppeling testKoppeling({
  String id = 'kp-1',
  KoppelingStatus status = KoppelingStatus.actief,
  Set<FamilieRecht> rechten = const {
    FamilieRecht.meekijken,
    FamilieRecht.plaatsen,
  },
  String? oudere,
  String oudereNaam = testOudereNaam,
}) => HhKoppeling(
  id: id,
  oudereId: oudere ?? oudereId,
  familielidId: familieId,
  status: status,
  rechten: status == KoppelingStatus.actief ? rechten : const {},
  oudereNaam: status == KoppelingStatus.actief ? oudereNaam : '',
  familielidNaam: familieNaam,
);

FakeFamilieGateway fakeFamilie({List<HhKoppeling> koppelingen = const []}) =>
    FakeFamilieGateway(
      koppelingen: koppelingen,
      ouderenOpEmail: {testOudereEmail: (id: oudereId, naam: testOudereNaam)},
      ikBenId: familieId,
      ikBenNaam: familieNaam,
    );

/// Een M9-scherm op zijn eigen route, ingelogd als [rol] (standaard het
/// familielid), met de landing /familie, de familieroutes en de M4-stroom
/// (voor F2), zonder guard.
Widget hhFamilieWikkel(
  String pad, {
  HhRol rol = HhRol.familie,
  FakeFamilieGateway? familieGateway,
  FakeUitvoerGateway? uitvoerGateway,
  FakeKlusGateway? klusGateway,
  FakeMeldingenGateway? meldingenGateway,
  HhDichtheid? dichtheid,
  double tekstschaal = 1.0,
}) {
  final router = GoRouter(
    initialLocation: pad,
    routes: [
      GoRoute(
        path: HhPaden.familie,
        builder: (context, state) => const FamilieStubScreen(),
      ),
      GoRoute(
        path: HhPaden.hulpvrager,
        builder: (context, state) => const HulpvragerStubScreen(),
      ),
      ...familieRoutes(),
      ...hulpvragerRoutes(),
    ],
  );
  final container = hulpvragerContainer(
    klusGateway: klusGateway ?? fakeKlusGateway(),
    sessie: SessieIngelogd(testGebruiker(rol)),
    nu: uitvoerNu,
    uitvoerGateway: uitvoerGateway,
    familieGateway: familieGateway,
    meldingenGateway: meldingenGateway,
  );
  // Oudere-schermen blijven ook in de grote stand getest.
  final d =
      dichtheid ??
      (rol == HhRol.hulpvrager ? HhDichtheid.groot : HhDichtheid.normaal);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: hhThema(d),
      routerConfig: router,
      builder: (context, kind) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(tekstschaal)),
        child: HhDichtheidScope(dichtheid: d, child: kind!),
      ),
    ),
  );
}

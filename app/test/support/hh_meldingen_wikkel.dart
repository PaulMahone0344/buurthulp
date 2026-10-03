import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_incident_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/familie/screen/familie_stub_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/hulpvrager_routes.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/status_routes.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/veiligheid_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/klussen_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/provider/klussen_providers.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/uitvoeren_routes.dart';
import 'package:heitjehulp_app/features/meldingen/meldingen_routes.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_jongere_wikkel.dart' show jongereId;
import 'hh_klussen_wikkel.dart' show NepTegels, testMijnKlussen;
import 'hh_toegang_wikkel.dart';
import 'hh_uitvoeren_wikkel.dart';

/// Een vaste "nu" voor de M8-tests (dezelfde als M6).
DateTime get meldingNu => uitvoerNu;

/// Een melding zoals de hook hem maakt.
HhMelding testMelding({
  String id = 'm1',
  String ontvanger = '',
  HhMeldingSoort soort = HhMeldingSoort.onderweg,
  String klus = 'k-uitvoeren',
  String incident = '',
  String titel = 'Onderweg naar u',
  String tekst = 'Sanne is onderweg naar u.',
  int minutenGeleden = 5,
  bool gelezen = false,
}) => HhMelding(
  id: id,
  ontvangerId: ontvanger,
  soort: soort,
  klusId: klus,
  incidentId: incident,
  titel: titel,
  tekst: tekst,
  gemaakt: meldingNu.subtract(Duration(minutes: minutenGeleden)),
  gelezenOp: gelezen ? meldingNu : null,
);

FakeMeldingenGateway fakeMeldingen([List<HhMelding> meldingen = const []]) {
  final fake = FakeMeldingenGateway(meldingen: meldingen);
  addTearDown(fake.sluit);
  return fake;
}

/// Een M8-scherm op zijn eigen route, ingelogd als [rol], met de echte
/// routes van toegang-landing, klussen, uitvoeren, status, veiligheid en
/// meldingen, zonder guard.
Widget hhMeldingenWikkel(
  String pad, {
  HhRol rol = HhRol.jongere,
  FakeMeldingenGateway? meldingenGateway,
  FakeIncidentGateway? incidentGateway,
  FakeUitvoerGateway? uitvoerGateway,
  HhDichtheid? dichtheid,
  double tekstschaal = 1.0,
}) {
  final router = GoRouter(
    initialLocation: pad,
    routes: [
      GoRoute(
        path: HhPaden.jongere,
        builder: (context, state) => const JongereStubScreen(),
      ),
      GoRoute(
        path: HhPaden.hulpvrager,
        builder: (context, state) => const HulpvragerStubScreen(),
      ),
      GoRoute(
        path: HhPaden.familie,
        builder: (context, state) => const FamilieStubScreen(),
      ),
      ...hulpvragerRoutes(),
      ...klussenRoutes(),
      ...uitvoerenRoutes(),
      ...statusRoutes(),
      ...veiligheidRoutes(),
      ...meldingenRoutes(),
    ],
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...toegangOverrides(
        gateway: fakeMetAlleRollen(),
        sessie: SessieIngelogd(testGebruiker(rol)),
        klussenGateway: FakeKlussenGateway(
          klussen: testMijnKlussen(),
          jongereId: jongereId,
        ),
        uitvoerGateway: uitvoerGateway,
        meldingenGateway: meldingenGateway,
        incidentGateway: incidentGateway,
      ),
      klokProvider.overrideWithValue(() => meldingNu),
      kaartTegelsProvider.overrideWithValue(NepTegels.new),
    ],
  );
  addTearDown(container.dispose);
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

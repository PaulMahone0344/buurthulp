import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_chat_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/chat/chat_routes.dart';
import 'package:heitjehulp_app/features/chat/model/hh_bericht.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/status_routes.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/veiligheid_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/klussen_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/klussen/provider/klussen_providers.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/uitvoeren_routes.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_jongere_wikkel.dart' show jongereId;
import 'hh_klussen_wikkel.dart' show NepTegels;
import 'hh_toegang_wikkel.dart';
import 'hh_uitvoeren_wikkel.dart';

/// Een bericht in het gesprek van de test-klus (k-uitvoeren) met de
/// test-jongere als helper.
HhBericht testBericht({
  String id = 'b1',
  String klus = 'k-uitvoeren',
  String? afzender,
  String? helper,
  String tekst = 'Hoi! Ik kom straks.',
  HhBerichtSoort soort = HhBerichtSoort.tekst,
  int minutenGeleden = 30,
  bool gelezen = false,
  bool gefilterd = false,
}) => HhBericht(
  id: id,
  klusId: klus,
  afzenderId: afzender ?? jongereId,
  helperId: helper ?? jongereId,
  tekst: tekst,
  soort: soort,
  gemaakt: uitvoerNu.subtract(Duration(minutes: minutenGeleden)),
  gelezenOp: gelezen ? uitvoerNu : null,
  isGefilterd: gefilterd,
);

FakeChatGateway fakeChat([List<HhBericht> berichten = const []]) {
  final fake = FakeChatGateway(
    berichten: berichten,
    helperVanKlus: {'k-uitvoeren': jongereId},
    klok: uitvoerNu.toUtc(),
  );
  addTearDown(fake.sluit);
  return fake;
}

/// Een B6-scherm op zijn eigen route, ingelogd als [rol] (jongere = de
/// helper, hulpvrager = de bewoner), met de echte routes van chat, status,
/// klussen, uitvoeren en veiligheid, zonder guard.
Widget hhChatWikkel(
  String pad, {
  required FakeChatGateway chatGateway,
  HhRol rol = HhRol.jongere,
  FakeUitvoerGateway? uitvoerGateway,
  List<HhKlus> mijnKlussen = const [],
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
      GoRoute(
        path: HhPaden.hulpvrager,
        builder: (context, state) => const HulpvragerStubScreen(),
      ),
      ...klussenRoutes(),
      ...uitvoerenRoutes(),
      ...statusRoutes(),
      ...veiligheidRoutes(),
      ...chatRoutes(),
    ],
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...toegangOverrides(
        gateway: fakeMetAlleRollen(),
        sessie: SessieIngelogd(testGebruiker(rol)),
        klussenGateway: FakeKlussenGateway(
          klussen: mijnKlussen,
          jongereId: jongereId,
        ),
        uitvoerGateway:
            uitvoerGateway ??
            fakeUitvoer(ikBen: rol == HhRol.jongere ? jongereId : oudereId),
        chatGateway: chatGateway,
      ),
      klokProvider.overrideWithValue(() => uitvoerNu),
      kaartTegelsProvider.overrideWithValue(NepTegels.new),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
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
}

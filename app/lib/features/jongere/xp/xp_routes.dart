import 'package:go_router/go_router.dart';

import '../klussen/paden_klussen.dart';
import 'model/hh_xp.dart';
import 'paden_xp.dart';
import 'screen/beloning_screen.dart';
import 'screen/verdiensten_screen.dart';
import 'screen/verklaring_screen.dart';

/// De routes van B9. Wordt in lib/app/router.dart met een spread
/// toegevoegd; de sessie- en screening-guard gelden ook hier.
List<RouteBase> xpRoutes() => [
  GoRoute(
    path: HhPadenXp.beloningPatroon,
    // Zonder beloning (bijv. na een herstart): meteen naar het Profiel.
    redirect: (context, state) =>
        state.extra is HhBeloning ? null : HhPadenKlussen.profiel,
    builder: (context, state) => BeloningScreen(
      klusId: state.pathParameters['id'] ?? '',
      beloning: state.extra as HhBeloning,
    ),
  ),
  GoRoute(
    path: HhPadenXp.verdiensten,
    builder: (context, state) => const VerdienstenScreen(),
  ),
  GoRoute(
    path: HhPadenXp.verklaring,
    builder: (context, state) => const VerklaringScreen(),
  ),
];

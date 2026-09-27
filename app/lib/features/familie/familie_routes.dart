import 'package:go_router/go_router.dart';

import 'paden_familie.dart';
import 'screen/familie_hulpvraag_screen.dart';
import 'screen/familie_oudere_screen.dart';
import 'screen/koppelen_screen.dart';

/// De routes van M9 voor het familielid (aanvragen, F3, F3-detail). F1 zit
/// op de rolroute /familie (FamilieStubScreen bouwt FamilieHomeScreen); F2
/// is de M4-stroom. Wordt in lib/app/router.dart met een spread toegevoegd;
/// de sessie-guard daar geldt ook hier.
List<RouteBase> familieRoutes() => [
  GoRoute(
    path: HhPadenFamilie.koppelen,
    builder: (context, state) => const KoppelenScreen(),
  ),
  GoRoute(
    path: HhPadenFamilie.ouderePatroon,
    builder: (context, state) =>
        FamilieOudereScreen(oudereId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: HhPadenFamilie.hulpvraagPatroon,
    builder: (context, state) => FamilieHulpvraagScreen(
      oudereId: state.pathParameters['id'] ?? '',
      klusId: state.pathParameters['klusId'] ?? '',
    ),
  ),
];

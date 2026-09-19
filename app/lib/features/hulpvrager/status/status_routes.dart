import 'package:go_router/go_router.dart';

import 'paden_status.dart';
import 'screen/hulpvraag_status_screen.dart';
import 'screen/hulpvragen_lijst_screen.dart';

/// De routes van M6 aan de kant van de oudere: O8 (de lijst) en O7 (één
/// hulpvraag). Wordt in lib/app/router.dart met een spread toegevoegd; de
/// sessie-guard daar geldt ook hier.
List<RouteBase> statusRoutes() => [
  GoRoute(
    path: HhPadenStatus.hulpvragen,
    builder: (context, state) => const HulpvragenLijstScreen(),
  ),
  GoRoute(
    path: HhPadenStatus.hulpvraagPatroon,
    builder: (context, state) =>
        HulpvraagStatusScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

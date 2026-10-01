import 'package:go_router/go_router.dart';

import 'paden_reputatie.dart';
import 'screen/beoordeling_geven_screen.dart';

/// De route van M7 aan de kant van de jongere (J17). Wordt in
/// lib/app/router.dart met een spread toegevoegd; de sessie-guard en de
/// screening-guard daar gelden ook hier. J19 hangt aan de bestaande tab
/// Profiel (klussenRoutes).
List<RouteBase> reputatieRoutes() => [
  GoRoute(
    path: HhPadenReputatie.beoordelenPatroon,
    builder: (context, state) =>
        BeoordelingGevenScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

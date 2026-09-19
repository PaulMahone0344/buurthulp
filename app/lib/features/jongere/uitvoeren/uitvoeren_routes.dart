import 'package:go_router/go_router.dart';

import 'paden_uitvoeren.dart';
import 'screen/klus_uitvoeren_screen.dart';

/// De route van M6 aan de kant van de jongere (J15). Wordt in
/// lib/app/router.dart met een spread toegevoegd; de sessie-guard en de
/// screening-guard daar gelden ook hier.
List<RouteBase> uitvoerenRoutes() => [
  GoRoute(
    path: HhPadenUitvoeren.uitvoerenPatroon,
    builder: (context, state) =>
        KlusUitvoerenScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

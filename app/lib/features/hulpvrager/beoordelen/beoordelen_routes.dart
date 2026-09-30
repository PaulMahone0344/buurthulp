import 'package:go_router/go_router.dart';

import 'paden_beoordelen.dart';
import 'screen/hulpvraag_beoordelen_screen.dart';

/// De route van M7 aan de kant van de oudere (O9). Wordt in
/// lib/app/router.dart met een spread toegevoegd; de sessie-guard daar geldt
/// ook hier.
List<RouteBase> beoordelenRoutes() => [
  GoRoute(
    path: HhPadenBeoordelen.beoordelenPatroon,
    builder: (context, state) =>
        HulpvraagBeoordelenScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

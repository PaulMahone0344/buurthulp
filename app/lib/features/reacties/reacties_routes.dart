import 'package:go_router/go_router.dart';

import 'paden_reacties.dart';
import 'screen/kies_helper_screen.dart';
import 'screen/reactie_verstuurd_screen.dart';

/// De routes van B5. Wordt in lib/app/router.dart met een spread toegevoegd;
/// de sessie- en screening-guard daar gelden ook hier.
List<RouteBase> reactiesRoutes() => [
  GoRoute(
    path: HhPadenReacties.verstuurdPatroon,
    builder: (context, state) => ReactieVerstuurdScreen(
      klusId: state.pathParameters['id'] ?? '',
      wachtOpOuder: state.uri.queryParameters['ouder'] == '1',
    ),
  ),
  GoRoute(
    path: HhPadenReacties.kiesPatroon,
    builder: (context, state) =>
        KiesHelperScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

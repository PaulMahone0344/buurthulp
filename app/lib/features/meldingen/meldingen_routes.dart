import 'package:go_router/go_router.dart';

import 'paden_meldingen.dart';
import 'screen/meldingen_screen.dart';

/// De route van M8 voor het meldingen-overzicht. Wordt in
/// lib/app/router.dart met een spread toegevoegd; de sessie-guard daar
/// geldt ook hier.
List<RouteBase> meldingenRoutes() => [
  GoRoute(
    path: HhPadenMeldingen.overzicht,
    builder: (context, state) => const MeldingenScreen(),
  ),
];

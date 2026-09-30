import 'package:go_router/go_router.dart';

import 'paden_veiligheid.dart';
import 'screen/bel_ons_screen.dart';
import 'screen/probleem_melden_screen.dart';

/// De routes van M8 voor O10 en O11. Wordt in lib/app/router.dart met een
/// spread toegevoegd; de sessie-guard daar geldt ook hier.
List<RouteBase> veiligheidRoutes() => [
  GoRoute(
    path: HhPadenVeiligheid.belOns,
    builder: (context, state) => const BelOnsScreen(),
  ),
  GoRoute(
    path: HhPadenVeiligheid.probleem,
    builder: (context, state) => ProbleemMeldenScreen(
      klusId: state.uri.queryParameters[HhPadenVeiligheid.klusParameter] ?? '',
    ),
  ),
];

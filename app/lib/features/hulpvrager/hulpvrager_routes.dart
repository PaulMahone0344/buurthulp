import 'package:go_router/go_router.dart';

import 'paden_hulpvrager.dart';
import 'screen/hulp_vragen_bevestigen_screen.dart';
import 'screen/hulp_vragen_verstuurd_screen.dart';
import 'screen/hulp_vragen_waar_screen.dart';
import 'screen/hulp_vragen_wanneer_screen.dart';
import 'screen/hulp_vragen_wat_screen.dart';
import 'screen/mijn_gegevens_screen.dart';
import 'screen/oudere_meer_screen.dart';
import 'veiligheid/screen/bel_ons_screen.dart';
import 'widget/oudere_tabbalk.dart';

/// De routes van M4 (O2-O6 en O12). O1
/// zit op de rolroute /hulpvrager uit M2. Wordt in lib/app/router.dart met
/// een spread ingevoegd; de sessie-guard daar geldt ook hier.
List<RouteBase> hulpvragerRoutes() => [
  GoRoute(
    path: HhPadenHulpvrager.hulpVragenWat,
    builder: (context, state) => const HulpVragenWatScreen(),
  ),
  GoRoute(
    path: HhPadenHulpvrager.hulpVragenWanneer,
    builder: (context, state) => const HulpVragenWanneerScreen(),
  ),
  GoRoute(
    path: HhPadenHulpvrager.hulpVragenWaar,
    builder: (context, state) => const HulpVragenWaarScreen(),
  ),
  GoRoute(
    path: HhPadenHulpvrager.hulpVragenBevestigen,
    builder: (context, state) => const HulpVragenBevestigenScreen(),
  ),
  GoRoute(
    path: HhPadenHulpvrager.hulpVragenVerstuurd,
    builder: (context, state) => const HulpVragenVerstuurdScreen(),
  ),
  GoRoute(
    path: HhPadenHulpvrager.gegevens,
    builder: (context, state) => const MijnGegevensScreen(),
  ),
  GoRoute(
    path: HhPadenHulpvrager.belOnsTab,
    builder: (context, state) =>
        const OudereTabScherm(actief: OudereTab.belOns, child: BelOnsScreen()),
  ),
  GoRoute(
    path: HhPadenHulpvrager.meer,
    builder: (context, state) => const OudereMeerScreen(),
  ),
];

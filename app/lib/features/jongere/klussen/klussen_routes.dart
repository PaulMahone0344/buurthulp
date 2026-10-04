import 'package:go_router/go_router.dart';

import 'paden_klussen.dart';
import 'screen/jongere_tab_schermen.dart';
import 'screen/klus_detail_screen.dart';
import 'screen/klussen_home_screen.dart';
import 'screen/mijn_klussen_screen.dart';
import '../../../design/components/hh_tabbalk.dart';

/// Routes van klussen vinden en reageren (M5: J13, J14, de tabbladen
/// Klussen (J11/J12, B10), Mijn klussen en Profiel, en Instellingen). De
/// landing /jongere (B10: HelperStartScreen) zit in router.dart. Deze lijst
/// wordt in router.dart met een spread toegevoegd.
List<RouteBase> klussenRoutes() => [
  GoRoute(
    path: HhPadenKlussen.mijnKlussen,
    pageBuilder: (context, state) =>
        hhTabPagina(state, const MijnKlussenScreen()),
  ),
  GoRoute(
    path: HhPadenKlussen.profiel,
    pageBuilder: (context, state) =>
        hhTabPagina(state, const JongereProfielScreen()),
  ),
  // B10: Klussen (J11/J12) is een eigen tab; /jongere is de Start.
  GoRoute(
    path: HhPadenKlussen.lijst,
    pageBuilder: (context, state) =>
        hhTabPagina(state, const KlussenHomeScreen()),
  ),
  // B10: Instellingen is geen tab meer (knop op het Profiel).
  GoRoute(
    path: HhPadenKlussen.instellingen,
    builder: (context, state) => const JongereInstellingenScreen(),
  ),
  GoRoute(
    path: HhPadenKlussen.klusPatroon,
    builder: (context, state) =>
        KlusDetailScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

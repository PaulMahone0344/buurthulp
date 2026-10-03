import 'package:go_router/go_router.dart';

import 'paden_klussen.dart';
import 'screen/jongere_tab_schermen.dart';
import 'screen/klus_detail_screen.dart';
import 'screen/mijn_klussen_screen.dart';
import '../../../design/components/hh_tabbalk.dart';

/// Routes van klussen vinden en accepteren (M5: J13, J14, en de tabbladen
/// Profiel en Instellingen). J11/J12 zitten op de landing /jongere in
/// router.dart (JongereStubScreen bouwt KlussenHomeScreen). Deze lijst
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
  GoRoute(
    path: HhPadenKlussen.instellingen,
    pageBuilder: (context, state) =>
        hhTabPagina(state, const JongereInstellingenScreen()),
  ),
  GoRoute(
    path: HhPadenKlussen.klusPatroon,
    builder: (context, state) =>
        KlusDetailScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

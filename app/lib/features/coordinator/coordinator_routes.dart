import 'package:go_router/go_router.dart';

import 'paden_coordinator.dart';
import 'screen/coordinator_klus_detail_screen.dart';
import 'screen/coordinator_klussen_screen.dart';
import 'screen/coordinator_tab_schermen.dart';
import 'screen/incident_detail_screen.dart';
import '../../design/components/hh_tabbalk.dart';

/// Routes van de coordinator in de app (M10: C1-detail, C2, C2-detail en het
/// tabblad Instellingen). C1 zelf zit op de landing /coordinator in
/// router.dart (CoordinatorStubScreen bouwt CoordinatorIncidentenScreen).
/// Deze lijst wordt in router.dart met een spread toegevoegd.
List<RouteBase> coordinatorRoutes() => [
  GoRoute(
    path: HhPadenCoordinator.klussen,
    pageBuilder: (context, state) =>
        hhTabPagina(state, const CoordinatorKlussenScreen()),
  ),
  GoRoute(
    path: HhPadenCoordinator.instellingen,
    pageBuilder: (context, state) =>
        hhTabPagina(state, const CoordinatorInstellingenScreen()),
  ),
  GoRoute(
    path: HhPadenCoordinator.incidentPatroon,
    builder: (context, state) =>
        IncidentDetailScreen(incidentId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: HhPadenCoordinator.klusPatroon,
    builder: (context, state) =>
        CoordinatorKlusDetailScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];

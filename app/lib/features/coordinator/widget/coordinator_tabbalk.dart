import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_tabbalk.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../l10n/teksten_meldkamer_nl.dart';
import '../../meldingen/widget/meldingen_bel.dart';
import '../paden_coordinator.dart';
import '../provider/coordinator_providers.dart';
import '../provider/te_doen_providers.dart';

/// De tabbladen van de coordinator (M10, B11: Te doen). Het grote
/// beheerwerk zit in het webpaneel (M14); de app doet het snelle werk.
enum CoordinatorTab {
  incidenten,
  teDoen,
  klussen,
  instellingen;

  String get label => switch (this) {
    CoordinatorTab.incidenten => TekstenCoordinatorNl.tabIncidenten,
    CoordinatorTab.teDoen => TekstenMeldkamerNl.tabTeDoen,
    CoordinatorTab.klussen => TekstenCoordinatorNl.tabKlussen,
    CoordinatorTab.instellingen => TekstenCoordinatorNl.tabInstellingen,
  };

  IconData get icoon => switch (this) {
    CoordinatorTab.incidenten => Icons.notifications_active_outlined,
    CoordinatorTab.teDoen => Icons.checklist_outlined,
    CoordinatorTab.klussen => Icons.assignment_outlined,
    CoordinatorTab.instellingen => Icons.settings_outlined,
  };

  String get pad => switch (this) {
    CoordinatorTab.incidenten => HhPaden.coordinator,
    CoordinatorTab.teDoen => HhPadenCoordinator.teDoen,
    CoordinatorTab.klussen => HhPadenCoordinator.klussen,
    CoordinatorTab.instellingen => HhPadenCoordinator.instellingen,
  };
}

/// Onderste tabbalk van de coordinator: sinds B10 de gedeelde [HhTabbalk]
/// (amber streep, labels die bij 200 procent kleiner worden). Navigeert met
/// context.go zodat er geen stapel ontstaat.
///
/// Op Incidenten staat het enige getal van deze rol: hoeveel meldingen er
/// nog open staan.
class CoordinatorTabbalk extends ConsumerWidget {
  const CoordinatorTabbalk({required this.actief, super.key});

  final CoordinatorTab actief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openIncidentenTellerProvider);
    final teDoen = ref.watch(teDoenTellerProvider);
    String? semantiek(CoordinatorTab tab) => switch (tab) {
      CoordinatorTab.incidenten when open > 0 =>
        TekstenCoordinatorNl.tabIncidentenSemantiek(open),
      CoordinatorTab.teDoen when teDoen > 0 => TekstenMeldkamerNl.tabSemantiek(
        teDoen,
      ),
      _ => null,
    };
    String? teller(CoordinatorTab tab) => switch (tab) {
      CoordinatorTab.incidenten when open > 0 =>
        TekstenCoordinatorNl.tabIncidentenTeller(open),
      CoordinatorTab.teDoen when teDoen > 0 => TekstenMeldkamerNl.tabTeller(
        teDoen,
      ),
      _ => null,
    };
    return HhTabbalk(
      tabs: [
        for (final tab in CoordinatorTab.values)
          HhTab(
            label: tab.label,
            icoon: tab.icoon,
            pad: tab.pad,
            semantiekLabel: semantiek(tab),
            teller: teller(tab),
          ),
      ],
      actief: actief.index,
      semantiekLabel: TekstenCoordinatorNl.tabbalkLabel,
    );
  }
}

/// Een scherm van de coordinator met de tabbalk eronder. Het kind is een
/// gewoon scherm met eigen [Scaffold] (HhScherm); de buitenste Scaffold
/// haalt de onderste veilige rand uit het kind, de balk regelt hem zelf.
class CoordinatorTabScherm extends StatelessWidget {
  const CoordinatorTabScherm({
    required this.actief,
    required this.child,
    super.key,
  });

  final CoordinatorTab actief;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // M8: het belletje met de ongelezen-teller in de kop.
      body: HhTabScope(child: MeldingenKop(child: child)),
      bottomNavigationBar: CoordinatorTabbalk(actief: actief),
    );
  }
}

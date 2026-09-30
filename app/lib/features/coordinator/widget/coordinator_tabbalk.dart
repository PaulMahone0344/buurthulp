import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../meldingen/widget/meldingen_bel.dart';
import '../../../theme.dart';
import '../paden_coordinator.dart';
import '../provider/coordinator_providers.dart';

/// De drie tabbladen van de coordinator (M10). Verder niets: het
/// beheerwerk zit in het webpaneel (M14).
enum CoordinatorTab {
  incidenten,
  klussen,
  instellingen;

  String get label => switch (this) {
    CoordinatorTab.incidenten => TekstenCoordinatorNl.tabIncidenten,
    CoordinatorTab.klussen => TekstenCoordinatorNl.tabKlussen,
    CoordinatorTab.instellingen => TekstenCoordinatorNl.tabInstellingen,
  };

  IconData get icoon => switch (this) {
    CoordinatorTab.incidenten => Icons.notifications_active_outlined,
    CoordinatorTab.klussen => Icons.assignment_outlined,
    CoordinatorTab.instellingen => Icons.settings_outlined,
  };

  String get pad => switch (this) {
    CoordinatorTab.incidenten => HhPaden.coordinator,
    CoordinatorTab.klussen => HhPadenCoordinator.klussen,
    CoordinatorTab.instellingen => HhPadenCoordinator.instellingen,
  };
}

/// Onderste tabbalk van de coordinator. Zelfde opbouw als de tabbalk van de
/// jongere (M5): eigen widget in plaats van de Material NavigationBar, vaste
/// raakhoogte en kleuren uit theme.dart, labels die bij 200 procent
/// wikkelen. Navigeert met context.go zodat er geen stapel ontstaat.
///
/// Op Incidenten staat het enige getal van deze rol: hoeveel meldingen er
/// nog open staan.
class CoordinatorTabbalk extends ConsumerWidget {
  const CoordinatorTabbalk({required this.actief, super.key});

  final CoordinatorTab actief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final open = ref.watch(openIncidentenTellerProvider);

    return Semantics(
      container: true,
      label: TekstenCoordinatorNl.tabbalkLabel,
      child: Material(
        color: HhKleuren.achtergrond,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: HhKleuren.rand,
                width: HhLijn.dun(context),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tab in CoordinatorTab.values)
                    Expanded(
                      child: _TabKnop(
                        tab: tab,
                        isActief: tab == actief,
                        dichtheid: dichtheid,
                        openMeldingen: tab == CoordinatorTab.incidenten
                            ? open
                            : 0,
                        onTik: tab == actief ? null : () => context.go(tab.pad),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabKnop extends StatelessWidget {
  const _TabKnop({
    required this.tab,
    required this.isActief,
    required this.dichtheid,
    required this.openMeldingen,
    required this.onTik,
  });

  final CoordinatorTab tab;
  final bool isActief;
  final HhDichtheid dichtheid;
  final int openMeldingen;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final kleur = isActief ? HhKleuren.primair : HhKleuren.tekstGedempt;
    final toontTeller = openMeldingen > 0;

    return Semantics(
      button: true,
      selected: isActief,
      label: toontTeller
          ? TekstenCoordinatorNl.tabIncidentenSemantiek(openMeldingen)
          : tab.label,
      onTap: onTik,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTik,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: HhMaten.knopHoogte(dichtheid)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: HhRuimte.voor(HhRuimte.s, dichtheid),
              horizontal: HhRuimte.voor(HhRuimte.xs, dichtheid),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tab.icoon,
                  size: HhMaten.icoonKeuzerij(dichtheid),
                  color: kleur,
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: tekst.bodyMedium!.copyWith(
                    color: kleur,
                    fontWeight: isActief ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (toontTeller) ...[
                  SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                  _Teller(aantal: openMeldingen, dichtheid: dichtheid),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "3 open" onder het tabblad Incidenten. In de foutkleur, want een
/// openstaande melding wacht op iemand.
class _Teller extends StatelessWidget {
  const _Teller({required this.aantal, required this.dichtheid});

  final int aantal;
  final HhDichtheid dichtheid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: HhRuimte.voor(HhRuimte.s, dichtheid),
        vertical: HhRuimte.xs,
      ),
      decoration: BoxDecoration(
        color: HhKleuren.fout,
        borderRadius: BorderRadius.circular(HhRadius.rond),
      ),
      child: Text(
        TekstenCoordinatorNl.tabIncidentenTeller(aantal),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall!.copyWith(color: HhKleuren.opPrimair),
      ),
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
      body: MeldingenKop(child: child),
      bottomNavigationBar: CoordinatorTabbalk(actief: actief),
    );
  }
}

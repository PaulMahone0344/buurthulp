import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../domein/incident_lijst.dart';
import '../model/hh_incident.dart';
import '../paden_coordinator.dart';
import '../provider/coordinator_providers.dart';
import '../widget/coordinator_tabbalk.dart';
import '../widget/incident_tegel.dart';

/// C1. De meldingen die binnenkomen, nieuwste bovenaan. De lijst luistert
/// op de realtime-verbinding van hh_incidenten: een nieuwe melding staat er
/// binnen enkele seconden bij zonder dat de coordinator iets doet, en bij
/// een noodmelding trilt het toestel.
class CoordinatorIncidentenScreen extends ConsumerWidget {
  const CoordinatorIncidentenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CoordinatorTabScherm(
      actief: CoordinatorTab.incidenten,
      child: HhScherm(
        titel: TekstenCoordinatorNl.c1Titel,
        toonTerug: false,
        scrollbaar: false,
        child: _Lijst(),
      ),
    );
  }
}

/// Filterbalk en meldingen in één scrollvlak, zodat pull-to-refresh ook op
/// een lege lijst werkt en niets afkapt bij 200 procent tekst. Geen lazy
/// ListView: de lijst is in de pilot kort en zo bestaat elke tegel meteen,
/// ook voor de schermlezer die hem doorloopt.
class _Lijst extends ConsumerWidget {
  const _Lijst();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(gefilterdeIncidentenProvider);
    final filter = ref.watch(incidentFilterProvider);
    final nu = ref.watch(klokProvider)();
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    final inhoud = switch (stand) {
      AsyncData<List<HhIncident>>(:final value) when value.isEmpty => [
        HhLegeStaat(
          icoon: filter == IncidentFilter.open
              ? Icons.notifications_none_outlined
              : Icons.inbox_outlined,
          titel: filter == IncidentFilter.open
              ? TekstenCoordinatorNl.c1LegeOpenTitel
              : TekstenCoordinatorNl.c1LegeAfgehandeldTitel,
          uitleg: filter == IncidentFilter.open
              ? TekstenCoordinatorNl.c1LegeOpenUitleg
              : TekstenCoordinatorNl.c1LegeAfgehandeldUitleg,
        ),
      ],
      AsyncData<List<HhIncident>>(:final value) => [
        for (final incident in value) ...[
          IncidentTegel(
            incident: incident,
            nu: nu,
            onTik: () =>
                context.go(HhPadenCoordinator.incidentDetail(incident.id)),
          ),
          SizedBox(height: tussen),
        ],
      ],
      AsyncError<List<HhIncident>>(:final error) => [
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenCoordinatorNl.c1LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.read(incidentenProvider.notifier).vernieuw(),
        ),
      ],
      _ => const [HhLaadStaat.skelet(regels: 3)],
    };

    return RefreshIndicator(
      onRefresh: () => ref.read(incidentenProvider.notifier).vernieuw(),
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          rand,
          0,
          rand,
          HhRuimte.voor(HhRuimte.xl, dichtheid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FilterBalk(),
            SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
            ...inhoud,
          ],
        ),
      ),
    );
  }
}

class _FilterBalk extends ConsumerWidget {
  const _FilterBalk();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(incidentFilterProvider);

    return HhKeuzerij<IncidentFilter>(
      semantiekLabel: TekstenCoordinatorNl.c1FilterLabel,
      keuzes: const [
        HhKeuze(
          waarde: IncidentFilter.open,
          label: TekstenCoordinatorNl.c1FilterOpen,
          icoon: Icons.notifications_active_outlined,
        ),
        HhKeuze(
          waarde: IncidentFilter.afgehandeld,
          label: TekstenCoordinatorNl.c1FilterAfgehandeld,
          icoon: Icons.check_circle_outline,
        ),
      ],
      geselecteerd: {filter},
      onGewijzigd: (gekozen) {
        if (gekozen.isEmpty) return;
        ref.read(incidentFilterProvider.notifier).zet(gekozen.first);
      },
    );
  }
}

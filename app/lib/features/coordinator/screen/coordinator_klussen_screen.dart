import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/klussen/domein/wanneer_tekst.dart'
    show metHoofdletter, wanneerTekst;
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../domein/open_sinds.dart';
import '../model/hh_coordinator_klus.dart';
import '../paden_coordinator.dart';
import '../provider/coordinator_providers.dart';
import '../widget/coordinator_tabbalk.dart';

/// C2. De klussen die open staan, OUDSTE eerst: wat het langst blijft
/// liggen, staat bovenaan en vraagt als eerste om een jongere.
class CoordinatorKlussenScreen extends ConsumerWidget {
  const CoordinatorKlussenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CoordinatorTabScherm(
      actief: CoordinatorTab.klussen,
      child: HhScherm(
        titel: TekstenCoordinatorNl.c2Titel,
        toonTerug: false,
        scrollbaar: false,
        child: _Lijst(),
      ),
    );
  }
}

class _Lijst extends ConsumerWidget {
  const _Lijst();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(coordinatorKlussenProvider);
    final nu = ref.watch(klokProvider)();
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    final inhoud = switch (stand) {
      AsyncData<List<HhCoordinatorKlus>>(:final value) when value.isEmpty =>
        const [
          HhLegeStaat(
            icoon: Icons.assignment_turned_in_outlined,
            titel: TekstenCoordinatorNl.c2LegeTitel,
            uitleg: TekstenCoordinatorNl.c2LegeUitleg,
          ),
        ],
      AsyncData<List<HhCoordinatorKlus>>(:final value) => [
        for (final klus in value) ...[
          _KlusRij(klus: klus, nu: nu),
          SizedBox(height: tussen),
        ],
      ],
      AsyncError<List<HhCoordinatorKlus>>(:final error) => [
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenCoordinatorNl.c2LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () =>
              ref.read(coordinatorKlussenProvider.notifier).vernieuw(),
        ),
      ],
      _ => const [HhLaadStaat.skelet(regels: 3)],
    };

    // Alles in één scrollvlak (zoals J11): pull-to-refresh werkt ook op een
    // lege lijst en niets kapt af bij 200 procent tekst.
    return RefreshIndicator(
      onRefresh: () => ref.read(coordinatorKlussenProvider.notifier).vernieuw(),
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
          children: inhoud,
        ),
      ),
    );
  }
}

class _KlusRij extends StatelessWidget {
  const _KlusRij({required this.klus, required this.nu});

  final HhCoordinatorKlus klus;
  final DateTime nu;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.xs, dichtheid);
    final soort = metHoofdletter(klus.klustypeNaam);
    final openSinds = TekstenCoordinatorNl.c2OpenSinds(
      openSindsTekst(klus.aangemaaktOp, nu),
    );

    return HhKaart(
      semantiekLabel: '$soort, ${klus.oudereNaam}, $openSinds',
      actie: TextButton(
        onPressed: () =>
            context.go(HhPadenCoordinator.klusDetail(klus.id)),
        child: const Text(TekstenCoordinatorNl.c2Koppelen),
      ),
      kop: soort,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(klus.oudereNaam, style: tekst.bodyLarge),
          SizedBox(height: klein),
          Text(
            klus.oudereWijkNaam.isEmpty
                ? TekstenCoordinatorNl.c2GeenWijk
                : klus.oudereWijkNaam,
            style: tekst.bodyMedium,
          ),
          SizedBox(height: klein),
          Text(wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu),
              style: tekst.bodyMedium),
          SizedBox(height: klein),
          Text(openSinds, style: tekst.labelSmall),
        ],
      ),
    );
  }
}

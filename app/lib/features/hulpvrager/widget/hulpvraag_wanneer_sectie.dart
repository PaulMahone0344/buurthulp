import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';
import '../domein/wanneer.dart';
import '../model/hulpvraag_concept.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// Deel "Wanneer" van de hulpvraag-pagina (was O3). Eerst de dag (vandaag,
/// morgen, kies een dag), dan het dagdeel. "Kies een dag" opent een eigen
/// grote dagkiezer met de komende twee weken; geen Material-datumkiezer,
/// die is Engels en heeft kleine raakvlakken.
class HulpvraagWanneerSectie extends ConsumerWidget {
  const HulpvraagWanneerSectie({super.key});

  /// Hoever vooruit de dagkiezer reikt (vandaag meegerekend).
  static const dagenVooruit = 14;

  static const _dagKeuzes = [
    HhKeuze(
      waarde: HhDagKeuze.vandaag,
      label: TekstenHulpvragerNl.dagVandaag,
      semantiekLabel: TekstenHulpvragerNl.dagVandaagSemantiek,
      icoon: Icons.today_outlined,
    ),
    HhKeuze(
      waarde: HhDagKeuze.morgen,
      label: TekstenHulpvragerNl.dagMorgen,
      semantiekLabel: TekstenHulpvragerNl.dagMorgenSemantiek,
      icoon: Icons.event_outlined,
    ),
    HhKeuze(
      waarde: HhDagKeuze.andereDag,
      label: TekstenHulpvragerNl.dagAndere,
      semantiekLabel: TekstenHulpvragerNl.dagAndereSemantiek,
      icoon: Icons.calendar_month_outlined,
    ),
  ];

  static const _dagdeelKeuzes = [
    HhKeuze(
      waarde: HhDagdeel.ochtend,
      label: TekstenHulpvragerNl.dagdeelOchtend,
      semantiekLabel: TekstenHulpvragerNl.dagdeelOchtendSemantiek,
      icoon: Icons.wb_sunny_outlined,
    ),
    HhKeuze(
      waarde: HhDagdeel.middag,
      label: TekstenHulpvragerNl.dagdeelMiddag,
      semantiekLabel: TekstenHulpvragerNl.dagdeelMiddagSemantiek,
      icoon: Icons.wb_cloudy_outlined,
    ),
    HhKeuze(
      waarde: HhDagdeel.avond,
      label: TekstenHulpvragerNl.dagdeelAvond,
      semantiekLabel: TekstenHulpvragerNl.dagdeelAvondSemantiek,
      icoon: Icons.nights_stay_outlined,
    ),
  ];

  Future<void> _kiesDagKeuze(
    BuildContext context,
    WidgetRef ref,
    HhDagKeuze keuze,
  ) async {
    final controller = ref.read(conceptProvider.notifier);
    if (keuze != HhDagKeuze.andereDag) {
      controller.kiesDagKeuze(keuze);
      return;
    }
    final nu = ref.read(klokProvider)();
    final dag = await showDialog<DateTime>(
      context: context,
      builder: (context) => _DagKiezer(dagen: komendeDagen(nu, dagenVooruit)),
    );
    if (dag == null) return;
    controller.kiesDag(dag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concept = ref.watch(conceptProvider);
    final nu = ref.watch(klokProvider)();
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final dag = concept.dag;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HhKeuzerij<HhDagKeuze>(
          semantiekLabel: TekstenHulpvragerNl.wanneerDagKeuzerij,
          keuzes: _dagKeuzes,
          geselecteerd: {?concept.dagKeuze},
          onGewijzigd: (keuze) => _kiesDagKeuze(context, ref, keuze.first),
        ),
        if (dag != null) ...[
          SizedBox(height: klein),
          Text(
            TekstenHulpvragerNl.dagGekozen(dagTekst(dag, nu)),
            style: tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: tussen),
          Text(TekstenHulpvragerNl.wanneerDagdeel, style: tekst.titleLarge),
          SizedBox(height: klein),
          HhKeuzerij<HhDagdeel>(
            semantiekLabel: TekstenHulpvragerNl.wanneerDagdeelKeuzerij,
            keuzes: _dagdeelKeuzes,
            geselecteerd: {?concept.dagdeel},
            onGewijzigd: (keuze) =>
                ref.read(conceptProvider.notifier).kiesDagdeel(keuze.first),
          ),
          SizedBox(height: klein),
          Text(TekstenHulpvragerNl.dagdeelUitleg, style: tekst.bodyMedium),
        ],
      ],
    );
  }
}

/// De eigen dagkiezer: een lijst van grote knoppen, een per dag, in
/// gewone taal ("donderdag 17 september"). Sluit met de terugknop.
class _DagKiezer extends StatelessWidget {
  const _DagKiezer({required this.dagen});

  final List<DateTime> dagen;

  @override
  Widget build(BuildContext context) {
    final klein = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));

    return Dialog.fullscreen(
      child: HhScherm(
        titel: TekstenHulpvragerNl.dagKiezerTitel,
        onTerug: () => Navigator.of(context).pop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < dagen.length; i++) ...[
              if (i > 0) SizedBox(height: klein),
              HhKnop(
                label: datumTekst(dagen[i]),
                semantiekLabel: TekstenHulpvragerNl.dagKiezerSemantiek(
                  datumTekst(dagen[i]),
                ),
                soort: HhKnopSoort.tweedeKeus,
                onPressed: () => Navigator.of(context).pop(dagen[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

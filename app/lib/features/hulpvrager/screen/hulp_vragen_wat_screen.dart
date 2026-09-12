import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/hh_fout.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/components/hh_stapbalk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../domein/klustype_icoon.dart';
import '../model/hh_klustype.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';
import 'stroom_verlaten_dialoog.dart';

/// O2, stap 1 van 4: wat heeft u nodig. De soorten hulp uit hh_klustypes
/// als grote iconen, drie per rij. Meer dan zes: eerst zes en een knop
/// "Meer". De terugknop verlaat de stroom en vraagt dan "Weet u het
/// zeker?" zodra er al iets gekozen is.
class HulpVragenWatScreen extends ConsumerStatefulWidget {
  const HulpVragenWatScreen({super.key});

  /// Hoeveel soorten hulp er eerst zichtbaar zijn.
  static const eersteZichtbaar = 6;

  /// Keuzes naast elkaar (ouderenregel: maximaal drie per rij).
  static const perRij = 3;

  @override
  ConsumerState<HulpVragenWatScreen> createState() =>
      _HulpVragenWatScreenState();
}

class _HulpVragenWatScreenState extends ConsumerState<HulpVragenWatScreen> {
  bool _toonAlles = false;

  Future<void> _verlaten() async {
    final concept = ref.read(conceptProvider);
    if (!concept.isLeeg && !await vraagStroomVerlaten(context)) return;
    ref.read(conceptProvider.notifier).wis();
    if (!mounted) return;
    terugOf(context, HhPaden.hulpvrager);
  }

  @override
  Widget build(BuildContext context) {
    final concept = ref.watch(conceptProvider);
    final klustypes = ref.watch(klustypesProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (heeftGepopt, _) {
        if (!heeftGepopt) _verlaten();
      },
      child: HhScherm(
        titel: TekstenHulpvragerNl.watTitel,
        onTerug: _verlaten,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HhStapbalk(
              stap: 1,
              totaal: TekstenHulpvragerNl.stappenTotaal,
              titel: TekstenHulpvragerNl.stapWat,
            ),
            SizedBox(height: tussen),
            Text(TekstenHulpvragerNl.watUitleg, style: tekst.bodyLarge),
            SizedBox(height: tussen),
            switch (klustypes) {
              AsyncData(:final value) when value.isEmpty => const HhLegeStaat(
                icoon: Icons.volunteer_activism_outlined,
                titel: TekstenHulpvragerNl.watTitel,
                uitleg: TekstenHulpvragerNl.watGeenKlustypes,
              ),
              AsyncData(:final value) => _Keuzes(
                klustypes: value,
                gekozen: concept.klustype,
                toonAlles: _toonAlles,
                onKies: ref.read(conceptProvider.notifier).kiesKlustype,
                onMeer: () => setState(() => _toonAlles = !_toonAlles),
              ),
              AsyncError(:final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HhMeldBalk(
                    soort: HhMeldSoort.fout,
                    tekst: error is HhFout
                        ? error.melding
                        : TekstenNl.foutOnbekend,
                  ),
                  SizedBox(height: tussen),
                  HhKnop(
                    label: TekstenNl.opnieuwProberen,
                    soort: HhKnopSoort.tweedeKeus,
                    onPressed: () => ref.invalidate(klustypesProvider),
                  ),
                ],
              ),
              _ => const HhLaadStaat.skelet(
                regels: 2,
                label: TekstenHulpvragerNl.watLaden,
              ),
            },
            SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
            HhKnop(
              label: TekstenNl.verder,
              icoon: Icons.arrow_forward,
              onPressed: concept.heeftWat
                  ? () => context.push(HhPadenHulpvrager.hulpVragenWanneer)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Keuzes extends StatelessWidget {
  const _Keuzes({
    required this.klustypes,
    required this.gekozen,
    required this.toonAlles,
    required this.onKies,
    required this.onMeer,
  });

  final List<HhKlustype> klustypes;
  final HhKlustype? gekozen;
  final bool toonAlles;
  final ValueChanged<HhKlustype> onKies;
  final VoidCallback onMeer;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);
    final heeftMeer = klustypes.length > HulpVragenWatScreen.eersteZichtbaar;
    final zichtbaar = heeftMeer && !toonAlles
        ? klustypes.take(HulpVragenWatScreen.eersteZichtbaar).toList()
        : klustypes;

    // Rijen van drie, elk een HhKeuzerij die dezelfde keuze deelt.
    final rijen = <List<HhKlustype>>[
      for (var i = 0; i < zichtbaar.length; i += HulpVragenWatScreen.perRij)
        zichtbaar.sublist(
          i,
          (i + HulpVragenWatScreen.perRij).clamp(0, zichtbaar.length),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rijen.length; r++) ...[
          if (r > 0) SizedBox(height: tussen),
          HhKeuzerij<String>(
            semantiekLabel: r == 0 ? TekstenHulpvragerNl.watKeuzerij : null,
            keuzes: [
              for (final type in rijen[r])
                HhKeuze(
                  waarde: type.id,
                  label: type.naam,
                  semantiekLabel: TekstenHulpvragerNl.watKiesSemantiek(
                    type.naam,
                  ),
                  icoon: KlustypeIcoon.voor(type.icoon),
                ),
            ],
            geselecteerd: {if (gekozen != null) gekozen!.id},
            onGewijzigd: (keuze) =>
                onKies(klustypes.firstWhere((t) => t.id == keuze.first)),
          ),
        ],
        if (heeftMeer) ...[
          SizedBox(height: tussen),
          HhKnop(
            label: toonAlles
                ? TekstenHulpvragerNl.watMinder
                : TekstenHulpvragerNl.watMeer,
            semantiekLabel: toonAlles
                ? TekstenHulpvragerNl.watMinderSemantiek
                : TekstenHulpvragerNl.watMeerSemantiek,
            icoon: toonAlles ? Icons.expand_less : Icons.expand_more,
            soort: HhKnopSoort.tekst,
            onPressed: onMeer,
          ),
        ],
      ],
    );
  }
}

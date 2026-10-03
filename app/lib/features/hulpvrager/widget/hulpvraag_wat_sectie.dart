import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../domein/klustype_icoon.dart';
import '../model/hh_klustype.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// Deel "Wat moet er gebeuren?" van "Klus plaatsen" (B4). De categorieën
/// uit hh_klustypes (alleen actief, op volgorde) als tegels met icoon, drie
/// per rij, alle dertien in één keer zichtbaar (mockup KlusPlaatsen).
class HulpvraagWatSectie extends ConsumerWidget {
  const HulpvraagWatSectie({super.key});

  /// Keuzes naast elkaar (ouderenregel: maximaal drie per rij).
  static const perRij = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gekozen = ref.watch(conceptProvider.select((c) => c.klustype));
    final klustypes = ref.watch(klustypesProvider);
    final tussen = HhRuimte.voor(HhRuimte.l, HhDichtheidScope.van(context));

    return switch (klustypes) {
      AsyncData(:final value) when value.isEmpty => const HhLegeStaat(
        icoon: Icons.handyman_outlined,
        titel: TekstenKlusNl.watTitel,
        uitleg: TekstenHulpvragerNl.watGeenKlustypes,
      ),
      AsyncData(:final value) => _Keuzes(
        klustypes: value,
        gekozen: gekozen,
        onKies: ref.read(conceptProvider.notifier).kiesKlustype,
      ),
      AsyncError(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HhMeldBalk(
            soort: HhMeldSoort.fout,
            tekst: error is HhFout ? error.melding : TekstenNl.foutOnbekend,
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
    };
  }
}

class _Keuzes extends StatelessWidget {
  const _Keuzes({
    required this.klustypes,
    required this.gekozen,
    required this.onKies,
  });

  final List<HhKlustype> klustypes;
  final HhKlustype? gekozen;
  final ValueChanged<HhKlustype> onKies;

  @override
  Widget build(BuildContext context) {
    final tussen = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));
    const perRij = HulpvraagWatSectie.perRij;

    // Rijen van drie, elk een HhKeuzerij die dezelfde keuze deelt.
    final rijen = <List<HhKlustype>>[
      for (var i = 0; i < klustypes.length; i += perRij)
        klustypes.sublist(i, (i + perRij).clamp(0, klustypes.length)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rijen.length; r++) ...[
          if (r > 0) SizedBox(height: tussen),
          _Rij(
            aantal: rijen[r].length,
            child: HhKeuzerij<String>(
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
              geselecteerd: {?gekozen?.id},
              onGewijzigd: (keuze) =>
                  onKies(klustypes.firstWhere((t) => t.id == keuze.first)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Een onvolledige laatste rij (13 = 4 x 3 + 1) blijft in het raster van
/// drie: de tegel wordt niet ineens drie keer zo breed.
class _Rij extends StatelessWidget {
  const _Rij({required this.aantal, required this.child});

  final int aantal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const perRij = HulpvraagWatSectie.perRij;
    if (aantal >= perRij) return child;
    return Row(
      children: [
        Expanded(flex: aantal, child: child),
        Spacer(flex: perRij - aantal),
      ],
    );
  }
}

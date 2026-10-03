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
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../domein/klustype_icoon.dart';
import '../model/hh_klustype.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// Deel "Wat heeft u nodig?" van de hulpvraag-pagina (was O2). De soorten
/// hulp uit hh_klustypes als grote iconen, drie per rij. Meer dan zes:
/// eerst zes en een knop "Meer".
class HulpvraagWatSectie extends ConsumerStatefulWidget {
  const HulpvraagWatSectie({super.key});

  /// Hoeveel soorten hulp er eerst zichtbaar zijn.
  static const eersteZichtbaar = 6;

  /// Keuzes naast elkaar (ouderenregel: maximaal drie per rij).
  static const perRij = 3;

  @override
  ConsumerState<HulpvraagWatSectie> createState() => _HulpvraagWatSectieState();
}

class _HulpvraagWatSectieState extends ConsumerState<HulpvraagWatSectie> {
  bool _toonAlles = false;

  @override
  Widget build(BuildContext context) {
    final gekozen = ref.watch(conceptProvider.select((c) => c.klustype));
    final klustypes = ref.watch(klustypesProvider);
    final tussen = HhRuimte.voor(HhRuimte.l, HhDichtheidScope.van(context));

    return switch (klustypes) {
      AsyncData(:final value) when value.isEmpty => const HhLegeStaat(
        icoon: Icons.volunteer_activism_outlined,
        titel: TekstenHulpvragerNl.watTitel,
        uitleg: TekstenHulpvragerNl.watGeenKlustypes,
      ),
      AsyncData(:final value) => _Keuzes(
        klustypes: value,
        gekozen: gekozen,
        toonAlles: _toonAlles,
        onKies: ref.read(conceptProvider.notifier).kiesKlustype,
        onMeer: () => setState(() => _toonAlles = !_toonAlles),
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
    final tussen = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));
    final heeftMeer = klustypes.length > HulpvraagWatSectie.eersteZichtbaar;
    final zichtbaar = heeftMeer && !toonAlles
        ? klustypes.take(HulpvraagWatSectie.eersteZichtbaar).toList()
        : klustypes;

    // Rijen van drie, elk een HhKeuzerij die dezelfde keuze deelt.
    final rijen = <List<HhKlustype>>[
      for (var i = 0; i < zichtbaar.length; i += HulpvraagWatSectie.perRij)
        zichtbaar.sublist(
          i,
          (i + HulpvraagWatSectie.perRij).clamp(0, zichtbaar.length),
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
            geselecteerd: {?gekozen?.id},
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../hulpvrager/status/provider/status_providers.dart';
import '../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../jongere/klussen/model/hh_klus.dart';
import '../../meldingen/model/hh_melding.dart';
import '../../meldingen/provider/meldingen_providers.dart';
import '../paden_reacties.dart';
import 'initialen_avatar.dart';

/// Start van de bewoner (mockup Main): "3 strijders willen je helpen" per open
/// klus waarop helpers reageerden (reacties_aantal van de server). Een
/// nieuwe reactie-melding (realtime) laadt de klussen opnieuw.
class HelpersWillenKaart extends ConsumerWidget {
  const HelpersWillenKaart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Komt er een reactie-melding binnen, dan kloppen de aantallen niet meer.
    ref.listen(meldingenProvider, (vorige, nieuwe) {
      int tel(AsyncValue<List<HhMelding>>? s) => (s?.value ?? const [])
          .where((m) => m.soort == HhMeldingSoort.reactie)
          .length;
      if (tel(nieuwe) != tel(vorige) && vorige?.hasValue == true) {
        ref.invalidate(mijnHulpvragenProvider);
      }
    });
    final klussen = [
      for (final k
          in ref.watch(mijnHulpvragenProvider).value ?? const <HhKlus>[])
        if (k.isOpen && k.reactiesAantal > 0) k,
    ];
    if (klussen.isEmpty) return const SizedBox.shrink();
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final nu = ref.watch(klokProvider)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final klus in klussen) ...[
          HhKaart(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const InitialenAvatar(voornaam: '+'),
                    SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TekstenReactiesNl.helpersWillen(
                              klus.reactiesAantal,
                            ),
                            style: tekst.titleMedium,
                          ),
                          Text(
                            TekstenReactiesNl.helpersWillenBij(
                              '${metHoofdletter(klus.klustypeNaam)}, '
                              '${wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu)}',
                            ),
                            style: tekst.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
                HhKnop(
                  label: TekstenReactiesNl.bekijkReacties,
                  icoon: Icons.arrow_forward_rounded,
                  onPressed: () => context.push(HhPadenReacties.kies(klus.id)),
                ),
              ],
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
        ],
      ],
    );
  }
}

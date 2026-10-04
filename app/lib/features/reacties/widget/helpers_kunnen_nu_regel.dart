import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_meld_balk.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../provider/reactie_providers.dart';

/// Bij het plaatsen (punt 12): "4 strijders kunnen nu helpen". Alleen een
/// aantal (de server stuurt geen namen); niets als het 0 of onbekend is.
class HelpersKunnenNuRegel extends ConsumerWidget {
  const HelpersKunnenNuRegel({
    required this.klustypeId,
    this.van,
    this.tot,
    super.key,
  });

  final String klustypeId;
  final DateTime? van;
  final DateTime? tot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aantal = ref
        .watch(
          aantalBeschikbaarProvider(
            BeschikbaarVraag(klustypeId: klustypeId, van: van, tot: tot),
          ),
        )
        .value;
    if (aantal == null || aantal <= 0) return const SizedBox.shrink();
    return HhMeldBalk(
      soort: HhMeldSoort.informatie,
      tekst: TekstenReactiesNl.helpersKunnenNu(aantal),
    );
  }
}

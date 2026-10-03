import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigatie.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../toegang/widget/aanmeld_stappen.dart';
import '../model/screening_stap.dart';
import '../paden_jongere.dart';

/// Steiger van elke stap (ID-foto, VOG, over mij): titel, de stappen
/// "Jij - Ouder - Klaar" (we zitten bij "Jij"), uitleg, de inhoud, een
/// meldbalk en de knop. Terug gaat altijd naar het overzicht (J9).
class ScreeningStapScherm extends ConsumerWidget {
  const ScreeningStapScherm({
    required this.stap,
    required this.gegevens,
    required this.uitleg,
    required this.child,
    required this.onVerder,
    this.isBezig = false,
    this.melding,
    this.meldSoort = HhMeldSoort.fout,
    this.knopLabel,
    super.key,
  });

  final ScreeningStap stap;
  final ScreeningGegevens gegevens;
  final String uitleg;
  final Widget child;
  final VoidCallback? onVerder;
  final bool isBezig;
  final String? melding;
  final HhMeldSoort meldSoort;
  final String? knopLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return HhScherm(
      titel: stap.titel,
      onTerug: () => terugOf(context, HhPadenJongere.overzicht),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AanmeldStappen(
            huidig: AanmeldStap.jij,
            metOuder:
                gegevens.isMinderjarigOp(ref.watch(klokProvider)()) ?? false,
          ),
          SizedBox(height: tussen),
          Text(uitleg, style: tekst.bodyMedium),
          SizedBox(height: tussen),
          child,
          if (melding != null) ...[
            SizedBox(height: tussen),
            HhMeldBalk(soort: meldSoort, tekst: melding!),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: knopLabel ?? TekstenJongereNl.opslaanEnVerder,
            isBezig: isBezig,
            onPressed: onVerder,
          ),
        ],
      ),
    );
  }
}

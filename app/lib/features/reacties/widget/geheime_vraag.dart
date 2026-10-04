import 'package:flutter/material.dart';

import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';

/// De geheime vraag na de klus (punt 11): bewoner "Was alles in orde?",
/// helper "Voelde je je veilig?". Alleen de meldkamer ziet het antwoord (de
/// server verbergt het voor de ander). Bij "Nee" een vrij tekstvak en maakt
/// de server een melding voor de meldkamer.
class GeheimeVraag extends StatelessWidget {
  const GeheimeVraag({
    required this.vraag,
    required this.antwoord,
    required this.onAntwoord,
    required this.toelichting,
    this.isActief = true,
    this.fout,
    super.key,
  });

  final String vraag;

  /// true = ja, false = nee, null = nog niet gekozen.
  final bool? antwoord;
  final ValueChanged<bool> onAntwoord;
  final TextEditingController toelichting;
  final bool isActief;
  final String? fout;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final gekozen = antwoord;
    return HhKaart(
      kop: vraag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TekstenReactiesNl.geheimUitleg, style: tekst.bodyMedium),
          SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
          HhKeuzerij<bool>(
            semantiekLabel: vraag,
            keuzes: const [
              HhKeuze(
                waarde: true,
                label: TekstenReactiesNl.ja,
                icoon: Icons.check_rounded,
              ),
              HhKeuze(
                waarde: false,
                label: TekstenReactiesNl.nee,
                icoon: Icons.close_rounded,
              ),
            ],
            geselecteerd: {?gekozen},
            onGewijzigd: isActief ? (k) => onAntwoord(k.first) : null,
          ),
          if (fout != null) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Text(
              fout!,
              style: tekst.bodyMedium!.copyWith(color: HhKleuren.fout),
            ),
          ],
          if (gekozen == false) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
            HhInvoer(
              label: TekstenReactiesNl.geheimToelichtingLabel,
              controller: toelichting,
              isActief: isActief,
              maxRegels: 3,
            ),
          ],
        ],
      ),
    );
  }
}

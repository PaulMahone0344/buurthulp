import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../theme.dart';
import '../domein/bedragen.dart';

/// "Jij betaalt € 0,00 (voorbeeld), inclusief servicekosten". Een
/// voorbeeld: de echte prijzen komen in B7.
class KlusPrijsBlok extends StatelessWidget {
  const KlusPrijsBlok({super.key});

  static const voorbeeldCenten = 0;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final bedrag = euroTekst(voorbeeldCenten);

    return Semantics(
      label: TekstenKlusNl.prijsSemantiek(bedrag),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HhKleuren.oppervlak,
          borderRadius: BorderRadius.circular(HhRadius.groot),
        ),
        child: Padding(
          padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.l, dichtheid)),
          // Wrap: bij grote tekst schuift het bedrag onder de uitleg.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: HhRuimte.voor(HhRuimte.m, dichtheid),
            runSpacing: HhRuimte.voor(HhRuimte.s, dichtheid),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    TekstenKlusNl.prijsJijBetaalt,
                    style: tekst.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(TekstenKlusNl.prijsInclusief, style: tekst.bodyMedium),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(bedrag, style: tekst.headlineMedium),
                  Text(TekstenKlusNl.prijsVoorbeeld, style: tekst.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

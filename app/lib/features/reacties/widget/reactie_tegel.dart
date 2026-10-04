import 'package:flutter/material.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../domein/reactie_regels.dart';
import '../model/hh_reactie.dart';

/// HMijnKlussen, tab Gereageerd: één reactie van de helper. De klus komt uit
/// klus_samenvatting (de server zet die), zodat ook een reactie op een klus
/// die al vergeven is nog te lezen is. Tik opent de klus zolang de reactie
/// loopt.
class ReactieTegel extends StatelessWidget {
  const ReactieTegel({required this.reactie, this.onTik, super.key});

  final HhReactie reactie;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final loopt = reactieLooptNog(reactie);
    final stand = reactieStand(reactie);
    final titel = reactie.klusSamenvatting.isEmpty
        ? TekstenReactiesNl.onbekendeKlus
        : reactie.klusSamenvatting;

    final inhoud = HhKaart(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titel, style: tekst.titleMedium),
                if (reactie.bericht.isNotEmpty) ...[
                  SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                  Text(
                    '“${reactie.bericht}”',
                    style: tekst.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: HhRuimte.voor(HhRuimte.xs, dichtheid),
                    horizontal: HhRuimte.voor(HhRuimte.m, dichtheid),
                  ),
                  decoration: BoxDecoration(
                    color: loopt ? HhKleuren.accentZacht : HhKleuren.oppervlak,
                    borderRadius: BorderRadius.circular(HhRadius.rond),
                    border: Border.all(
                      color: loopt ? HhKleuren.accent : HhKleuren.rand,
                      width: HhLijn.dun(context),
                    ),
                  ),
                  child: Text(
                    stand,
                    style: tekst.bodyMedium!.copyWith(
                      color: loopt
                          ? HhKleuren.waarschuwing
                          : HhKleuren.tekstGedempt,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onTik != null)
            const ExcludeSemantics(child: Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );

    return Semantics(
      button: onTik != null,
      label: '$titel. $stand',
      excludeSemantics: true,
      child: onTik == null
          ? inhoud
          : InkWell(
              onTap: onTik,
              borderRadius: BorderRadius.circular(HhRadius.groot),
              child: inhoud,
            ),
    );
  }
}

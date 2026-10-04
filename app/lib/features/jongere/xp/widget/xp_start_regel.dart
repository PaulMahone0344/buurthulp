import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../design/lijn.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../../klussen/paden_klussen.dart';
import '../provider/xp_providers.dart';
import 'niveau_pil.dart';

/// Het kleine XP-blok op Start (helper): niveau, XP en een tik naar het
/// Profiel. Laden of een fout: niets (Start blijft rustig). De echte
/// Start-indeling volgt in B10.
class XpStartRegel extends ConsumerWidget {
  const XpStartRegel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overzicht = ref.watch(xpOverzichtProvider).value;
    if (overzicht == null) return const SizedBox.shrink();
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final volgend = overzicht.volgend;
    return Padding(
      padding: EdgeInsets.only(bottom: HhRuimte.voor(HhRuimte.m, dichtheid)),
      child: Semantics(
        button: true,
        label:
            '${TekstenXpNl.startRegel(overzicht.niveau.naam, overzicht.xpTotaal)}. ${TekstenXpNl.startNaarProfiel}',
        excludeSemantics: true,
        child: Material(
          color: HhKleuren.oppervlakZacht,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HhRadius.groot),
            side: BorderSide(
              color: HhKleuren.randZacht,
              width: HhLijn.dun(context),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(HhRadius.groot),
            onTap: () => context.go(HhPadenKlussen.profiel),
            child: Padding(
              padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.m, dichtheid)),
              child: Row(
                children: [
                  NiveauPil(tekst: overzicht.niveau.naam),
                  SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TekstenXpNl.xpTotaal(overzicht.xpTotaal),
                          style: tekst.titleMedium,
                        ),
                        if (volgend != null)
                          Padding(
                            padding: EdgeInsets.only(
                              top: HhRuimte.voor(HhRuimte.xs, dichtheid),
                            ),
                            child: LinearProgressIndicator(
                              value: volgend.voortgang(overzicht.xpTotaal),
                              minHeight: HhRuimte.xs,
                              backgroundColor: HhKleuren.oppervlak,
                              color: HhKleuren.accentDonker,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: HhKleuren.tekstGedempt,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

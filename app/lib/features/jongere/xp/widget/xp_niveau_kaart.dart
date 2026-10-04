import 'package:flutter/material.dart';

import '../../../../design/components/hh_kaart.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../../reputatie/domein/sterren.dart';
import '../model/hh_xp.dart';
import 'niveau_pil.dart';

/// Niveau-pil, XP-totaal en de balk naar het volgende niveau, met wat er nog
/// nodig is. Alle getallen komen van de server (GET /api/hh/xp/mijn).
class XpNiveauKaart extends StatelessWidget {
  const XpNiveauKaart({required this.overzicht, super.key});

  final HhXpOverzicht overzicht;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final volgend = overzicht.volgend;

    return HhKaart(
      kop: TekstenXpNl.niveauKop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: klein,
            runSpacing: klein,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              NiveauPil(tekst: overzicht.niveau.naam),
              Text(
                TekstenXpNl.xpTotaal(overzicht.xpTotaal),
                style: tekst.titleLarge,
              ),
            ],
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
          if (volgend == null)
            Text(TekstenXpNl.hoogsteNiveau, style: tekst.bodyLarge)
          else ...[
            Semantics(
              container: true,
              label: TekstenXpNl.balkSemantiek(
                overzicht.xpTotaal,
                volgend.xpTot,
                volgend.niveau.naam,
              ),
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HhRadius.rond),
                  child: LinearProgressIndicator(
                    value: volgend.voortgang(overzicht.xpTotaal),
                    minHeight: HhRuimte.voor(HhRuimte.s, dichtheid),
                    backgroundColor: HhKleuren.oppervlak,
                    color: HhKleuren.accentDonker,
                  ),
                ),
              ),
            ),
            SizedBox(height: klein),
            Text(_nogNodig(volgend), style: tekst.bodyLarge),
          ],
          SizedBox(height: klein),
          Text(TekstenXpNl.hoeWerktHet, style: tekst.bodyMedium),
        ],
      ),
    );
  }

  static String _nogNodig(HhVolgendNiveau v) {
    final delen = [TekstenXpNl.nogTot(v.xpNodig, v.niveau.naam)];
    if (v.klussenNodig > 0) delen.add(TekstenXpNl.nogKlussen(v.klussenNodig));
    if (v.sterrenNodig > 0) {
      delen.add(TekstenXpNl.nogSterren(sterrenTekst(v.sterrenNodig)));
    }
    return '${delen.join(' ')}.';
  }
}

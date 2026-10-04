import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_start_nl.dart';
import '../../../l10n/teksten_xp_nl.dart';
import '../../../theme.dart';
import '../klussen/paden_klussen.dart';
import '../xp/domein/xp_tekst.dart';
import '../xp/model/hh_xp.dart';
import '../xp/widget/niveau_pil.dart';

/// Start helper (B10, mockup StartHelper): "Jouw niveau" met pil, het
/// volgende niveau, de XP-balk en een rij behaalde badges. Tik = Profiel.
/// Alles van de server (GET /api/hh/xp/mijn).
class HelperNiveauKaart extends StatelessWidget {
  const HelperNiveauKaart({required this.overzicht, super.key});

  final HhXpOverzicht overzicht;

  static const _maxBadges = 5;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final volgend = overzicht.volgend;
    final behaald = overzicht.badges.where((b) => b.isBehaald).take(_maxBadges);

    return HhKaart(
      kop: TekstenStartNl.niveauKop,
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
                volgend == null
                    ? TekstenStartNl.hoogste
                    : TekstenStartNl.volgende(volgend.niveau.naam),
                style: tekst.bodyLarge,
              ),
            ],
          ),
          SizedBox(height: klein),
          if (volgend != null) ...[
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
                    minHeight: klein,
                    backgroundColor: HhKleuren.oppervlak,
                    color: HhKleuren.accentDonker,
                  ),
                ),
              ),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
            Text(
              '${TekstenXpNl.xpTotaal(overzicht.xpTotaal)} · '
              '${TekstenXpNl.nogTot(volgend.xpNodig, volgend.niveau.naam)}',
              style: tekst.bodyMedium,
            ),
          ] else
            Text(
              TekstenXpNl.xpTotaal(overzicht.xpTotaal),
              style: tekst.bodyMedium,
            ),
          if (behaald.isNotEmpty) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
            Wrap(
              spacing: klein,
              runSpacing: klein,
              children: [
                for (final b in behaald)
                  Semantics(
                    container: true,
                    label: b.naam,
                    excludeSemantics: true,
                    child: Tooltip(
                      message: b.naam,
                      child: Container(
                        padding: EdgeInsets.all(klein),
                        decoration: const BoxDecoration(
                          color: HhKleuren.accentZacht,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          badgeIcoon(b.icoon),
                          color: HhKleuren.primair,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: klein),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(HhPadenKlussen.profiel),
              icon: const Icon(Icons.military_tech_outlined),
              label: const Text(TekstenStartNl.badgesNaarProfiel),
            ),
          ),
        ],
      ),
    );
  }
}

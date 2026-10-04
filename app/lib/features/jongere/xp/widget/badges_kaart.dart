import 'package:flutter/material.dart';

import '../../../../design/components/hh_kaart.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../domein/xp_tekst.dart';
import '../model/hh_xp.dart';

/// Alle badges: behaald (met datum) of nog niet. Twee per rij; bij grote
/// letters wordt het er één.
class BadgesKaart extends StatelessWidget {
  const BadgesKaart({required this.badges, super.key});

  final List<HhBadge> badges;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);
    final behaald = badges.where((b) => b.isBehaald).length;
    return HhKaart(
      kop: TekstenXpNl.badgesKop,
      actie: Text(
        TekstenXpNl.badgesTeller(behaald, badges.length),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      child: LayoutBuilder(
        builder: (context, maat) {
          final groot = MediaQuery.textScalerOf(context).scale(10) > 15;
          final breedte = groot ? maat.maxWidth : (maat.maxWidth - tussen) / 2;
          return Wrap(
            spacing: tussen,
            runSpacing: tussen,
            children: [
              for (final b in badges)
                SizedBox(
                  width: breedte,
                  child: _BadgeTegel(badge: b),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeTegel extends StatelessWidget {
  const _BadgeTegel({required this.badge});

  final HhBadge badge;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final aan = badge.isBehaald;
    final stand = aan
        ? TekstenXpNl.behaaldOp(datumTekst(badge.behaaldOp))
        : TekstenXpNl.nogNiet;
    return Semantics(
      container: true,
      label: TekstenXpNl.badgeSemantiek(badge.naam, stand),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.s, dichtheid)),
        decoration: BoxDecoration(
          color: aan ? HhKleuren.accentZacht : HhKleuren.oppervlakZacht,
          borderRadius: BorderRadius.circular(HhRadius.groot),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              badgeIcoon(badge.icoon),
              color: aan ? HhKleuren.primair : HhKleuren.tekstDerde,
            ),
            SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.naam,
                    style: tekst.titleSmall!.copyWith(
                      color: aan ? HhKleuren.tekst : HhKleuren.tekstGedempt,
                    ),
                  ),
                  Text(stand, style: tekst.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// De vertrouwensbadges met datum: ouder-toestemming, VOG (verloopt), ID.
class VertrouwenKaart extends StatelessWidget {
  const VertrouwenKaart({required this.vertrouwen, super.key});

  final List<HhVertrouwen> vertrouwen;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return HhKaart(
      kop: TekstenXpNl.vertrouwenKop,
      child: vertrouwen.isEmpty
          ? Text(TekstenXpNl.vertrouwenLeeg, style: tekst.bodyLarge)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < vertrouwen.length; i++) ...[
                  if (i > 0)
                    SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                  _VertrouwenRegel(v: vertrouwen[i]),
                ],
              ],
            ),
    );
  }
}

class _VertrouwenRegel extends StatelessWidget {
  const _VertrouwenRegel({required this.v});

  final HhVertrouwen v;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final dichtheid = HhDichtheidScope.van(context);
    final String stand;
    if (v.isVerlopen) {
      stand = TekstenXpNl.verlopenOp(datumTekst(v.geldigTot));
    } else if (v.geldigTot != null) {
      stand = TekstenXpNl.geldigTot(datumTekst(v.geldigTot));
    } else {
      stand = TekstenXpNl.sinds(datumTekst(v.datum));
    }
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            badgeIcoon(v.icoon),
            color: v.isVerlopen ? HhKleuren.tekstDerde : HhKleuren.succes,
          ),
          SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.naam,
                  style: tekst.titleSmall!.copyWith(
                    color: v.isVerlopen
                        ? HhKleuren.tekstGedempt
                        : HhKleuren.tekst,
                  ),
                ),
                Text(stand, style: tekst.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

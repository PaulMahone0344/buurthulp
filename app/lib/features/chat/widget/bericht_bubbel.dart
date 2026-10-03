import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_chat_nl.dart';
import '../../../theme.dart';
import '../../jongere/klussen/domein/wanneer_tekst.dart' show tijdTekst;
import '../model/hh_bericht.dart';

/// Eén bericht als bubbel: eigen berichten rechts in groen, die van de
/// ander links op het oppervlak, met de tijd eronder. Een snelknop staat
/// vet met een bliksem. "Gelezen" alleen onder mijn laatste gelezen
/// bericht. Was er iets weggefilterd, dan een korte regel uitleg.
class BerichtBubbel extends StatelessWidget {
  const BerichtBubbel({
    required this.bericht,
    required this.isVanMij,
    required this.naamAfzender,
    this.toonGelezen = false,
    super.key,
  });

  final HhBericht bericht;
  final bool isVanMij;
  final String naamAfzender;
  final bool toonGelezen;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final voorgrond = isVanMij ? HhKleuren.opPrimair : HhKleuren.tekst;
    final gedempt = isVanMij ? HhKleuren.randZacht : HhKleuren.tekstGedempt;
    final achtergrond = isVanMij ? HhKleuren.primair : HhKleuren.oppervlak;
    final rond = HhRuimte.l;
    final hoek = HhRadius.klein;
    final isSnel = bericht.soort == HhBerichtSoort.snel && !bericht.isGewist;
    // Integratie (AVG): het account van de afzender is weg.
    final inhoud = bericht.isGewist
        ? TekstenChatNl.berichtVerwijderd
        : bericht.tekst;
    final moment = bericht.gemaakt;
    final tijd = moment == null ? '' : tijdTekst(moment);
    final onder = [
      if (tijd.isNotEmpty) tijd,
      if (toonGelezen) TekstenChatNl.gelezen,
    ].join(' · ');

    final stijl = tekst.bodyLarge?.copyWith(
      color: bericht.isGewist
          ? gedempt
          : (isSnel && !isVanMij ? HhKleuren.primair : voorgrond),
      fontWeight: isSnel ? FontWeight.w600 : null,
      fontStyle: bericht.isGewist ? FontStyle.italic : null,
    );

    return Semantics(
      container: true,
      label: TekstenChatNl.bubbelSemantiek(
        isVanMij ? TekstenChatNl.ik : naamAfzender,
        tijd,
        inhoud,
        isGelezen: toonGelezen,
      ),
      excludeSemantics: true,
      child: Align(
        alignment: isVanMij ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.8,
          alignment: isVanMij ? Alignment.centerRight : Alignment.centerLeft,
          child: Align(
            alignment: isVanMij ? Alignment.centerRight : Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: achtergrond,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(rond),
                  topRight: Radius.circular(rond),
                  bottomLeft: Radius.circular(isVanMij ? rond : hoek),
                  bottomRight: Radius.circular(isVanMij ? hoek : rond),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  HhRuimte.voor(HhRuimte.m, dichtheid),
                  HhRuimte.voor(HhRuimte.s, dichtheid),
                  HhRuimte.voor(HhRuimte.m, dichtheid),
                  HhRuimte.voor(HhRuimte.xs, dichtheid),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (isSnel)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.flash_on_rounded,
                                    size: 18,
                                    color: stijl?.color,
                                  ),
                                ),
                              ),
                            TextSpan(text: inhoud),
                          ],
                        ),
                        style: stijl,
                      ),
                    ),
                    if (bericht.isGefilterd && !bericht.isGewist)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          TekstenChatNl.filterUitleg,
                          style: tekst.bodySmall?.copyWith(
                            color: gedempt,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (onder.isNotEmpty)
                      Text(
                        onder,
                        style: tekst.bodySmall?.copyWith(color: gedempt),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

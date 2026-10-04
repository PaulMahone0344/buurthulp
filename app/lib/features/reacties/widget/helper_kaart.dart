import 'package:flutter/material.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../domein/reactie_regels.dart';
import '../model/hh_reactie.dart';
import '../../jongere/xp/widget/niveau_pil.dart';
import 'initialen_avatar.dart';

/// KiesHelper: één helper die wil helpen. Initialen-avatar, voornaam en
/// leeftijd, niveau-pil (B9: echt niveau, plus "Nieuw in de buurt"), sterren met aantal, "ID
/// gecontroleerd", één regel uit de laatste recensie en het berichtje van de
/// helper. Nooit een achternaam, geboortedatum of adres (die stuurt de
/// server ook niet).
class HelperKaart extends StatelessWidget {
  const HelperKaart({
    required this.kaart,
    required this.onKies,
    this.isBezig = false,
    super.key,
  });

  final HhReactieKaart kaart;
  final VoidCallback? onKies;
  final bool isBezig;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final sterren = sterrenKort(kaart.sterren, kaart.beoordelingen);
    final naam = TekstenReactiesNl.voornaamLeeftijd(
      kaart.voornaam,
      kaart.leeftijd,
    );

    return HhKaart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: TekstenReactiesNl.helperSemantiek(
              naam: kaart.voornaam,
              leeftijd: kaart.leeftijd == null ? '' : '${kaart.leeftijd} jaar',
              sterren: sterren,
              id: kaart.isIdGecontroleerd,
            ),
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialenAvatar(voornaam: kaart.voornaam),
                SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: klein,
                        runSpacing: HhRuimte.voor(HhRuimte.xs, dichtheid),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(naam, style: tekst.titleMedium),
                          NiveauPil(tekst: kaart.niveau),
                          if (kaart.isNieuwInDeBuurt)
                            const NiveauPil(
                              tekst: TekstenReactiesNl.nieuwInDeBuurt,
                              isZacht: true,
                            ),
                        ],
                      ),
                      SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: HhKleuren.accentDonker,
                          ),
                          SizedBox(
                            width: HhRuimte.voor(HhRuimte.xs, dichtheid),
                          ),
                          Flexible(
                            child: Text(sterren, style: tekst.bodyMedium),
                          ),
                        ],
                      ),
                      if (kaart.isIdGecontroleerd)
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: HhKleuren.succes,
                            ),
                            SizedBox(
                              width: HhRuimte.voor(HhRuimte.xs, dichtheid),
                            ),
                            Flexible(
                              child: Text(
                                TekstenReactiesNl.idGecontroleerd,
                                style: tekst.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      if (kaart.ouderGaatMee)
                        Text(
                          TekstenReactiesNl.ouderGaatMee,
                          style: tekst.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (kaart.laatsteRecensie.isNotEmpty) ...[
            SizedBox(height: klein),
            Text(
              '“${kaart.laatsteRecensie}”',
              style: tekst.bodyMedium!.copyWith(fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (kaart.bericht.isNotEmpty) ...[
            SizedBox(height: klein),
            Container(
              padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.m, dichtheid)),
              decoration: BoxDecoration(
                color: HhKleuren.oppervlak,
                borderRadius: BorderRadius.circular(HhRadius.groot),
              ),
              child: Text(kaart.bericht, style: tekst.bodyLarge),
            ),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
          HhKnop(
            label: TekstenReactiesNl.kies(kaart.voornaam),
            icoon: Icons.check_circle_outline,
            isBezig: isBezig,
            onPressed: onKies,
          ),
        ],
      ),
    );
  }
}

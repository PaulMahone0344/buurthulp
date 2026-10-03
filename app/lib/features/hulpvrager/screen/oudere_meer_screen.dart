import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_meer_rij.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';
import '../paden_hulpvrager.dart';
import '../widget/oudere_tabbalk.dart';

/// Tab Meer van de oudere (3 okt, indeling naar BuurtHeld): mijn gegevens,
/// instellingen en hulp als lijst kaarten. Deze schermen openen met push,
/// zodat de oudere met "Terug" weer hier uitkomt.
class OudereMeerScreen extends StatelessWidget {
  const OudereMeerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tussen = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));

    return OudereTabScherm(
      actief: OudereTab.meer,
      child: HhScherm(
        titel: TekstenHulpvragerNl.meerTitel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HhMeerRij(
              titel: TekstenHulpvragerNl.homeMijnGegevens,
              uitleg: TekstenHulpvragerNl.meerGegevensUitleg,
              onTik: () => context.push(HhPadenHulpvrager.gegevens),
            ),
            SizedBox(height: tussen),
            HhMeerRij(
              titel: TekstenHulpvragerNl.homeInstellingen,
              uitleg: TekstenHulpvragerNl.meerInstellingenUitleg,
              onTik: () => context.push(HhPaden.instellingen),
            ),
            SizedBox(height: tussen),
            HhMeerRij(
              titel: TekstenHulpvragerNl.meerHulpTitel,
              uitleg: TekstenHulpvragerNl.meerHulpUitleg,
              onTik: () => context.push(HhPaden.hulp),
            ),
          ],
        ),
      ),
    );
  }
}

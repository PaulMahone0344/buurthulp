import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../../../hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import '../../provider/screening_providers.dart' show meldingVanFout;
import '../paden_xp.dart';
import '../provider/xp_providers.dart';
import 'badges_kaart.dart';
import 'verdiensten_kaart.dart';
import 'xp_niveau_kaart.dart';

/// Het B9-deel van het helperprofiel (HProfiel): niveau + XP-balk, badges,
/// vertrouwensbadges met datum en verdiensten. Elk blok met ruimte erna, zodat
/// het profielscherm het tussen de bestaande kaarten kan zetten.
class XpProfielBlok extends ConsumerWidget {
  const XpProfielBlok({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(xpOverzichtProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid));
    final waarde = stand.value;
    if (waarde == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stand.hasError)
            HhLegeStaat(
              icoon: Icons.cloud_off_outlined,
              titel: TekstenXpNl.ladenMislukt,
              uitleg: meldingVanFout(stand.error),
              knopLabel: TekstenNl.opnieuwProberen,
              onKnop: () => ref.invalidate(xpOverzichtProvider),
            )
          else
            const HhLaadStaat.skelet(regels: 3),
          tussen,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        XpNiveauKaart(overzicht: waarde),
        tussen,
        BadgesKaart(badges: waarde.badges),
        tussen,
        VertrouwenKaart(vertrouwen: waarde.vertrouwen),
        tussen,
        VerdienstenKaart(
          verdiensten: waarde.verdiensten,
          nu: ref.watch(klokProvider)(),
          onAlles: () => context.push(HhPadenXp.verdiensten),
        ),
        tussen,
      ],
    );
  }
}

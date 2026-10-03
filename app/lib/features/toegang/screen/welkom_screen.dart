import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_rol.dart';
import '../provider/sessie_providers.dart';

/// G2. Twee grote keuzes: hulp zoeken (bewoner) en helpen (helper).
/// De coordinator registreert niet en logt in via
/// "Ik heb al een account". De keuze zet de dichtheid: "Ik zoek hulp"
/// maakt alles groot voordat er een account is.
class WelkomScreen extends ConsumerWidget {
  const WelkomScreen({super.key});

  // go, geen push: bij een sessiewissel bekijkt de guard de basisroute
  // van de stapel, en dat moet dan G4 (of G3) zijn, niet G2. De
  // terugknop van G3/G4 gaat expliciet naar G2.
  void _kies(BuildContext context, WidgetRef ref, HhRol rol) {
    ref.read(gekozenRolProvider.notifier).kies(rol);
    context.go(HhPaden.registreren);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;

    return HhScherm(
      titel: TekstenNl.welkomTitel,
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TekstenNl.welkomUitleg, style: tekst.bodyLarge),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenNl.keuzeZoekHulp,
            icoon: Icons.front_hand_outlined,
            maat: HhDichtheid.groot,
            onPressed: () => _kies(context, ref, HhRol.hulpvrager),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
          Text(
            TekstenAanmeldenNl.welkomZoekHulpUitleg,
            style: tekst.bodyMedium,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
          HhKnop(
            label: TekstenNl.keuzeWilHelpen,
            icoon: Icons.volunteer_activism_outlined,
            maat: HhDichtheid.groot,
            onPressed: () => _kies(context, ref, HhRol.jongere),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
          Text(
            TekstenAanmeldenNl.welkomWilHelpenUitleg,
            style: tekst.bodyMedium,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          const Divider(),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenNl.alEenAccount,
            soort: HhKnopSoort.tekst,
            onPressed: () {
              ref.read(gekozenRolProvider.notifier).kies(null);
              context.go(HhPaden.inloggen);
            },
          ),
        ],
      ),
    );
  }
}

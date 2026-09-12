import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/paden.dart';
import '../design/components/hh_knop.dart';
import '../design/components/hh_lege_staat.dart';
import '../design/components/hh_meld_balk.dart';
import '../design/components/hh_scherm.dart';
import '../design/dichtheid_scope.dart';
import '../l10n/teksten_nl.dart';
import '../theme.dart';
import 'toegang/model/hh_rol.dart';
import 'toegang/provider/sessie_providers.dart';

/// Landing per rol na inloggen (M2). Naam, rol, uitloggen en de weg naar
/// instellingen en hulp; nog geen tabs of inhoud. De echte tabnavigatie
/// komt per rol in M3-M10.
class RolLandingScherm extends ConsumerWidget {
  const RolLandingScherm({required this.rol, required this.icoon, super.key});

  final HhRol rol;
  final IconData icoon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != rol) return const Scaffold();

    return HhScherm(
      titel: TekstenNl.landingWelkom(gebruiker.naam),
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TekstenNl.landingRol(rol.naam), style: tekst.bodyLarge),
          if (!gebruiker.isBevestigd) ...[
            SizedBox(height: tussen),
            const HhMeldBalk(
              soort: HhMeldSoort.waarschuwing,
              tekst: TekstenNl.bevestigEmailBanner,
            ),
            HhKnop(
              label: TekstenNl.bevestigEmailBannerKnop,
              soort: HhKnopSoort.tekst,
              onPressed: () => context.push(HhPaden.bevestigEmail),
            ),
          ],
          SizedBox(height: tussen),
          HhLegeStaat(
            icoon: icoon,
            titel: rol.naam,
            uitleg: TekstenNl.landingKomtLater,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenNl.landingInstellingen,
            icoon: Icons.settings_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPaden.instellingen),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenNl.hulpTitel,
            icoon: Icons.help_outline,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPaden.hulp),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenNl.uitloggen,
            icoon: Icons.logout,
            soort: HhKnopSoort.tekst,
            onPressed: () =>
                ref.read(sessieControllerProvider.notifier).uitloggen(),
          ),
        ],
      ),
    );
  }
}

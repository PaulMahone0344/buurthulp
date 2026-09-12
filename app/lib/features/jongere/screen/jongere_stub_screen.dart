import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../model/screening_stap.dart';
import '../paden_jongere.dart';
import '../provider/screening_providers.dart';
import '../widget/hh_screening_pil.dart';

/// Landing van de jongere (/jongere). Zelfde inhoud als de M2-landing
/// (naam, rol, bevestig-banner, instellingen, hulp, uitloggen) plus een
/// kaart "Screening" met de status, naar J9. De klussenlijst komt in M5. Een
/// jongere die nog niet goedgekeurd is komt hier niet: de router-guard
/// stuurt hem naar J9.
class JongereStubScreen extends ConsumerWidget {
  const JongereStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final stand = ref.watch(screeningControllerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != HhRol.jongere) {
      return const Scaffold();
    }

    return HhScherm(
      titel: TekstenNl.landingWelkom(gebruiker.naam),
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            TekstenNl.landingRol(HhRol.jongere.naam),
            style: tekst.bodyLarge,
          ),
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
          HhKaart(
            kop: TekstenJongereNl.landingScreening,
            child: switch (stand) {
              AsyncData<ScreeningGegevens>(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HhScreeningPil(
                    status: value.verificatiestatus,
                    label: TekstenJongereNl.landingScreening,
                  ),
                  SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
                  HhKnop(
                    label: TekstenJongereNl.landingScreeningKnop,
                    icoon: Icons.fact_check_outlined,
                    soort: HhKnopSoort.tweedeKeus,
                    onPressed: () => context.push(HhPadenJongere.overzicht),
                  ),
                ],
              ),
              AsyncError<ScreeningGegevens>(:final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HhMeldBalk(
                    soort: HhMeldSoort.fout,
                    tekst: meldingVanFout(error),
                  ),
                  HhKnop(
                    label: TekstenNl.opnieuwProberen,
                    soort: HhKnopSoort.tekst,
                    onPressed: () => ref
                        .read(screeningControllerProvider.notifier)
                        .vernieuw(),
                  ),
                ],
              ),
              _ => const HhLaadStaat.skelet(regels: 1),
            },
          ),
          SizedBox(height: tussen),
          const HhLegeStaat(
            icoon: Icons.directions_run,
            titel: TekstenNl.rolJongere,
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

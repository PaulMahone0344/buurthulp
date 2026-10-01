import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../toegang/model/hh_rol.dart';
import '../../meldingen/widget/laatste_melding_regel.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../paden_hulpvrager.dart';
import '../status/paden_status.dart';
import '../veiligheid/meldkamer_config.dart';
import '../veiligheid/paden_veiligheid.dart';
import '../provider/concept_controller.dart';

/// O1. Het begin voor de oudere: drie grote knoppen (hulp vragen, mijn
/// hulpvragen, bel ons) en klein daarboven de naam, instellingen en mijn
/// gegevens. Geen terugknop: hier is niets om naar terug te gaan.
/// M8: "Bel ons" opent O10; de laatste melding staat als rustige regel
/// bovenaan (geen teller, geen lijst).
class HulpvragerHomeScreen extends ConsumerStatefulWidget {
  const HulpvragerHomeScreen({super.key});

  @override
  ConsumerState<HulpvragerHomeScreen> createState() =>
      _HulpvragerHomeScreenState();
}

class _HulpvragerHomeScreenState extends ConsumerState<HulpvragerHomeScreen> {
  void _hulpVragen() {
    // Een nieuwe hulpvraag begint altijd leeg.
    ref.read(conceptProvider.notifier).wis();
    context.push(HhPadenHulpvrager.hulpVragenWat);
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != HhRol.hulpvrager) {
      return const Scaffold();
    }
    // De naam komt uit de sessie; O1 laadt bewust niets van de server
    // (een wijziging op O12 is pas na opnieuw inloggen zichtbaar in de
    // kop, zie OPEN-PUNTEN-M4).
    return HhScherm(
      titel: TekstenNl.landingWelkom(gebruiker.naam),
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: klein,
            runSpacing: klein,
            children: [
              HhKnop(
                label: TekstenHulpvragerNl.homeInstellingen,
                semantiekLabel: TekstenHulpvragerNl.homeInstellingenSemantiek,
                icoon: Icons.settings_outlined,
                soort: HhKnopSoort.tekst,
                onPressed: () => context.push(HhPaden.instellingen),
              ),
              HhKnop(
                label: TekstenHulpvragerNl.homeMijnGegevens,
                semantiekLabel: TekstenHulpvragerNl.homeMijnGegevensSemantiek,
                icoon: Icons.person_outline,
                soort: HhKnopSoort.tekst,
                onPressed: () => context.push(HhPadenHulpvrager.gegevens),
              ),
            ],
          ),
          if (!gebruiker.isBevestigd) ...[
            SizedBox(height: tussen),
            const HhMeldBalk(
              soort: HhMeldSoort.waarschuwing,
              tekst: TekstenNl.bevestigEmailBanner,
            ),
          ],
          // M8: de laatste melding, rustig, zonder teller.
          SizedBox(height: tussen),
          const LaatsteMeldingRegel(),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenHulpvragerNl.homeHulpVragen,
            semantiekLabel: TekstenHulpvragerNl.homeHulpVragenSemantiek,
            icoon: Icons.add_circle_outline,
            onPressed: _hulpVragen,
          ),
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenHulpvragerNl.homeMijnHulpvragen,
            semantiekLabel: TekstenHulpvragerNl.homeMijnHulpvragenSemantiek,
            icoon: Icons.list_alt_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPadenStatus.hulpvragen),
          ),
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenHulpvragerNl.homeBelOns,
            semantiekLabel: TekstenHulpvragerNl.homeBelOnsSemantiek(
              MeldkamerConfig.telefoon,
            ),
            icoon: Icons.phone_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPadenVeiligheid.belOns),
          ),
        ],
      ),
    );
  }
}

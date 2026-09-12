import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../core/config.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../../toegang/screen/hulp_screen.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';

/// O1. Het begin voor de oudere: drie grote knoppen (hulp vragen, mijn
/// hulpvragen, bel ons) en klein daarboven de naam, instellingen en mijn
/// gegevens. Geen terugknop: hier is niets om naar terug te gaan.
class HulpvragerHomeScreen extends ConsumerStatefulWidget {
  const HulpvragerHomeScreen({super.key});

  @override
  ConsumerState<HulpvragerHomeScreen> createState() =>
      _HulpvragerHomeScreenState();
}

class _HulpvragerHomeScreenState extends ConsumerState<HulpvragerHomeScreen> {
  String? _belMelding;

  /// Zelfde belknop-aanpak als G8: launchUrl via de vervangbare opener,
  /// bij mislukken het nummer in een meldbalk.
  Future<void> _bel() async {
    setState(() => _belMelding = null);
    final uri = Uri(scheme: 'tel', path: HhConfig.meldkamerTelefoon);
    var gelukt = false;
    try {
      gelukt = await ref.read(urlOpenerProvider)(uri);
    } on Exception {
      gelukt = false;
    }
    if (!mounted || gelukt) return;
    setState(
      () => _belMelding = TekstenNl.hulpBellenLuktNiet(
        HhConfig.meldkamerTelefoon,
      ),
    );
  }

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
          if (_belMelding != null) ...[
            SizedBox(height: tussen),
            HhMeldBalk(soort: HhMeldSoort.waarschuwing, tekst: _belMelding!),
          ],
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
            onPressed: () => context.push(HhPadenHulpvrager.mijnHulpvragen),
          ),
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenHulpvragerNl.homeBelOns,
            semantiekLabel: TekstenHulpvragerNl.homeBelOnsSemantiek(
              HhConfig.meldkamerTelefoon,
            ),
            icoon: Icons.phone_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: _bel,
          ),
        ],
      ),
    );
  }
}

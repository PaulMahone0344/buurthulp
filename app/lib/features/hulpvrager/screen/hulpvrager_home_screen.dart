import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../adres/widget/adres_aanvullen_balk.dart';
import '../../jongere/widget/helper_wacht_start.dart' show WachtBalk;
import '../../toegang/domein/werkgebied.dart';
import '../../toegang/model/hh_rol.dart';
import '../../meldingen/widget/laatste_melding_regel.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';
import '../widget/oudere_tabbalk.dart';

/// O1. Het begin voor de oudere: de grote knop "Hulp vragen". Mijn
/// hulpvragen, Bel ons en Meer (gegevens, instellingen) zijn sinds 3 okt
/// tabs in de balk onderin (indeling naar BuurtHeld). Geen terugknop.
/// M8: de laatste melding staat als rustige regel bovenaan (geen teller,
/// geen lijst).
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

    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != HhRol.hulpvrager) {
      return const Scaffold();
    }
    // De naam komt uit de sessie; O1 laadt bewust niets van de server
    // (een wijziging op O12 is pas na opnieuw inloggen zichtbaar in de
    // kop, zie OPEN-PUNTEN-M4).
    return OudereTabScherm(
      actief: OudereTab.start,
      child: HhScherm(
        titel: TekstenNl.landingWelkom(gebruiker.naam),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!gebruiker.isBevestigd) ...[
              SizedBox(height: tussen),
              const HhMeldBalk(
                soort: HhMeldSoort.waarschuwing,
                tekst: TekstenNl.bevestigEmailBanner,
              ),
            ],
            // ADRES: een onvolledig adres eerst aanvullen (gele balk).
            SizedBox(height: tussen),
            const AdresAanvullenBalk(),
            // M8: de laatste melding, rustig, zonder teller.
            const LaatsteMeldingRegel(),
            SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
            // B2: buiten het werkgebied (of adres niet gevonden) geen klus.
            if (gebruiker.magKlusPlaatsen)
              HhKnop(
                label: TekstenHulpvragerNl.homeHulpVragen,
                semantiekLabel: TekstenHulpvragerNl.homeHulpVragenSemantiek,
                icoon: Icons.add_circle_outline,
                onPressed: _hulpVragen,
              )
            else
              WachtBalk(
                kop: gebruiker.werkgebiedStatus == HhWerkgebiedStatus.onbekend
                    ? TekstenAanmeldenNl.adresOnbekendKop
                    : TekstenAanmeldenNl.nietInBuurtKop,
                uitleg: werkgebiedMelding(
                  gebruiker.wijkId,
                  gebruiker.werkgebiedStatus,
                )!,
              ),
          ],
        ),
      ),
    );
  }
}

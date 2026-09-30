import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_familie_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/familie_rechten.dart';
import '../model/hh_koppeling.dart';
import '../paden_familie.dart';
import '../provider/familie_providers.dart';
import '../widget/oudere_tegel.dart';

/// F1. De landing van het familielid: de gekoppelde ouderen en "Familielid
/// koppelen". Aanvragen die op toestemming wachten staan er NIET (besluit
/// 30 sep 2026): anders verraadt F1 of een e-mailadres bij een oudere
/// hoort. De server geeft ze ook niet (script 44). Met precies één
/// gekoppelde oudere gaat het meteen door naar F3 (behalve als je vanaf F3
/// terugkomt: ?lijst=1). Het meldingen-belletje (M8) zit eromheen in
/// FamilieStubScreen.
class FamilieHomeScreen extends ConsumerStatefulWidget {
  const FamilieHomeScreen({this.toonLijst = false, super.key});

  /// true: niet meteen door naar F3.
  final bool toonLijst;

  @override
  ConsumerState<FamilieHomeScreen> createState() => _FamilieHomeScreenState();
}

class _FamilieHomeScreenState extends ConsumerState<FamilieHomeScreen> {
  bool _isDoorgestuurd = false;

  void _misschienDoor(List<HhKoppeling> koppelingen) {
    if (widget.toonLijst || _isDoorgestuurd) return;
    final oudere = meteenDoorNaar(koppelingen);
    if (oudere == null) return;
    _isDoorgestuurd = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(HhPadenFamilie.oudere(oudere));
    });
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != HhRol.familie) {
      return const Scaffold();
    }
    final stand = ref.watch(mijnKoppelingenProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.m, dichtheid);

    final lijst = stand.value;
    final List<Widget> inhoud;
    if (lijst != null) {
      _misschienDoor(lijst);
      final indeling = deelKoppelingenIn(lijst);
      inhoud = [
        if (indeling.actief.isEmpty)
          const HhLegeStaat(
            icoon: Icons.family_restroom,
            titel: TekstenFamilieNl.f1Leeg,
            uitleg: TekstenFamilieNl.f1LeegUitleg,
          ),
        if (indeling.actief.isNotEmpty) ...[
          Text(TekstenFamilieNl.f1GekoppeldKop, style: tekst.titleLarge),
          SizedBox(height: klein),
          for (final k in indeling.actief) ...[
            OudereTegel(
              naam: k.oudereNaam.isEmpty
                  ? TekstenFamilieNl.onbekendeNaam
                  : k.oudereNaam,
              onTik: () => context.push(HhPadenFamilie.oudere(k.oudereId)),
            ),
            SizedBox(height: klein),
          ],
        ],
      ];
    } else if (stand.hasError) {
      inhoud = [
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenFamilieNl.f1LadenMislukt,
          uitleg: meldingVanFout(stand.error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.invalidate(mijnKoppelingenProvider),
        ),
      ];
    } else {
      inhoud = const [HhLaadStaat.skelet(regels: 3)];
    }

    return HhScherm(
      titel: TekstenFamilieNl.f1Titel,
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HhKnop(
              label: TekstenFamilieNl.f1Instellingen,
              icoon: Icons.settings_outlined,
              soort: HhKnopSoort.tekst,
              onPressed: () => context.push(HhPaden.instellingen),
            ),
          ),
          if (!gebruiker.isBevestigd) ...[
            SizedBox(height: klein),
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
          SizedBox(height: klein),
          Text(TekstenFamilieNl.f1Uitleg, style: tekst.bodyLarge),
          SizedBox(height: tussen),
          ...inhoud,
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenFamilieNl.f1Koppelen,
            icoon: Icons.person_add_alt_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPadenFamilie.koppelen),
          ),
        ],
      ),
    );
  }
}

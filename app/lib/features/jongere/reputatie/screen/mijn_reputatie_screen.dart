import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_adres_nl.dart';
import '../../../../l10n/teksten_beoordelen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../theme.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../paden_jongere.dart';
import '../../provider/screening_providers.dart' show meldingVanFout;
import '../domein/sterren.dart';
import '../model/hh_beoordeling.dart';
import '../provider/beoordeling_providers.dart';
import '../widget/sterren_rij.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../xp/paden_xp.dart';
import '../../xp/provider/xp_providers.dart';
import '../../xp/widget/xp_profiel_blok.dart';

/// J19. Mijn profiel en reputatie: het gemiddelde aantal sterren en het
/// aantal klussen zoals de server ze uitrekende (hh_users), en de laatste
/// beoordelingen met tekst. Vervangt de tijdelijke inhoud van de tab
/// Profiel; het screeningoverzicht (J9) blijft bereikbaar als "Mijn
/// screening". B9: daaronder niveau en XP, badges, vertrouwen (met datum)
/// en verdiensten (XpProfielBlok) en de knop "Verklaring van inzet".
/// Pull-to-refresh haalt de nieuwe stand op.
///
/// Dit scherm is voor de jongere zelf. De oudere ziet nergens gemiddelden of
/// aantallen (ouderenregel).
class MijnReputatieScreen extends ConsumerWidget {
  const MijnReputatieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(mijnReputatieProvider);
    final naam = ref.watch(huidigeGebruikerProvider)?.naam ?? '';
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    Future<void> vernieuw() {
      ref.invalidate(xpOverzichtProvider);
      return ref.refresh(mijnReputatieProvider.future);
    }

    final waarde = stand.value;
    final List<Widget> inhoud;
    if (waarde != null) {
      inhoud = [
        _ReputatieKaart(naam: naam, reputatie: waarde.reputatie),
        SizedBox(height: tussen),
        // B9: niveau, badges, vertrouwen en verdiensten.
        const XpProfielBlok(),
        _LaatsteKaart(laatste: waarde.laatste),
      ];
    } else if (stand.hasError) {
      inhoud = [
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenBeoordelenNl.j19LadenMislukt,
          uitleg: meldingVanFout(stand.error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.invalidate(mijnReputatieProvider),
        ),
      ];
    } else {
      inhoud = const [HhLaadStaat.skelet(regels: 3)];
    }

    return HhScherm(
      titel: TekstenBeoordelenNl.j19Titel,
      toonTerug: false,
      scrollbaar: false,
      child: RefreshIndicator(
        onRefresh: vernieuw,
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            rand,
            0,
            rand,
            HhRuimte.voor(HhRuimte.xl, dichtheid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...inhoud,
              SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
              // B9: Verklaring van inzet (punt 19).
              HhKnop(
                label: TekstenXpNl.verklaringKnop,
                icoon: Icons.workspace_premium_outlined,
                soort: HhKnopSoort.tweedeKeus,
                onPressed: () => context.push(HhPadenXp.verklaring),
              ),
              SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
              HhKnop(
                label: TekstenBeoordelenNl.j19Screening,
                icoon: Icons.verified_user_outlined,
                soort: HhKnopSoort.tweedeKeus,
                onPressed: () => context.push(HhPadenJongere.overzicht),
              ),
              // ADRES (antwoord Ibrahim 5): verhuisd? Zelf het adres
              // aanpassen; de server bepaalt het werkgebied opnieuw.
              SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
              HhKnop(
                label: TekstenAdresNl.mijnAdresTitel,
                icoon: Icons.home_outlined,
                soort: HhKnopSoort.tweedeKeus,
                onPressed: () => context.push(HhPadenJongere.adres),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReputatieKaart extends StatelessWidget {
  const _ReputatieKaart({required this.naam, required this.reputatie});

  final String naam;
  final HhReputatie reputatie;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final gemiddeld = TekstenBeoordelenNl.j19Gemiddeld(
      sterrenTekst(reputatie.sterrenGemiddeld),
    );

    return HhKaart(
      kop: TekstenBeoordelenNl.j19ReputatieKop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (naam.isNotEmpty) ...[
            Text(naam, style: tekst.titleLarge),
            SizedBox(height: klein),
          ],
          if (reputatie.heeftBeoordelingen) ...[
            SterrenRij(waarde: reputatie.sterrenGemiddeld, label: gemiddeld),
            SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
            ExcludeSemantics(child: Text(gemiddeld, style: tekst.titleLarge)),
            Text(
              TekstenBeoordelenNl.j19GemiddeldUitleg,
              style: tekst.bodyMedium,
            ),
          ] else ...[
            Text(
              TekstenBeoordelenNl.j19NogGeenSterren,
              style: tekst.titleLarge,
            ),
            Text(
              TekstenBeoordelenNl.j19NogGeenSterrenUitleg,
              style: tekst.bodyMedium,
            ),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: HhMaten.icoonKeuzerij(dichtheid),
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: klein),
              Expanded(
                child: Text(
                  TekstenBeoordelenNl.j19Klussen(reputatie.klussenAantal),
                  style: tekst.bodyLarge,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LaatsteKaart extends StatelessWidget {
  const _LaatsteKaart({required this.laatste});

  final List<HhBeoordeling> laatste;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    return HhKaart(
      kop: TekstenBeoordelenNl.j19LaatsteKop,
      child: laatste.isEmpty
          ? Text(TekstenBeoordelenNl.j19GeenTeksten, style: tekst.bodyLarge)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < laatste.length; i++) ...[
                  if (i > 0) SizedBox(height: tussen),
                  _BeoordelingRegel(beoordeling: laatste[i]),
                ],
              ],
            ),
    );
  }
}

class _BeoordelingRegel extends StatelessWidget {
  const _BeoordelingRegel({required this.beoordeling});

  final HhBeoordeling beoordeling;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final sterren = TekstenBeoordelenNl.sterrenSemantiek(
      beoordeling.sterren,
      sterrenWoord(beoordeling.sterren),
    );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SterrenRij(waarde: beoordeling.sterren.toDouble(), label: sterren),
          Text(beoordeling.tekst, style: tekst.bodyLarge),
        ],
      ),
    );
  }
}

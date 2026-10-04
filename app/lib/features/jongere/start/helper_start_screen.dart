import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_klussen_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../l10n/teksten_start_nl.dart';
import '../../../theme.dart';
import '../../adres/widget/adres_aanvullen_balk.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../reacties/widget/kan_nu_helpen_schakelaar.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/helper_wacht.dart';
import '../klussen/domein/klus_filter.dart';
import '../klussen/model/hh_klus.dart';
import '../klussen/paden_klussen.dart';
import '../klussen/provider/klussen_providers.dart';
import '../klussen/widget/jongere_tabbalk.dart';
import '../klussen/widget/klus_tegel.dart';
import '../provider/screening_providers.dart';
import '../uitvoeren/domein/klus_overgang.dart';
import '../uitvoeren/paden_uitvoeren.dart';
import '../widget/helper_wacht_start.dart';
import '../xp/paden_xp.dart';
import '../xp/provider/xp_providers.dart';
import '../xp/widget/verdiensten_kaart.dart';
import 'helper_niveau_kaart.dart';

/// Start van de helper (B10, mockup StartHelper): "Ik kan nu helpen", het
/// niveau met XP-balk en badges, de volgende eigen klus, de drie dichtstbij
/// klussen in de buurt (met "Alle" naar de tab Klussen) en de verdiensten.
/// Een helper die nog wacht (nagekeken, ouder, VOG) ziet alleen de gele balk,
/// net als vroeger op de klussenlijst. Pull-to-refresh haalt alles opnieuw.
class HelperStartScreen extends ConsumerWidget {
  const HelperStartScreen({super.key});

  static const _inDeBuurtMax = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != HhRol.jongere) {
      return const Scaffold();
    }
    final voornaam = gebruiker.naam.trim().split(RegExp(r'\s+')).first;
    final titel = TekstenStartNl.hoi(voornaam);

    final wacht = ref.watch(helperWachtProvider);
    if (wacht != HelperWacht.klaar) {
      return JongereTabScherm(
        actief: JongereTab.start,
        child: HhScherm(
          titel: titel,
          toonTerug: false,
          child: switch ((wacht, ref.watch(screeningControllerProvider))) {
            (final HelperWacht w, _) => HelperWachtStart(wacht: w),
            (null, AsyncError(:final error)) => HhLegeStaat(
              icoon: Icons.cloud_off_outlined,
              titel: TekstenKlussenNl.j11LadenMislukt,
              uitleg: meldingVanFout(error),
              knopLabel: TekstenNl.opnieuwProberen,
              onKnop: () =>
                  ref.read(screeningControllerProvider.notifier).vernieuw(),
            ),
            (null, _) => const HhLaadStaat.skelet(regels: 3),
          },
        ),
      );
    }

    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid));
    final nu = ref.watch(klokProvider)();
    final xp = ref.watch(xpOverzichtProvider).value;

    Future<void> vernieuw() async {
      ref.invalidate(xpOverzichtProvider);
      ref.invalidate(mijnKlussenProvider);
      await ref.read(openKlussenProvider.notifier).vernieuw();
    }

    return JongereTabScherm(
      actief: JongereTab.start,
      child: HhScherm(
        titel: titel,
        toonTerug: false,
        scrollbaar: false,
        child: RefreshIndicator(
          onRefresh: vernieuw,
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              rand,
              0,
              rand,
              HhRuimte.voor(HhRuimte.xl, dichtheid),
            ),
            children: [
              const AdresAanvullenBalk(),
              const KanNuHelpenSchakelaar(),
              tussen,
              if (xp != null) ...[HelperNiveauKaart(overzicht: xp), tussen],
              _VolgendeKlus(nu: nu),
              _InDeBuurt(nu: nu, max: _inDeBuurtMax),
              tussen,
              if (xp != null)
                VerdienstenKaart(
                  verdiensten: xp.verdiensten,
                  nu: nu,
                  onAlles: () => context.push(HhPadenXp.verdiensten),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// De eerstvolgende eigen klus die gepland is of loopt. Niets als er geen is.
class _VolgendeKlus extends ConsumerWidget {
  const _VolgendeKlus({required this.nu});

  final DateTime nu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mijn = ref.watch(mijnKlussenProvider).value ?? const <HhKlus>[];
    final gepland = mijn.where((k) => isInUitvoering(k.status)).toList()
      ..sort((a, b) {
        final x = a.wanneerVan;
        final y = b.wanneerVan;
        if (x == null) return y == null ? 0 : 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
    if (gepland.isEmpty) return const SizedBox.shrink();
    final klus = gepland.first;
    final dichtheid = HhDichtheidScope.van(context);
    return Padding(
      padding: EdgeInsets.only(bottom: HhRuimte.voor(HhRuimte.l, dichtheid)),
      child: HhKaart(
        kop: TekstenStartNl.volgendeKlusKop,
        child: KlusTegel(
          klus: klus,
          nu: nu,
          toonStatus: true,
          onTik: () => context.push(HhPadenUitvoeren.uitvoeren(klus.id)),
        ),
      ),
    );
  }
}

/// De drie klussen die de lijst als eerste toont (zelfde filter en straal als
/// de tab Klussen), met "Alle" naar die tab.
class _InDeBuurt extends ConsumerWidget {
  const _InDeBuurt({required this.nu, required this.max});

  final DateTime nu;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(gefilterdeKlussenProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    final List<Widget> inhoud = switch (stand) {
      AsyncData<GefilterdeKlussen>(:final value) when value.klussen.isEmpty => [
        Text(TekstenStartNl.geenInDeBuurt, style: tekst.bodyLarge),
      ],
      AsyncData<GefilterdeKlussen>(:final value) => [
        for (final klus in value.klussen.take(max)) ...[
          KlusTegel(
            klus: klus,
            nu: nu,
            middelpunt: value.middelpunt,
            onTik: () => context.push(HhPadenKlussen.klusDetail(klus.id)),
          ),
          SizedBox(height: tussen),
        ],
      ],
      AsyncError() => [
        Text(TekstenStartNl.ladenMislukt, style: tekst.bodyLarge),
      ],
      _ => const [HhLaadStaat.skelet(regels: 2)],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(
                TekstenStartNl.inDeBuurtKop,
                style: tekst.titleMedium,
              ),
            ),
            Semantics(
              label: TekstenStartNl.alleSemantiek,
              button: true,
              excludeSemantics: true,
              child: TextButton(
                onPressed: () => context.go(HhPadenKlussen.lijst),
                child: const Text(TekstenStartNl.alle),
              ),
            ),
          ],
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
        ...inhoud,
      ],
    );
  }
}

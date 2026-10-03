import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_keuzerij.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../theme.dart';
import '../../../hulpvrager/domein/klustype_icoon.dart';
import '../../../hulpvrager/model/hulpvraag_concept.dart';
import '../../../hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../domein/helper_wacht.dart';
import '../../model/hh_profiel.dart';
import '../../provider/screening_providers.dart';
import '../../widget/helper_wacht_start.dart';
import '../domein/dagdeel.dart';
import '../domein/klus_filter.dart';
import '../domein/wanneer_tekst.dart';
import '../model/hh_klus.dart';
import '../paden_klussen.dart';
import '../provider/klussen_providers.dart';
import '../widget/jongere_tabbalk.dart';
import '../widget/klus_tegel.dart';
import '../widget/klussen_kaart.dart';

/// Lijst (J11) of kaart (J12).
enum KlussenWeergave { lijst, kaart }

/// J11/J12. De landing van de goedgekeurde jongere (/jongere): open klussen
/// in zijn wijk als lijst of op de kaart, met de filterbalk (soort, dagdeel)
/// en de straal uit zijn profiel als client-filter. Pull-to-refresh op de
/// lijst. B2: wacht de helper nog (nagekeken, ouder-toestemming, VOG), dan
/// alleen de gele balk en geen klussen; nog niet verstuurd of afgewezen
/// stuurt de router-guard naar J9.
class KlussenHomeScreen extends ConsumerStatefulWidget {
  const KlussenHomeScreen({super.key});

  /// Klustypes per rij in de filterbalk (zes op een rij past niet op 390 px
  /// bij 200 procent; zelfde keuze als O2 en J8).
  static const klustypesPerRij = 3;

  @override
  ConsumerState<KlussenHomeScreen> createState() => _KlussenHomeScreenState();
}

class _KlussenHomeScreenState extends ConsumerState<KlussenHomeScreen> {
  KlussenWeergave _weergave = KlussenWeergave.lijst;

  void _openKlus(HhKlus klus) =>
      context.push(HhPadenKlussen.klusDetail(klus.id));

  Future<void> _vernieuw() => ref.read(openKlussenProvider.notifier).vernieuw();

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);

    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != HhRol.jongere) {
      return const Scaffold();
    }

    // B2: zolang de helper nog wacht (nagekeken, ouder, VOG) geen klussen,
    // ook geen verzoek naar de server; wel de gele balk.
    final wacht = ref.watch(helperWachtProvider);
    if (wacht != HelperWacht.klaar) {
      return JongereTabScherm(
        actief: JongereTab.klussen,
        child: HhScherm(
          titel: TekstenKlussenNl.j11Titel,
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

    final gefilterd = ref.watch(gefilterdeKlussenProvider);
    final nu = ref.watch(klokProvider)();

    final schakelaar = HhKeuzerij<KlussenWeergave>(
      semantiekLabel: TekstenKlussenNl.weergaveLabel,
      keuzes: const [
        HhKeuze(
          waarde: KlussenWeergave.lijst,
          label: TekstenKlussenNl.weergaveLijst,
          icoon: Icons.view_list_outlined,
        ),
        HhKeuze(
          waarde: KlussenWeergave.kaart,
          label: TekstenKlussenNl.weergaveKaart,
          icoon: Icons.map_outlined,
        ),
      ],
      geselecteerd: {_weergave},
      onGewijzigd: (keuze) => setState(() => _weergave = keuze.first),
    );

    return JongereTabScherm(
      actief: JongereTab.klussen,
      child: HhScherm(
        titel: TekstenKlussenNl.j11Titel,
        toonTerug: false,
        scrollbaar: false,
        child: switch (_weergave) {
          KlussenWeergave.lijst => _Lijst(
            stand: gefilterd,
            nu: nu,
            rand: rand,
            schakelaar: schakelaar,
            onKlus: _openKlus,
            onVernieuw: _vernieuw,
          ),
          KlussenWeergave.kaart => _Kaart(
            stand: gefilterd,
            rand: rand,
            schakelaar: schakelaar,
            onKlus: _openKlus,
            onNaarLijst: () =>
                setState(() => _weergave = KlussenWeergave.lijst),
            onVernieuw: _vernieuw,
          ),
        },
      ),
    );
  }
}

/// J11: filterbalk, telling, tegels, melding over de straal. Alles in een
/// ListView zodat pull-to-refresh ook op een lege lijst werkt.
class _Lijst extends ConsumerWidget {
  const _Lijst({
    required this.stand,
    required this.nu,
    required this.rand,
    required this.schakelaar,
    required this.onKlus,
    required this.onVernieuw,
  });

  final AsyncValue<GefilterdeKlussen> stand;
  final DateTime nu;
  final double rand;
  final Widget schakelaar;
  final ValueChanged<HhKlus> onKlus;
  final Future<void> Function() onVernieuw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);
    final filter = ref.watch(klusFilterProvider);
    final straal = ref.watch(straalKmProvider);

    final inhoud = switch (stand) {
      AsyncData<GefilterdeKlussen>(:final value) => [
        if (value.klussen.isEmpty)
          filter.isLeeg && value.buitenStraal == 0
              ? const HhLegeStaat(
                  icoon: Icons.volunteer_activism_outlined,
                  titel: TekstenKlussenNl.j11Leeg,
                  uitleg: TekstenKlussenNl.j11LeegUitleg,
                )
              : HhLegeStaat(
                  icoon: Icons.filter_alt_off_outlined,
                  titel: TekstenKlussenNl.j11LeegGefilterd,
                  uitleg: TekstenKlussenNl.j11LeegGefilterdUitleg,
                  knopLabel: filter.isLeeg
                      ? null
                      : TekstenKlussenNl.filterWissen,
                  onKnop: filter.isLeeg
                      ? null
                      : () => ref.read(klusFilterProvider.notifier).wis(),
                )
        else ...[
          Text(
            TekstenKlussenNl.j11Aantal(value.klussen.length),
            style: tekst.labelSmall,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          for (final klus in value.klussen) ...[
            KlusTegel(
              klus: klus,
              nu: nu,
              middelpunt: value.middelpunt,
              onTik: () => onKlus(klus),
            ),
            SizedBox(height: tussen),
          ],
        ],
        if (value.buitenStraal > 0) ...[
          SizedBox(height: tussen),
          HhMeldBalk(
            soort: HhMeldSoort.informatie,
            tekst: TekstenKlussenNl.j11BuitenStraal(value.buitenStraal, straal),
          ),
        ],
      ],
      AsyncError<GefilterdeKlussen>(:final error) => [
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenKlussenNl.j11LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: onVernieuw,
        ),
      ],
      _ => const [HhLaadStaat.skelet(regels: 3)],
    };

    // Geen lazy ListView: de lijst is in de pilot kort en zo bestaat elke
    // tegel meteen (ook voor de schermlezer die de lijst doorloopt).
    return RefreshIndicator(
      onRefresh: onVernieuw,
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
            schakelaar,
            SizedBox(height: tussen),
            const _FilterBalk(),
            SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
            ...inhoud,
          ],
        ),
      ),
    );
  }
}

/// J12: de schakelaar, de kaart met markers, en eronder de badge "n zonder
/// locatie" die naar de lijst gaat. De kaart vult de resthoogte; is die te
/// klein (200 procent tekst in de grote dichtheid), dan scrolt het geheel
/// en krijgt de kaart een vaste hoogte, zodat niets overloopt.
class _Kaart extends ConsumerWidget {
  const _Kaart({
    required this.stand,
    required this.rand,
    required this.schakelaar,
    required this.onKlus,
    required this.onNaarLijst,
    required this.onVernieuw,
  });

  final AsyncValue<GefilterdeKlussen> stand;
  final double rand;
  final Widget schakelaar;
  final ValueChanged<HhKlus> onKlus;
  final VoidCallback onNaarLijst;
  final Future<void> Function() onVernieuw;

  /// Onder deze resthoogte scrolt J12 met een vaste kaarthoogte.
  static const minimumHoogteVoorVullendeKaart = 480.0;
  static const vasteKaartHoogte = 280.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    final (kaart, badge) = switch (stand) {
      AsyncData<GefilterdeKlussen>(:final value) => (
        value.metCoordinaten.isEmpty
            ? Center(
                child: HhLegeStaat(
                  icoon: Icons.map_outlined,
                  titel: TekstenKlussenNl.j12Leeg,
                  uitleg: TekstenKlussenNl.j12LeegUitleg,
                  knopLabel: TekstenKlussenNl.weergaveLijst,
                  onKnop: onNaarLijst,
                ),
              )
            : KlussenKaart(
                klussen: value.metCoordinaten,
                middelpunt: value.middelpunt,
                tegels: ref.watch(kaartTegelsProvider)(),
                onKlus: onKlus,
              ),
        value.zonderCoordinaten.isEmpty
            ? null
            : HhKnop(
                label: TekstenKlussenNl.j12ZonderLocatie(
                  value.zonderCoordinaten.length,
                ),
                semantiekLabel: TekstenKlussenNl.j12ZonderLocatieSemantiek(
                  value.zonderCoordinaten.length,
                ),
                icoon: Icons.location_off_outlined,
                soort: HhKnopSoort.tweedeKeus,
                onPressed: onNaarLijst,
              ),
      ),
      AsyncError<GefilterdeKlussen>(:final error) => (
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenKlussenNl.j11LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: onVernieuw,
        ),
        null,
      ),
      _ => (const HhLaadStaat.skelet(regels: 3), null),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        rand,
        0,
        rand,
        HhRuimte.voor(HhRuimte.l, dichtheid),
      ),
      child: LayoutBuilder(
        builder: (context, grenzen) {
          final vult = grenzen.maxHeight >= minimumHoogteVoorVullendeKaart;
          final kinderen = [
            schakelaar,
            SizedBox(height: tussen),
            if (vult)
              Expanded(child: kaart)
            else
              SizedBox(height: vasteKaartHoogte, child: kaart),
            if (badge != null) ...[SizedBox(height: tussen), badge],
          ];
          final kolom = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: kinderen,
          );
          return vult ? kolom : SingleChildScrollView(child: kolom);
        },
      ),
    );
  }
}

/// Soort klus (meerdere, rijen van drie) en dagdeel (meerdere). De keuze
/// staat in [klusFilterProvider] en blijft staan bij navigeren.
class _FilterBalk extends ConsumerWidget {
  const _FilterBalk();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final filter = ref.watch(klusFilterProvider);
    final klustypes = ref.watch(klustypesProvider);
    final controller = ref.read(klusFilterProvider.notifier);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);

    final rijen = switch (klustypes) {
      AsyncData<List<HhKlustype>>(:final value) => _inRijen(
        value,
        KlussenHomeScreen.klustypesPerRij,
      ),
      _ => const <List<HhKlustype>>[],
    };

    return HhKaart(
      kop: TekstenKlussenNl.filterKlustype,
      actie: filter.isLeeg
          ? null
          : HhKnop(
              label: TekstenKlussenNl.filterWissen,
              soort: HhKnopSoort.tekst,
              onPressed: controller.wis,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final rij in rijen) ...[
            HhKeuzerij<String>(
              meerdere: true,
              semantiekLabel: TekstenKlussenNl.filterKlustype,
              keuzes: [
                for (final type in rij)
                  HhKeuze(
                    waarde: type.id,
                    label: metHoofdletter(type.naam),
                    icoon: KlustypeIcoon.voor(type.icoon),
                  ),
              ],
              geselecteerd: filter.klustypeIds,
              onGewijzigd: controller.zetKlustypes,
            ),
            SizedBox(height: tussen),
          ],
          SizedBox(height: tussen),
          Text(
            TekstenKlussenNl.filterDagdeel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: tussen),
          HhKeuzerij<HhDagdeel>(
            meerdere: true,
            semantiekLabel: TekstenKlussenNl.filterDagdeel,
            keuzes: [
              for (final dagdeel in HhDagdeel.values)
                HhKeuze(
                  waarde: dagdeel,
                  label: dagdeelNaam(dagdeel),
                  icoon: switch (dagdeel) {
                    HhDagdeel.ochtend => Icons.wb_twilight_outlined,
                    HhDagdeel.middag => Icons.wb_sunny_outlined,
                    HhDagdeel.avond => Icons.nights_stay_outlined,
                  },
                ),
            ],
            geselecteerd: filter.dagdelen,
            onGewijzigd: controller.zetDagdelen,
          ),
        ],
      ),
    );
  }

  static List<List<T>> _inRijen<T>(List<T> lijst, int perRij) => [
    for (var i = 0; i < lijst.length; i += perRij)
      lijst.sublist(i, i + perRij > lijst.length ? lijst.length : i + perRij),
  ];
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_familie_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/paden_hulpvrager.dart';
import '../../hulpvrager/provider/concept_controller.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../hulpvrager/status/domein/hulpvraag_indeling.dart';
import '../../hulpvrager/status/widget/hulpvraag_tegel.dart';
import '../../jongere/klussen/model/hh_klus.dart';
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../domein/familie_rechten.dart';
import '../model/hh_koppeling.dart';
import '../paden_familie.dart';
import '../provider/familie_providers.dart';
import '../provider/hulpvraag_namens.dart';

/// F3. Meekijken bij één oudere: met recht plaatsen de knop "Hulp vragen
/// voor ..." (F2, de M4-stroom namens de oudere); met recht meekijken de
/// hulpvragen in de drie lijstjes van O8 (tik opent het detail, zoals O7 maar
/// alleen-lezen). "Meldingen" is een lege plek: M8 bouwt de meldingen
/// (OPEN-PUNTEN-M9).
class FamilieOudereScreen extends ConsumerStatefulWidget {
  const FamilieOudereScreen({required this.oudereId, super.key});

  final String oudereId;

  @override
  ConsumerState<FamilieOudereScreen> createState() =>
      _FamilieOudereScreenState();
}

class _FamilieOudereScreenState extends ConsumerState<FamilieOudereScreen> {
  HulpvraagTab _tab = HulpvraagTab.gepland;

  void _terug() => context.go(HhPadenFamilie.lijst);

  void _hulpVragen(HhKoppeling koppeling) {
    // Een nieuwe hulpvraag begint leeg, net als op O1.
    ref.read(conceptProvider.notifier).wis();
    ref
        .read(hulpvraagNamensProvider.notifier)
        .zet(
          HulpvraagNamens(
            oudereId: koppeling.oudereId,
            oudereNaam: koppeling.oudereNaam,
            naPlaatsen: HhPadenFamilie.oudere(koppeling.oudereId),
          ),
        );
    context.push(HhPadenHulpvrager.hulpVragenWat);
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(koppelingMetProvider(widget.oudereId));
    final koppeling = stand.value;

    if (koppeling == null) {
      return HhScherm(
        titel: TekstenFamilieNl.f3TitelZonderNaam,
        toonTerug: true,
        onTerug: _terug,
        child: stand.isLoading
            ? const HhLaadStaat.skelet(regels: 3)
            : stand.hasError
            ? HhLegeStaat(
                icoon: Icons.cloud_off_outlined,
                titel: TekstenFamilieNl.f1LadenMislukt,
                uitleg: meldingVanFout(stand.error),
                knopLabel: TekstenNl.opnieuwProberen,
                onKnop: () => ref.invalidate(mijnKoppelingenProvider),
              )
            : HhLegeStaat(
                icoon: Icons.link_off,
                titel: TekstenFamilieNl.f3GeenToegang,
                uitleg: TekstenFamilieNl.f1Uitleg,
                knopLabel: TekstenFamilieNl.f3AndereOudere,
                onKnop: _terug,
              ),
      );
    }

    final zicht = zichtVoor(koppeling);
    final naam = koppeling.oudereNaam;
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return HhScherm(
      titel: naam.isEmpty
          ? TekstenFamilieNl.f3TitelZonderNaam
          : TekstenFamilieNl.f3Titel(naam),
      toonTerug: true,
      onTerug: _terug,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!koppeling.isActief)
            Text(TekstenFamilieNl.f3GeenToegang, style: tekst.bodyLarge),
          if (zicht.kanPlaatsen) ...[
            HhKnop(
              label: naam.isEmpty
                  ? TekstenFamilieNl.f3HulpVragenZonderNaam
                  : TekstenFamilieNl.f3HulpVragen(naam),
              icoon: Icons.add_circle_outline,
              onPressed: () => _hulpVragen(koppeling),
            ),
            SizedBox(height: tussen),
          ],
          if (zicht.kanMeekijken)
            _Hulpvragen(
              oudereId: widget.oudereId,
              tab: _tab,
              onTab: (tab) => setState(() => _tab = tab),
            )
          else if (koppeling.isActief)
            Text(TekstenFamilieNl.f3GeenMeekijken, style: tekst.bodyLarge),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenFamilieNl.f3MeldingenKop,
            child: Text(
              TekstenFamilieNl.f3MeldingenLeeg,
              style: tekst.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hulpvragen extends ConsumerWidget {
  const _Hulpvragen({
    required this.oudereId,
    required this.tab,
    required this.onTab,
  });

  final String oudereId;
  final HulpvraagTab tab;
  final ValueChanged<HulpvraagTab> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(hulpvragenVanOudereProvider(oudereId));
    final nu = ref.watch(klokProvider)();
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    final List<Widget> lijst = switch (stand) {
      AsyncData<List<HhKlus>>(:final value) => () {
        final per = deelHulpvragenIn(value)[tab]!;
        if (per.isEmpty) {
          return <Widget>[
            switch (tab) {
              HulpvraagTab.open => const HhLegeStaat(
                icoon: Icons.inbox_outlined,
                titel: TekstenUitvoerenNl.o8LeegOpen,
                uitleg: TekstenUitvoerenNl.o8LeegOpenUitleg,
              ),
              HulpvraagTab.gepland => const HhLegeStaat(
                icoon: Icons.event_outlined,
                titel: TekstenUitvoerenNl.o8LeegGepland,
                uitleg: TekstenUitvoerenNl.o8LeegGeplandUitleg,
              ),
              HulpvraagTab.afgerond => const HhLegeStaat(
                icoon: Icons.check_circle_outline,
                titel: TekstenUitvoerenNl.o8LeegAfgerond,
                uitleg: TekstenUitvoerenNl.o8LeegAfgerondUitleg,
              ),
            },
          ];
        }
        return <Widget>[
          for (final klus in per) ...[
            HulpvraagTegel(
              klus: klus,
              nu: nu,
              onTik: () =>
                  context.push(HhPadenFamilie.hulpvraag(oudereId, klus.id)),
            ),
            SizedBox(height: tussen),
          ],
        ];
      }(),
      AsyncError<List<HhKlus>>(:final error) => <Widget>[
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenFamilieNl.f3LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.invalidate(hulpvragenVanOudereProvider(oudereId)),
        ),
      ],
      _ => const <Widget>[HhLaadStaat.skelet(regels: 3)],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HhKeuzerij<HulpvraagTab>(
          semantiekLabel: TekstenFamilieNl.f3TabbladenLabel,
          keuzes: [
            for (final t in HulpvraagTab.values)
              HhKeuze(
                waarde: t,
                label: t.naam,
                icoon: switch (t) {
                  HulpvraagTab.open => Icons.inbox_outlined,
                  HulpvraagTab.gepland => Icons.event_outlined,
                  HulpvraagTab.afgerond => Icons.check_circle_outline,
                },
              ),
          ],
          geselecteerd: {tab},
          onGewijzigd: (keuze) => onTab(keuze.first),
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
        ...lijst,
      ],
    );
  }
}

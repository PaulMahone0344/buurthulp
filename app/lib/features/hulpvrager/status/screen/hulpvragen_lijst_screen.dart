import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../app/paden.dart';
import '../../../../core/hh_fout.dart';
import '../../../../design/components/hh_keuzerij.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../jongere/klussen/model/hh_klus.dart';
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../provider/hulpvrager_providers.dart' show klokProvider;
import '../domein/hulpvraag_indeling.dart';
import '../paden_status.dart';
import '../provider/status_providers.dart';
import '../widget/hulpvraag_tegel.dart';

/// O8. De hulpvragen van de oudere in drie tabbladen: Open, Gepland,
/// Afgerond. Eén rij van drie keuzes (ouderenregel), grote tegels, tikken
/// opent O7.
class HulpvragenLijstScreen extends ConsumerStatefulWidget {
  const HulpvragenLijstScreen({super.key});

  @override
  ConsumerState<HulpvragenLijstScreen> createState() =>
      _HulpvragenLijstScreenState();
}

class _HulpvragenLijstScreenState extends ConsumerState<HulpvragenLijstScreen> {
  HulpvraagTab _tab = HulpvraagTab.open;

  Future<void> _vernieuw() =>
      ref.read(mijnHulpvragenProvider.notifier).vernieuw();

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    // Zonder sessie of met een andere rol stuurt de router-guard al weg.
    if (gebruiker == null || gebruiker.rol != HhRol.hulpvrager) {
      return const Scaffold();
    }

    final stand = ref.watch(mijnHulpvragenProvider);
    final nu = ref.watch(klokProvider)();

    final inhoud = switch (stand) {
      AsyncData<List<HhKlus>>(:final value) => () {
        final per = deelHulpvragenIn(value)[_tab]!;
        if (per.isEmpty) {
          return <Widget>[
            switch (_tab) {
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
              onTik: () => context.push(HhPadenStatus.hulpvraag(klus.id)),
            ),
            SizedBox(height: tussen),
          ],
        ];
      }(),
      AsyncError<List<HhKlus>>(:final error) => <Widget>[
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenUitvoerenNl.o8LadenMislukt,
          uitleg: error is HhFout ? error.melding : TekstenNl.foutOnbekend,
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: _vernieuw,
        ),
      ],
      _ => const <Widget>[HhLaadStaat.skelet(regels: 3)],
    };

    return HhScherm(
      titel: TekstenUitvoerenNl.o8Titel,
      onTerug: () => terugOf(context, HhPaden.hulpvrager),
      scrollbaar: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rand),
            child: HhKeuzerij<HulpvraagTab>(
              semantiekLabel: TekstenUitvoerenNl.o8TabbladenLabel,
              keuzes: [
                for (final tab in HulpvraagTab.values)
                  HhKeuze(
                    waarde: tab,
                    label: tab.naam,
                    icoon: switch (tab) {
                      HulpvraagTab.open => Icons.inbox_outlined,
                      HulpvraagTab.gepland => Icons.event_outlined,
                      HulpvraagTab.afgerond => Icons.check_circle_outline,
                    },
                  ),
              ],
              geselecteerd: {_tab},
              onGewijzigd: (keuze) => setState(() => _tab = keuze.first),
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _vernieuw,
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
                  children: inhoud,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

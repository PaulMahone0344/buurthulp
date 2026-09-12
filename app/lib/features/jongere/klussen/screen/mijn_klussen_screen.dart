import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/components/hh_keuzerij.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../theme.dart';
import '../../../hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../provider/screening_providers.dart' show meldingVanFout;
import '../domein/mijn_klussen_indeling.dart';
import '../model/hh_klus.dart';
import '../paden_klussen.dart';
import '../provider/klussen_providers.dart';
import '../widget/jongere_tabbalk.dart';
import '../widget/klus_tegel.dart';

/// J14. De klussen die aan de jongere zijn toegewezen, in drie tabbladen:
/// vandaag, gepland, historie (status en wanneer_van, lokale dag). Tik op
/// een klus opent J13; uitvoeren komt in M6, hier alleen de statuspil.
class MijnKlussenScreen extends ConsumerStatefulWidget {
  const MijnKlussenScreen({super.key});

  @override
  ConsumerState<MijnKlussenScreen> createState() => _MijnKlussenScreenState();
}

class _MijnKlussenScreenState extends ConsumerState<MijnKlussenScreen> {
  MijnKlussenTab _tab = MijnKlussenTab.vandaag;

  Future<void> _vernieuw() => ref.read(mijnKlussenProvider.notifier).vernieuw();

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    if (gebruiker == null || gebruiker.rol != HhRol.jongere) {
      return const Scaffold();
    }

    final stand = ref.watch(mijnKlussenProvider);
    final nu = ref.watch(klokProvider)();

    final inhoud = switch (stand) {
      AsyncData<List<HhKlus>>(:final value) => () {
        final per = deelIn(value, nu)[_tab]!;
        if (per.isEmpty) {
          return <Widget>[
            switch (_tab) {
              MijnKlussenTab.vandaag => const HhLegeStaat(
                icoon: Icons.today_outlined,
                titel: TekstenKlussenNl.j14LeegVandaag,
                uitleg: TekstenKlussenNl.j14LeegVandaagUitleg,
              ),
              MijnKlussenTab.gepland => const HhLegeStaat(
                icoon: Icons.event_outlined,
                titel: TekstenKlussenNl.j14LeegGepland,
                uitleg: TekstenKlussenNl.j14LeegGeplandUitleg,
              ),
              MijnKlussenTab.historie => const HhLegeStaat(
                icoon: Icons.history,
                titel: TekstenKlussenNl.j14LeegHistorie,
                uitleg: TekstenKlussenNl.j14LeegHistorieUitleg,
              ),
            },
          ];
        }
        return <Widget>[
          for (final klus in per) ...[
            KlusTegel(
              klus: klus,
              nu: nu,
              toonStatus: true,
              onTik: () => context.push(HhPadenKlussen.klusDetail(klus.id)),
            ),
            SizedBox(height: tussen),
          ],
        ];
      }(),
      AsyncError<List<HhKlus>>(:final error) => <Widget>[
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenKlussenNl.j14LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: _vernieuw,
        ),
      ],
      _ => const <Widget>[HhLaadStaat.skelet(regels: 3)],
    };

    return JongereTabScherm(
      actief: JongereTab.mijnKlussen,
      child: HhScherm(
        titel: TekstenKlussenNl.j14Titel,
        toonTerug: false,
        scrollbaar: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rand),
              child: HhKeuzerij<MijnKlussenTab>(
                semantiekLabel: TekstenKlussenNl.j14TabbladenLabel,
                keuzes: [
                  for (final tab in MijnKlussenTab.values)
                    HhKeuze(
                      waarde: tab,
                      label: tab.naam,
                      icoon: switch (tab) {
                        MijnKlussenTab.vandaag => Icons.today_outlined,
                        MijnKlussenTab.gepland => Icons.event_outlined,
                        MijnKlussenTab.historie => Icons.history,
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
      ),
    );
  }
}

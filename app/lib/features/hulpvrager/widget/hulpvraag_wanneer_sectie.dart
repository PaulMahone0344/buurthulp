import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../theme.dart';
import '../domein/tijdregel.dart';
import '../domein/wanneer.dart';
import '../model/hulpvraag_concept.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// "Wanneer?" op "Klus plaatsen" (B4). Eerst de dag (vandaag, morgen, kies
/// een dag), dan een tijdwiel zoals de iPhone-wekker: "Vanaf" (verplicht)
/// en met de schakelaar "Eindtijd" ook "Tot" (optioneel). Kwartieren,
/// 24-uursklok. Valt de tijd buiten 07:00-19:00 of duurt hij langer dan 2
/// uur, dan zegt de pagina dat alleen helpers van 18+ hem kunnen doen (de
/// server beslist, punt 7).
class HulpvraagWanneerSectie extends ConsumerWidget {
  const HulpvraagWanneerSectie({super.key});

  /// Hoever vooruit de dagkiezer reikt (vandaag meegerekend).
  static const dagenVooruit = 14;

  /// Stappen van het tijdwiel (minuten).
  static const minuutStap = 15;

  static const _dagKeuzes = [
    HhKeuze(
      waarde: HhDagKeuze.vandaag,
      label: TekstenHulpvragerNl.dagVandaag,
      semantiekLabel: TekstenHulpvragerNl.dagVandaagSemantiek,
      icoon: Icons.today_outlined,
    ),
    HhKeuze(
      waarde: HhDagKeuze.morgen,
      label: TekstenHulpvragerNl.dagMorgen,
      semantiekLabel: TekstenHulpvragerNl.dagMorgenSemantiek,
      icoon: Icons.event_outlined,
    ),
    HhKeuze(
      waarde: HhDagKeuze.andereDag,
      label: TekstenHulpvragerNl.dagAndere,
      semantiekLabel: TekstenHulpvragerNl.dagAndereSemantiek,
      icoon: Icons.calendar_month_outlined,
    ),
  ];

  Future<void> _kiesDagKeuze(
    BuildContext context,
    WidgetRef ref,
    HhDagKeuze keuze,
  ) async {
    final controller = ref.read(conceptProvider.notifier);
    if (keuze != HhDagKeuze.andereDag) {
      controller.kiesDagKeuze(keuze);
      return;
    }
    final nu = ref.read(klokProvider)();
    final dag = await showDialog<DateTime>(
      context: context,
      builder: (context) => _DagKiezer(dagen: komendeDagen(nu, dagenVooruit)),
    );
    if (dag == null) return;
    controller.kiesDag(dag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concept = ref.watch(conceptProvider);
    final nu = ref.watch(klokProvider)();
    final controller = ref.read(conceptProvider.notifier);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final dag = concept.dag;
    final vanaf = concept.vanafMinuten;
    final eind = concept.eindMinuten;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HhKeuzerij<HhDagKeuze>(
          semantiekLabel: TekstenHulpvragerNl.wanneerDagKeuzerij,
          keuzes: _dagKeuzes,
          geselecteerd: {?concept.dagKeuze},
          onGewijzigd: (keuze) => _kiesDagKeuze(context, ref, keuze.first),
        ),
        if (dag != null && vanaf != null) ...[
          SizedBox(height: klein),
          Text(
            TekstenHulpvragerNl.dagGekozen(dagTekst(dag, nu)),
            style: tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: tussen),
          DecoratedBox(
            decoration: BoxDecoration(
              color: HhKleuren.oppervlak,
              borderRadius: BorderRadius.circular(HhRadius.groot),
            ),
            child: Padding(
              padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.l, dichtheid)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    value: concept.heeftEindtijd,
                    onChanged: controller.zetEindtijd,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      TekstenKlusNl.eindtijd,
                      style: tekst.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(TekstenKlusNl.eindtijdOptioneel),
                  ),
                  SizedBox(height: klein),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Tijdwiel(
                          sleutel: const ValueKey('tijdwiel-vanaf'),
                          welke: TekstenKlusNl.vanaf,
                          minuten: vanaf,
                          semantiek: TekstenKlusNl.vanafSemantiek,
                          onGekozen: controller.zetVanaf,
                        ),
                      ),
                      if (eind != null) ...[
                        SizedBox(width: tussen),
                        Expanded(
                          child: _Tijdwiel(
                            sleutel: const ValueKey('tijdwiel-tot'),
                            welke: TekstenKlusNl.tot,
                            minuten: eind,
                            semantiek: TekstenKlusNl.totSemantiek,
                            onGekozen: controller.zetTot,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isVoorbij(dag, vanaf, nu)) ...[
            SizedBox(height: klein),
            const HhMeldBalk(
              soort: HhMeldSoort.waarschuwing,
              tekst: TekstenKlusNl.ontbreektTijdVoorbij,
            ),
          ] else if (!concept.heeftGeldigeEindtijd) ...[
            SizedBox(height: klein),
            const HhMeldBalk(
              soort: HhMeldSoort.waarschuwing,
              tekst: TekstenKlusNl.ontbreektTot,
            ),
          ] else if (isAlleenVoor18Plus(vanaf: vanaf, tot: eind)) ...[
            SizedBox(height: klein),
            const HhMeldBalk(
              soort: HhMeldSoort.informatie,
              tekst: TekstenKlusNl.alleen18Plus,
            ),
          ],
        ],
      ],
    );
  }
}

/// Eén tijdwiel ("Vanaf 14:00" erboven): uren en kwartieren, 24-uursklok.
/// Het wiel zelf is voor de schermlezer één regel met de gekozen tijd.
class _Tijdwiel extends StatelessWidget {
  const _Tijdwiel({
    required this.sleutel,
    required this.welke,
    required this.minuten,
    required this.semantiek,
    required this.onGekozen,
  });

  final Key sleutel;
  final String welke;
  final int minuten;
  final String Function(String tijd) semantiek;
  final ValueChanged<int> onGekozen;

  static const _hoogte = 150.0;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final tijd = tijdTekst(minuten);
    // Het wiel kent alleen kwartieren: een andere minuut eerst afronden.
    final stap = HulpvraagWanneerSectie.minuutStap;
    final afgerond = (minuten ~/ stap) * stap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TekstenKlusNl.tijdGekozen(welke, tijd),
          style: tekst.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        Semantics(
          label: semantiek(tijd),
          child: SizedBox(
            height: _hoogte,
            child: CupertinoDatePicker(
              key: sleutel,
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              minuteInterval: stap,
              initialDateTime: DateTime(
                2000,
                1,
                1,
                afgerond ~/ 60,
                afgerond % 60,
              ),
              onDateTimeChanged: (moment) =>
                  onGekozen(moment.hour * 60 + moment.minute),
            ),
          ),
        ),
      ],
    );
  }
}

/// De eigen dagkiezer: een lijst van grote knoppen, een per dag, in
/// gewone taal ("donderdag 17 september"). Sluit met de terugknop.
class _DagKiezer extends StatelessWidget {
  const _DagKiezer({required this.dagen});

  final List<DateTime> dagen;

  @override
  Widget build(BuildContext context) {
    final klein = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));

    return Dialog.fullscreen(
      child: HhScherm(
        titel: TekstenHulpvragerNl.dagKiezerTitel,
        onTerug: () => Navigator.of(context).pop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < dagen.length; i++) ...[
              if (i > 0) SizedBox(height: klein),
              HhKnop(
                label: datumTekst(dagen[i]),
                semantiekLabel: TekstenHulpvragerNl.dagKiezerSemantiek(
                  datumTekst(dagen[i]),
                ),
                soort: HhKnopSoort.tweedeKeus,
                onPressed: () => Navigator.of(context).pop(dagen[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

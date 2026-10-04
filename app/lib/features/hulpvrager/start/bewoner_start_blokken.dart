import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_start_nl.dart';
import '../../../theme.dart';
import '../provider/hulpvrager_providers.dart' show klokProvider;
import '../status/paden_status.dart';
import '../status/provider/status_providers.dart';
import '../status/widget/hulpvraag_tegel.dart';
import 'bewoner_agenda.dart';

/// Start bewoner (B10, mockup Main): twee tegels naast elkaar ("Aankomend"
/// en "Nieuwe reacties"). Saldo komt erbij met B7. Tik = Mijn hulpvragen.
/// Laden of een fout: niets (de rest van Start blijft bruikbaar).
class BewonerTegels extends ConsumerWidget {
  const BewonerTegels({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klussen = ref.watch(mijnHulpvragenProvider).value;
    if (klussen == null) return const SizedBox.shrink();
    final nu = ref.watch(klokProvider)();
    final aankomend = aankomendeKlussen(klussen, nu).length;
    final reacties = nieuweReacties(klussen);
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);
    final groot = MediaQuery.textScalerOf(context).scale(10) > 15;

    final tegels = [
      _Tegel(
        label: TekstenStartNl.aankomendTegel,
        getal: aankomend,
        woord: TekstenStartNl.klussenWoord(aankomend),
        semantiek: TekstenStartNl.aankomendSemantiek(aankomend),
        icoon: Icons.event_outlined,
        onTik: () => context.go(HhPadenStatus.hulpvragen),
      ),
      _Tegel(
        label: TekstenStartNl.reactiesTegel,
        getal: reacties,
        woord: '',
        semantiek: TekstenStartNl.reactiesSemantiek(reacties),
        icoon: Icons.forum_outlined,
        isAccent: reacties > 0,
        onTik: () => context.go(HhPadenStatus.hulpvragen),
      ),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: HhRuimte.voor(HhRuimte.l, dichtheid)),
      child: groot
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tegels[0],
                SizedBox(height: tussen),
                tegels[1],
              ],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tegels[0]),
                  SizedBox(width: tussen),
                  Expanded(child: tegels[1]),
                ],
              ),
            ),
    );
  }
}

class _Tegel extends StatelessWidget {
  const _Tegel({
    required this.label,
    required this.getal,
    required this.woord,
    required this.semantiek,
    required this.icoon,
    required this.onTik,
    this.isAccent = false,
  });

  final String label;
  final int getal;
  final String woord;
  final String semantiek;
  final IconData icoon;
  final VoidCallback onTik;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      side: BorderSide(
        color: isAccent ? HhKleuren.accent : HhKleuren.randZacht,
        width: HhLijn.dun(context),
      ),
    );
    return Semantics(
      button: true,
      label: semantiek,
      excludeSemantics: true,
      onTap: onTik,
      child: Material(
        color: isAccent ? HhKleuren.accentZacht : HhKleuren.oppervlakZacht,
        shape: vorm,
        child: InkWell(
          customBorder: vorm,
          onTap: onTik,
          child: Padding(
            padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.m, dichtheid)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icoon, color: HhKleuren.primair),
                    SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                    Flexible(child: Text(label, style: tekst.bodyMedium)),
                  ],
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                Wrap(
                  spacing: HhRuimte.voor(HhRuimte.xs, dichtheid),
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      '$getal',
                      style: tekst.headlineSmall!.copyWith(
                        color: HhKleuren.primair,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (woord.isNotEmpty) Text(woord, style: tekst.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Aankomende klussen" (mockup Main): Dag / Week / Maand, de weekstrook
/// (ma t/m zo met een stip op dagen met een klus; tik = die dag) en de
/// klussen in de gekozen periode.
class AankomendeKlussenKaart extends ConsumerStatefulWidget {
  const AankomendeKlussenKaart({super.key});

  @override
  ConsumerState<AankomendeKlussenKaart> createState() =>
      _AankomendeKlussenKaartState();
}

class _AankomendeKlussenKaartState
    extends ConsumerState<AankomendeKlussenKaart> {
  AgendaPeriode _periode = AgendaPeriode.week;
  DateTime? _gekozen;

  @override
  Widget build(BuildContext context) {
    final klussen = ref.watch(mijnHulpvragenProvider).value;
    if (klussen == null) return const SizedBox.shrink();
    final nu = ref.watch(klokProvider)();
    final gekozen = _gekozen ?? nu;
    final aankomend = aankomendeKlussen(klussen, nu);
    final inPeriodeLijst = aankomend
        .where((k) => inPeriode(k, _periode, gekozen))
        .toList();
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    return HhKaart(
      kop: TekstenStartNl.aankomendKop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HhKeuzerij<AgendaPeriode>(
            semantiekLabel: TekstenStartNl.periodeLabel,
            keuzes: const [
              HhKeuze(
                waarde: AgendaPeriode.dag,
                label: TekstenStartNl.dag,
                icoon: Icons.today_outlined,
              ),
              HhKeuze(
                waarde: AgendaPeriode.week,
                label: TekstenStartNl.week,
                icoon: Icons.view_week_outlined,
              ),
              HhKeuze(
                waarde: AgendaPeriode.maand,
                label: TekstenStartNl.maand,
                icoon: Icons.calendar_month_outlined,
              ),
            ],
            geselecteerd: {_periode},
            onGewijzigd: (keuze) => setState(() => _periode = keuze.first),
          ),
          SizedBox(height: tussen),
          _Weekstrook(
            dagen: weekVan(nu),
            vandaag: nu,
            gekozen: _periode == AgendaPeriode.dag ? gekozen : null,
            aantal: (dag) => aantalOpDag(aankomend, dag),
            onDag: (dag) => setState(() {
              _gekozen = dag;
              _periode = AgendaPeriode.dag;
            }),
          ),
          SizedBox(height: tussen),
          if (inPeriodeLijst.isEmpty)
            Text(
              TekstenStartNl.geenAankomend,
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            for (final klus in inPeriodeLijst) ...[
              HulpvraagTegel(
                klus: klus,
                nu: nu,
                onTik: () => context.push(HhPadenStatus.hulpvraag(klus.id)),
              ),
              SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            ],
        ],
      ),
    );
  }
}

class _Weekstrook extends StatelessWidget {
  const _Weekstrook({
    required this.dagen,
    required this.vandaag,
    required this.gekozen,
    required this.aantal,
    required this.onDag,
  });

  final List<DateTime> dagen;
  final DateTime vandaag;
  final DateTime? gekozen;
  final int Function(DateTime) aantal;
  final ValueChanged<DateTime> onDag;

  bool _zelfde(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: TekstenStartNl.weekstripLabel,
      child: Row(
        children: [
          for (var i = 0; i < dagen.length; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final dag = dagen[i];
                  final n = aantal(dag);
                  final isGekozen = gekozen != null && _zelfde(dag, gekozen!);
                  final isVandaag = _zelfde(dag, vandaag);
                  final kort = TekstenStartNl.weekdagenKort[i];
                  return Semantics(
                    button: true,
                    selected: isGekozen,
                    label: TekstenStartNl.dagSemantiek('$kort ${dag.day}', n),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(HhRadius.groot),
                      onTap: () => onDag(dag),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        constraints: BoxConstraints(
                          minHeight: HhMaten.knopHoogte(dichtheid),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: HhRuimte.voor(HhRuimte.xs, dichtheid),
                        ),
                        decoration: BoxDecoration(
                          color: isGekozen
                              ? HhKleuren.primair
                              : isVandaag
                              ? HhKleuren.accentZacht
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(HhRadius.groot),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                kort,
                                style: tekst.bodySmall!.copyWith(
                                  color: isGekozen
                                      ? HhKleuren.opPrimair
                                      : HhKleuren.tekstGedempt,
                                ),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${dag.day}',
                                style: tekst.titleSmall!.copyWith(
                                  color: isGekozen
                                      ? HhKleuren.opPrimair
                                      : HhKleuren.tekst,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: HhRuimte.s,
                              child: n > 0
                                  ? Center(
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isGekozen
                                              ? HhKleuren.accent
                                              : HhKleuren.accentDonker,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

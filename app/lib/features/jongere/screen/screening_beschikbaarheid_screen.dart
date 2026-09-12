import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../theme.dart';
import '../model/hh_beschikbaarheid.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J7. Zeven dagen x drie dagdelen, als {"ma":["middag"],...} in
/// hh_profielen.beschikbaarheid.
class ScreeningBeschikbaarheidScreen extends ConsumerStatefulWidget {
  const ScreeningBeschikbaarheidScreen({super.key});

  @override
  ConsumerState<ScreeningBeschikbaarheidScreen> createState() =>
      _ScreeningBeschikbaarheidScreenState();
}

class _ScreeningBeschikbaarheidScreenState
    extends ConsumerState<ScreeningBeschikbaarheidScreen> {
  static const _dagdelen = [
    HhKeuze(
      waarde: HhDagdeel.ochtend,
      label: TekstenJongereNl.dagdeelOchtend,
      icoon: Icons.wb_twilight_outlined,
    ),
    HhKeuze(
      waarde: HhDagdeel.middag,
      label: TekstenJongereNl.dagdeelMiddag,
      icoon: Icons.wb_sunny_outlined,
    ),
    HhKeuze(
      waarde: HhDagdeel.avond,
      label: TekstenJongereNl.dagdeelAvond,
      icoon: Icons.nights_stay_outlined,
    ),
  ];

  bool _isIngevuld = false;
  bool _isBezig = false;
  HhBeschikbaarheid _keuze = const HhBeschikbaarheid.leeg();
  String? _melding;

  Future<void> _opslaan(ScreeningGegevens gegevens) async {
    if (_keuze.isLeeg) {
      setState(() => _melding = TekstenJongereNl.validatieBeschikbaarheidLeeg);
      return;
    }
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    if (gegevens.profiel?.beschikbaarheid != _keuze) {
      final result = await ref
          .read(screeningControllerProvider.notifier)
          .werkProfielBij({'beschikbaarheid': _keuze.naarJson()});
      if (!mounted) return;
      if (result case Err<void>(:final fout)) {
        setState(() {
          _isBezig = false;
          _melding = fout.melding;
        });
        return;
      }
    }
    setState(() => _isBezig = false);
    context.go(ScreeningStap.beschikbaarheid.volgendPad);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        if (!_isIngevuld) {
          _isIngevuld = true;
          _keuze =
              gegevens.profiel?.beschikbaarheid ??
              const HhBeschikbaarheid.leeg();
        }
        return ScreeningStapScherm(
          stap: ScreeningStap.beschikbaarheid,
          uitleg: TekstenJongereNl.j7Uitleg,
          isBezig: _isBezig,
          melding: _melding,
          onVerder: () => _opslaan(gegevens),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final dag in HhDag.values) ...[
                if (dag != HhDag.ma) SizedBox(height: tussen),
                Text(
                  dag.naam,
                  style: tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                HhKeuzerij<HhDagdeel>(
                  semantiekLabel: dag.naam,
                  keuzes: _dagdelen,
                  geselecteerd: _keuze.voor(dag),
                  meerdere: true,
                  onGewijzigd: _isBezig
                      ? null
                      : (dagdelen) =>
                            setState(() => _keuze = _keuze.met(dag, dagdelen)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

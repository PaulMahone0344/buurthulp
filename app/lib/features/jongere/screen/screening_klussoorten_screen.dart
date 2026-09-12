import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../hh_klustype_icoon.dart';
import '../model/hh_profiel.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J8. Klussoorten uit hh_klustypes, meerdere, als keuzerij in rijen van
/// twee (zes op een rij past niet op een smal scherm).
class ScreeningKlussoortenScreen extends ConsumerStatefulWidget {
  const ScreeningKlussoortenScreen({super.key});

  static const perRij = 2;

  @override
  ConsumerState<ScreeningKlussoortenScreen> createState() =>
      _ScreeningKlussoortenScreenState();
}

class _ScreeningKlussoortenScreenState
    extends ConsumerState<ScreeningKlussoortenScreen> {
  bool _isIngevuld = false;
  bool _isBezig = false;
  Set<String> _keuze = const {};
  String? _melding;

  Future<void> _opslaan(ScreeningGegevens gegevens) async {
    if (_keuze.isEmpty) {
      setState(() => _melding = TekstenJongereNl.validatieKlustypesLeeg);
      return;
    }
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final huidig = gegevens.profiel?.klustypeIds ?? const <String>{};
    if (huidig.length != _keuze.length || !huidig.containsAll(_keuze)) {
      final result = await ref
          .read(screeningControllerProvider.notifier)
          .werkProfielBij({'klustypes': _keuze.toList()..sort()});
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
    context.go(ScreeningStap.klussoorten.volgendPad);
  }

  List<List<HhKlustype>> _rijen(List<HhKlustype> types) => [
    for (var i = 0; i < types.length; i += ScreeningKlussoortenScreen.perRij)
      types.sublist(
        i,
        i + ScreeningKlussoortenScreen.perRij > types.length
            ? types.length
            : i + ScreeningKlussoortenScreen.perRij,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final klustypes = ref.watch(klustypesProvider);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        if (!_isIngevuld) {
          _isIngevuld = true;
          _keuze = gegevens.profiel?.klustypeIds ?? const {};
        }
        return ScreeningStapScherm(
          stap: ScreeningStap.klussoorten,
          uitleg: TekstenJongereNl.j8Uitleg,
          isBezig: _isBezig,
          melding: _melding,
          onVerder: () => _opslaan(gegevens),
          child: switch (klustypes) {
            AsyncData<List<HhKlustype>>(value: final lijst)
                when lijst.isEmpty =>
              const HhLegeStaat(
                icoon: Icons.handyman_outlined,
                titel: TekstenJongereNl.j8Titel,
                uitleg: TekstenJongereNl.j8GeenKlustypes,
              ),
            AsyncData<List<HhKlustype>>(value: final lijst) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, rij) in _rijen(lijst).indexed) ...[
                  if (i > 0) SizedBox(height: tussen),
                  HhKeuzerij<String>(
                    semantiekLabel: TekstenJongereNl.j8Titel,
                    keuzes: [
                      for (final type in rij)
                        HhKeuze(
                          waarde: type.id,
                          label: type.naam,
                          icoon: klustypeIcoon(type.icoon),
                        ),
                    ],
                    geselecteerd: _keuze,
                    meerdere: true,
                    onGewijzigd: _isBezig
                        ? null
                        : (nieuw) => setState(() => _keuze = nieuw),
                  ),
                ],
              ],
            ),
            AsyncError<List<HhKlustype>>(:final error) => HhLegeStaat(
              icoon: Icons.cloud_off_outlined,
              titel: TekstenJongereNl.ladenMislukt,
              uitleg: meldingVanFout(error),
              knopLabel: TekstenNl.opnieuwProberen,
              onKnop: () => ref.invalidate(klustypesProvider),
            ),
            _ => const HhLaadStaat.skelet(regels: 3),
          },
        );
      },
    );
  }
}

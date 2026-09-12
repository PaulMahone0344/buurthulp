import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_profiel.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J6. Wijk (hh_users.wijk, uit de actieve hh_wijken) en straal_km
/// (hh_profielen, keuzerij 1/2/5/10).
class ScreeningWerkgebiedScreen extends ConsumerStatefulWidget {
  const ScreeningWerkgebiedScreen({super.key});

  static const stralen = [1, 2, 5, 10];
  static const standaardStraal = 2;

  @override
  ConsumerState<ScreeningWerkgebiedScreen> createState() =>
      _ScreeningWerkgebiedScreenState();
}

class _ScreeningWerkgebiedScreenState
    extends ConsumerState<ScreeningWerkgebiedScreen> {
  bool _isIngevuld = false;
  bool _isBezig = false;
  String _wijkId = '';
  int _straal = ScreeningWerkgebiedScreen.standaardStraal;
  String? _melding;

  void _vulIn(ScreeningGegevens gegevens) {
    if (_isIngevuld) return;
    _isIngevuld = true;
    _wijkId = gegevens.account.wijkId;
    final straal = gegevens.profiel?.straalKm ?? 0;
    if (straal > 0) _straal = straal;
  }

  Future<void> _opslaan(ScreeningGegevens gegevens) async {
    if (_wijkId.isEmpty) {
      setState(() => _melding = TekstenJongereNl.validatieWijkVerplicht);
      return;
    }
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final controller = ref.read(screeningControllerProvider.notifier);
    if (gegevens.account.wijkId != _wijkId) {
      final result = await controller.werkAccountBij({'wijk': _wijkId});
      if (!mounted) return;
      if (result case Err<void>(:final fout)) {
        setState(() {
          _isBezig = false;
          _melding = fout.melding;
        });
        return;
      }
    }
    if (gegevens.profiel == null || gegevens.profiel!.straalKm != _straal) {
      final result = await controller.werkProfielBij({'straal_km': _straal});
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
    context.go(ScreeningStap.werkgebied.volgendPad);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final wijken = ref.watch(wijkenProvider);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        _vulIn(gegevens);
        return ScreeningStapScherm(
          stap: ScreeningStap.werkgebied,
          uitleg: TekstenJongereNl.j6Uitleg,
          isBezig: _isBezig,
          melding: _melding,
          onVerder: () => _opslaan(gegevens),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HhKaart(
                kop: TekstenJongereNl.j6WijkKop,
                child: switch (wijken) {
                  AsyncData<List<HhWijk>>(value: final lijst)
                      when lijst.isEmpty =>
                    const HhLegeStaat(
                      icoon: Icons.map_outlined,
                      titel: TekstenJongereNl.j6WijkKop,
                      uitleg: TekstenJongereNl.j6GeenWijken,
                    ),
                  AsyncData<List<HhWijk>>(value: final lijst) => WijkLijst(
                    wijken: lijst,
                    gekozenId: _wijkId,
                    onGekozen: _isBezig
                        ? null
                        : (id) => setState(() => _wijkId = id),
                  ),
                  AsyncError<List<HhWijk>>(:final error) => HhLegeStaat(
                    icoon: Icons.cloud_off_outlined,
                    titel: TekstenJongereNl.ladenMislukt,
                    uitleg: meldingVanFout(error),
                    knopLabel: TekstenNl.opnieuwProberen,
                    onKnop: () => ref.invalidate(wijkenProvider),
                  ),
                  _ => const HhLaadStaat.skelet(regels: 2),
                },
              ),
              SizedBox(height: tussen),
              HhKaart(
                kop: TekstenJongereNl.j6StraalKop,
                child: HhKeuzerij<int>(
                  semantiekLabel: TekstenJongereNl.j6StraalKop,
                  keuzes: [
                    for (final km in ScreeningWerkgebiedScreen.stralen)
                      HhKeuze(
                        waarde: km,
                        label: TekstenJongereNl.j6StraalLabel(km),
                        icoon: Icons.directions_bike_outlined,
                      ),
                  ],
                  geselecteerd: {_straal},
                  onGewijzigd: _isBezig
                      ? null
                      : (keuze) => setState(() => _straal = keuze.first),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Verticale keuzelijst van wijken (een keuzerij past niet bij meer dan een
/// paar wijken). Zelfde vorm en semantiek als een keuzeknop: gekozen heeft
/// een dikke primaire rand en een gevuld vlak.
class WijkLijst extends StatelessWidget {
  const WijkLijst({
    required this.wijken,
    required this.gekozenId,
    required this.onGekozen,
    super.key,
  });

  final List<HhWijk> wijken;
  final String gekozenId;
  final ValueChanged<String>? onGekozen;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < wijken.length; i++) ...[
          if (i > 0) SizedBox(height: tussen),
          Builder(
            builder: (context) {
              final wijk = wijken[i];
              final isGekozen = wijk.id == gekozenId;
              final kleur = isGekozen ? schema.primary : schema.onSurface;
              final vorm = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HhRadius.klein),
                side: BorderSide(
                  color: isGekozen ? schema.primary : schema.outline,
                  width: isGekozen ? HhLijn.dik(context) : HhLijn.dun(context),
                ),
              );
              final actie = onGekozen == null
                  ? null
                  : () => onGekozen!(wijk.id);
              return Semantics(
                button: true,
                enabled: actie != null,
                checked: isGekozen,
                inMutuallyExclusiveGroup: true,
                label: '${wijk.wijk}, ${wijk.gemeente}',
                onTap: actie,
                excludeSemantics: true,
                child: Material(
                  color: isGekozen ? HhKleuren.oppervlak : schema.surface,
                  shape: vorm,
                  child: InkWell(
                    onTap: actie,
                    customBorder: vorm,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: HhMaten.knopHoogte(dichtheid),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: HhRuimte.voor(HhRuimte.m, dichtheid),
                          horizontal: HhRuimte.voor(HhRuimte.l, dichtheid),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isGekozen
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: HhMaten.icoonKeuzerij(dichtheid),
                              color: kleur,
                            ),
                            SizedBox(
                              width: HhRuimte.voor(HhRuimte.m, dichtheid),
                            ),
                            Expanded(
                              child: Text(
                                wijk.wijk,
                                style: tekst.bodyLarge!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: kleur,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

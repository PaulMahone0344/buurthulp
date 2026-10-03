import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../core/config.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../toegang/screen/hulp_screen.dart' show urlOpenerProvider;
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../toegang/widget/aanmeld_stappen.dart';
import '../model/hh_screening_status.dart';
import '../model/screening_stap.dart';
import '../paden_jongere.dart';
import '../provider/screening_providers.dart';
import '../widget/hh_screening_pil.dart';
import '../widget/screening_lader.dart';

/// J9 "Je aanmelding" (B2). Na het aanmeldformulier: de stappen "Jij -
/// Ouder - Klaar", de status als pil, per stap af of open (ID-foto, VOG bij
/// 18+, over mij) en de knop "Aanmelding versturen" (nieuw ->
/// in_behandeling), actief zodra de ID-foto er staat. Daarna "Aanmelding
/// binnen" (H6b). Bij afgewezen een beltekst; anders de weg naar Start.
class ScreeningOverzichtScreen extends ConsumerStatefulWidget {
  const ScreeningOverzichtScreen({super.key});

  @override
  ConsumerState<ScreeningOverzichtScreen> createState() =>
      _ScreeningOverzichtScreenState();
}

class _ScreeningOverzichtScreenState
    extends ConsumerState<ScreeningOverzichtScreen> {
  bool _isBezig = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  Future<void> _indienen() async {
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref
        .read(screeningControllerProvider.notifier)
        .terControleAanbieden();
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenJongereNl.j9Ingediend;
        case Err<void>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
    if (result is Ok<void>) context.go(HhPadenJongere.binnen);
  }

  Future<void> _bel() async {
    setState(() => _melding = null);
    final uri = Uri(scheme: 'tel', path: HhConfig.meldkamerTelefoon);
    var gelukt = false;
    try {
      gelukt = await ref.read(urlOpenerProvider)(uri);
    } on Exception {
      gelukt = false;
    }
    if (!mounted || gelukt) return;
    setState(() {
      _meldSoort = HhMeldSoort.waarschuwing;
      _melding = TekstenNl.hulpBellenLuktNiet(HhConfig.meldkamerTelefoon);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        final status = gegevens.verificatiestatus;
        final isGoedgekeurd = status == HhScreeningStatus.goedgekeurd;
        final nu = ref.watch(klokProvider)();
        final stappen = ScreeningStap.voor(gegevens, nu);
        return HhScherm(
          titel: TekstenJongereNl.j9Titel,
          toonTerug: isGoedgekeurd,
          onTerug: isGoedgekeurd ? () => context.go(HhPaden.jongere) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AanmeldStappen(
                huidig: AanmeldStap.jij,
                metOuder: gegevens.isMinderjarigOp(nu) ?? false,
              ),
              SizedBox(height: tussen),
              HhKaart(
                kop: TekstenJongereNl.j9StatusKop,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusRij(
                      label: TekstenJongereNl.j9VerificatieLabel,
                      status: status,
                    ),
                    SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
                    Text(switch (status) {
                      HhScreeningStatus.nieuw =>
                        stappen.contains(ScreeningStap.vog)
                            ? TekstenAanmeldenNl.overzichtUitlegVog
                            : TekstenAanmeldenNl.overzichtUitleg,
                      HhScreeningStatus.inBehandeling =>
                        TekstenJongereNl.j9WachtTekst,
                      HhScreeningStatus.goedgekeurd =>
                        TekstenJongereNl.j9GoedgekeurdTekst,
                      HhScreeningStatus.afgewezen =>
                        TekstenJongereNl.j9AfgewezenTekst,
                    }, style: tekst.bodyLarge),
                    if (status == HhScreeningStatus.afgewezen) ...[
                      SizedBox(height: tussen),
                      HhKnop(
                        label: TekstenJongereNl.j9BelOns,
                        icoon: Icons.phone_outlined,
                        semantiekLabel:
                            '${TekstenJongereNl.j9BelOns}, '
                            '${HhConfig.meldkamerTelefoon}',
                        onPressed: _bel,
                      ),
                    ],
                    if (isGoedgekeurd ||
                        status == HhScreeningStatus.inBehandeling) ...[
                      SizedBox(height: tussen),
                      HhKnop(
                        label: TekstenAanmeldenNl.naarStart,
                        icoon: Icons.arrow_forward,
                        onPressed: () => context.go(HhPaden.jongere),
                      ),
                    ],
                    if (!isGoedgekeurd) ...[
                      SizedBox(height: klein),
                      HhKnop(
                        label: TekstenJongereNl.j9Vernieuwen,
                        icoon: Icons.refresh,
                        soort: HhKnopSoort.tekst,
                        onPressed: _isBezig
                            ? null
                            : () => ref
                                  .read(screeningControllerProvider.notifier)
                                  .vernieuw(),
                      ),
                    ],
                  ],
                ),
              ),
              if (_melding != null) ...[
                SizedBox(height: tussen),
                HhMeldBalk(soort: _meldSoort, tekst: _melding!),
              ],
              SizedBox(height: tussen),
              HhKaart(
                kop: TekstenJongereNl.j9StappenKop,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final stap in stappen) ...[
                      if (stap != stappen.first) SizedBox(height: klein),
                      _StapKnop(
                        stap: stap,
                        isAf: stap.isAf(gegevens),
                        onPressed: _isBezig
                            ? null
                            : () => context.push(stap.pad),
                      ),
                    ],
                  ],
                ),
              ),
              if (status == HhScreeningStatus.nieuw) ...[
                SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
                Text(
                  TekstenAanmeldenNl.overzichtVersturenHulp,
                  style: tekst.bodyMedium,
                ),
                SizedBox(height: klein),
                HhKnop(
                  label: TekstenAanmeldenNl.overzichtVersturen,
                  icoon: Icons.send_outlined,
                  isBezig: _isBezig,
                  onPressed: kanTerControleAanbieden(gegevens)
                      ? _indienen
                      : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusRij extends StatelessWidget {
  const _StatusRij({required this.label, required this.status});

  final String label;
  final HhScreeningStatus status;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: HhRuimte.voor(HhRuimte.s, dichtheid),
      runSpacing: HhRuimte.voor(HhRuimte.xs, dichtheid),
      children: [
        ExcludeSemantics(child: Text(label, style: tekst.bodyLarge)),
        HhScreeningPil(status: status, label: label),
      ],
    );
  }
}

/// Een stap in de lijst: nummer, titel en af/open, als knop naar de stap.
class _StapKnop extends StatelessWidget {
  const _StapKnop({
    required this.stap,
    required this.isAf,
    required this.onPressed,
  });

  final ScreeningStap stap;
  final bool isAf;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = stap.titel;
    final staat = isAf ? TekstenJongereNl.stapAf : TekstenJongereNl.stapOpen;
    return HhKnop(
      label: label,
      icoon: isAf ? Icons.check_circle : Icons.radio_button_unchecked,
      soort: HhKnopSoort.tweedeKeus,
      semantiekLabel: '$label, $staat',
      onPressed: onPressed,
    );
  }
}

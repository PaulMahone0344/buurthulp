import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigatie.dart';
import '../../../../core/pb/xp_gateway.dart';
import '../../../../core/result.dart';
import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../../../toegang/screen/hulp_screen.dart' show urlOpenerProvider;
import '../../klussen/paden_klussen.dart';
import '../domein/xp_tekst.dart';
import '../model/hh_xp.dart';
import '../provider/xp_providers.dart';

/// "Verklaring van inzet" (B9, punt 19): de server maakt een snapshot met een
/// controlecode. De helper laat hem zien of opent de pagina op de website om
/// te printen of te delen (werkt pas als de site online is).
class VerklaringScreen extends ConsumerStatefulWidget {
  const VerklaringScreen({super.key});

  @override
  ConsumerState<VerklaringScreen> createState() => _VerklaringScreenState();
}

class _VerklaringScreenState extends ConsumerState<VerklaringScreen> {
  Result<HhVerklaring>? _uitkomst;
  bool _openMislukt = false;

  @override
  void initState() {
    super.initState();
    _laad();
  }

  Future<void> _laad() async {
    setState(() => _uitkomst = null);
    final uitkomst = await ref.read(maakVerklaringProvider)();
    if (!mounted) return;
    setState(() => _uitkomst = uitkomst);
  }

  Future<void> _open(String code) async {
    final gelukt = await ref.read(urlOpenerProvider)(verklaringWebUrl(code));
    if (!mounted) return;
    setState(() => _openMislukt = !gelukt);
  }

  @override
  Widget build(BuildContext context) {
    final uitkomst = _uitkomst;
    final Widget inhoud = switch (uitkomst) {
      null => const HhLaadStaat.skelet(regels: 5),
      Err<HhVerklaring>(:final fout) => HhLegeStaat(
        icoon: Icons.cloud_off_outlined,
        titel: TekstenXpNl.verklaringMislukt,
        uitleg: fout.melding,
        knopLabel: TekstenNl.opnieuwProberen,
        onKnop: _laad,
      ),
      Ok<HhVerklaring>(:final waarde) => _Verklaring(
        verklaring: waarde,
        openMislukt: _openMislukt,
        onOpen: () => _open(waarde.code),
      ),
    };
    return HhScherm(
      titel: TekstenXpNl.verklaringTitel,
      onTerug: () => terugOf(context, HhPadenKlussen.profiel),
      child: inhoud,
    );
  }
}

class _Verklaring extends StatelessWidget {
  const _Verklaring({
    required this.verklaring,
    required this.openMislukt,
    required this.onOpen,
  });

  final HhVerklaring verklaring;
  final bool openMislukt;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final v = verklaring;
    String dag(String iso) => datumTekst(DateTime.tryParse(iso));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(TekstenXpNl.verklaringUitleg, style: tekst.bodyLarge),
        SizedBox(height: tussen),
        HhKaart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                TekstenXpNl.verklaringZin(v.voornaam, v.klussen),
                style: tekst.titleMedium,
              ),
              if (v.periodeVan.isNotEmpty) ...[
                SizedBox(height: klein),
                Text(
                  TekstenXpNl.periode(dag(v.periodeVan), dag(v.periodeTot)),
                  style: tekst.bodyLarge,
                ),
              ],
              if (v.uren > 0)
                Text(
                  TekstenXpNl.uren(urenTekst(v.uren)),
                  style: tekst.bodyLarge,
                ),
              if (v.niveau.isNotEmpty)
                Text(TekstenXpNl.niveauRegel(v.niveau), style: tekst.bodyLarge),
              for (final (naam, datum) in [...v.badges, ...v.vertrouwen]) ...[
                SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                Text('· $naam (${dag(datum)})', style: tekst.bodyMedium),
              ],
            ],
          ),
        ),
        SizedBox(height: tussen),
        HhKaart(
          kop: TekstenXpNl.controlecodeKop,
          child: SelectableText(
            v.code,
            style: tekst.headlineSmall!.copyWith(
              fontFamily: HhTekst.monoFamilie,
              letterSpacing: 2,
              color: HhKleuren.primair,
            ),
          ),
        ),
        SizedBox(height: tussen),
        HhKnop(
          label: TekstenXpNl.openOpWebsite,
          icoon: Icons.open_in_new_rounded,
          onPressed: onOpen,
        ),
        if (openMislukt) ...[
          SizedBox(height: klein),
          const HhMeldBalk(
            tekst: TekstenXpNl.openMislukt,
            soort: HhMeldSoort.fout,
          ),
        ],
      ],
    );
  }
}

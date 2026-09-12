import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../toegang/screen/hulp_screen.dart' show urlOpenerProvider;
import '../datum_invoer.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';
import '../widget/hh_screening_pil.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J4. Uitleg, "VOG aanvragen" opent Justis, "Ik heb aangevraagd" zet
/// hh_profielen.vog_aangevraagd_op op nu. vog_status is van de meldkamer en
/// wordt alleen getoond.
class ScreeningVogScreen extends ConsumerStatefulWidget {
  const ScreeningVogScreen({super.key});

  static final aanvraagUrl = Uri.parse(
    'https://www.justis.nl/producten/verklaring-omtrent-het-gedrag-vog',
  );

  @override
  ConsumerState<ScreeningVogScreen> createState() => _ScreeningVogScreenState();
}

class _ScreeningVogScreenState extends ConsumerState<ScreeningVogScreen> {
  bool _isBezig = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  Future<void> _openAanvraag() async {
    setState(() => _melding = null);
    var gelukt = false;
    try {
      gelukt = await ref.read(urlOpenerProvider)(
        ScreeningVogScreen.aanvraagUrl,
      );
    } on Exception {
      gelukt = false;
    }
    if (!mounted || gelukt) return;
    setState(() {
      _meldSoort = HhMeldSoort.waarschuwing;
      _melding = TekstenJongereNl.j4AanvragenLuktNiet;
    });
  }

  Future<void> _hebAangevraagd() async {
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref
        .read(screeningControllerProvider.notifier)
        .werkProfielBij({
          'vog_aangevraagd_op': datumVoorServer(DateTime.now()),
        });
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenJongereNl.opgeslagen;
        case Err<void>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        final aangevraagdOp = gegevens.profiel?.vogAangevraagdOp;
        return ScreeningStapScherm(
          stap: ScreeningStap.vog,
          uitleg: TekstenJongereNl.j4Uitleg,
          melding: _melding,
          meldSoort: _meldSoort,
          knopLabel: TekstenNl.verder,
          onVerder: () => context.go(ScreeningStap.vog.volgendPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HhKaart(
                kop: TekstenJongereNl.j4StatusKop,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HhScreeningPil(
                      status: gegevens.vogStatus,
                      label: TekstenJongereNl.j9VogLabel,
                    ),
                    if (aangevraagdOp != null) ...[
                      SizedBox(height: tussen),
                      Text(
                        TekstenJongereNl.j4AangevraagdOp(
                          toonDatumNl(aangevraagdOp.toLocal()),
                        ),
                        style: tekst.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
              HhKnop(
                label: TekstenJongereNl.j4Aanvragen,
                icoon: Icons.open_in_new,
                soort: HhKnopSoort.tweedeKeus,
                onPressed: _openAanvraag,
              ),
              if (aangevraagdOp == null) ...[
                SizedBox(height: tussen),
                HhKnop(
                  label: TekstenJongereNl.j4HebAangevraagd,
                  icoon: Icons.check,
                  soort: HhKnopSoort.tweedeKeus,
                  isBezig: _isBezig,
                  onPressed: _hebAangevraagd,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../theme.dart';
import '../iban_validatie.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J5. IBAN met NL-validatie (mod-97), opgeslagen in hh_profielen.iban.
/// iban_geverifieerd blijft van de server en wordt alleen getoond.
class ScreeningIbanScreen extends ConsumerStatefulWidget {
  const ScreeningIbanScreen({super.key});

  @override
  ConsumerState<ScreeningIbanScreen> createState() =>
      _ScreeningIbanScreenState();
}

class _ScreeningIbanScreenState extends ConsumerState<ScreeningIbanScreen> {
  final _iban = TextEditingController();
  bool _isIngevuld = false;
  bool _isBezig = false;
  String? _ibanFout;
  String? _melding;

  @override
  void dispose() {
    _iban.dispose();
    super.dispose();
  }

  Future<void> _opslaan(ScreeningGegevens gegevens) async {
    final fout = valideerIban(_iban.text);
    setState(() {
      _ibanFout = fout;
      _melding = null;
    });
    if (fout != null) return;
    final iban = normaliseerIban(_iban.text);

    if (gegevens.profiel?.iban != iban) {
      setState(() => _isBezig = true);
      final result = await ref
          .read(screeningControllerProvider.notifier)
          .werkProfielBij({'iban': iban});
      if (!mounted) return;
      if (result case Err<void>(:final fout)) {
        setState(() {
          _isBezig = false;
          _melding = fout.melding;
        });
        return;
      }
      setState(() => _isBezig = false);
    }
    if (!mounted) return;
    context.go(ScreeningStap.iban.volgendPad);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);

    return ScreeningLader(
      builder: (context, gegevens) {
        if (!_isIngevuld) {
          _isIngevuld = true;
          _iban.text = toonIban(gegevens.profiel?.iban ?? '');
        }
        final isGeverifieerd = gegevens.profiel?.isIbanGeverifieerd ?? false;
        return ScreeningStapScherm(
          stap: ScreeningStap.iban,
          uitleg: TekstenJongereNl.j5Uitleg,
          isBezig: _isBezig,
          melding: _melding,
          onVerder: () => _opslaan(gegevens),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HhInvoer(
                label: TekstenJongereNl.j5Iban,
                controller: _iban,
                hulptekst: TekstenJongereNl.j5IbanHulp,
                fouttekst: _ibanFout,
                isVerplicht: true,
                isActief: !_isBezig,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.creditCardNumber],
                onSubmitted: (_) => _opslaan(gegevens),
              ),
              if (gegevens.profiel?.iban.isNotEmpty ?? false) ...[
                SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
                HhMeldBalk(
                  soort: isGeverifieerd
                      ? HhMeldSoort.geslaagd
                      : HhMeldSoort.informatie,
                  tekst: isGeverifieerd
                      ? TekstenJongereNl.j5Geverifieerd
                      : TekstenJongereNl.j5NogNietGeverifieerd,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

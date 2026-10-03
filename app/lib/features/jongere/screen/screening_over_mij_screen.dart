import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../model/screening_stap.dart';
import '../paden_jongere.dart';
import '../provider/screening_providers.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// "Over mij" (hh_profielen.over_mij): een paar zinnen voor bewoners die
/// een helper kiezen. Mag leeg blijven; geen verplichte stap meer (B2).
class ScreeningOverMijScreen extends ConsumerStatefulWidget {
  const ScreeningOverMijScreen({super.key});

  static const maxTekens = 500;

  @override
  ConsumerState<ScreeningOverMijScreen> createState() =>
      _ScreeningOverMijScreenState();
}

class _ScreeningOverMijScreenState
    extends ConsumerState<ScreeningOverMijScreen> {
  final _overMij = TextEditingController();
  bool _isIngevuld = false;
  bool _isBezig = false;
  String? _fout;
  String? _melding;

  @override
  void dispose() {
    _overMij.dispose();
    super.dispose();
  }

  void _vulIn(ScreeningGegevens gegevens) {
    if (_isIngevuld) return;
    _isIngevuld = true;
    _overMij.text = gegevens.profiel?.overMij ?? '';
  }

  Future<void> _opslaan(ScreeningGegevens gegevens) async {
    final tekst = _overMij.text.trim();
    if (tekst.length > ScreeningOverMijScreen.maxTekens) {
      setState(() => _fout = TekstenAanmeldenNl.validatieOverMijTeLang);
      return;
    }
    setState(() {
      _fout = null;
      _melding = null;
    });
    if (tekst == (gegevens.profiel?.overMij ?? '')) {
      context.go(HhPadenJongere.overzicht);
      return;
    }
    setState(() => _isBezig = true);
    final result = await ref
        .read(screeningControllerProvider.notifier)
        .werkProfielBij({'over_mij': tekst});
    if (!mounted) return;
    setState(() => _isBezig = false);
    switch (result) {
      case Ok<void>():
        context.go(HhPadenJongere.overzicht);
      case Err<void>(:final fout):
        setState(() => _melding = fout.melding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreeningLader(
      builder: (context, gegevens) {
        _vulIn(gegevens);
        return ScreeningStapScherm(
          stap: ScreeningStap.overMij,
          gegevens: gegevens,
          uitleg: TekstenAanmeldenNl.overMijUitleg,
          isBezig: _isBezig,
          melding: _melding,
          knopLabel: TekstenAanmeldenNl.opslaan,
          onVerder: () => _opslaan(gegevens),
          child: HhInvoer(
            label: TekstenAanmeldenNl.overMijTitel,
            controller: _overMij,
            hulptekst: TekstenAanmeldenNl.overMijHulp,
            fouttekst: _fout,
            isActief: !_isBezig,
            maxRegels: 6,
          ),
        );
      },
    );
  }
}

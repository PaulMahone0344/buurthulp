import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pb/uitvoer_gateway.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../toegang/screen/hulp_screen.dart' show urlOpenerProvider;
import '../provider/uitvoeren_providers.dart';

/// J16 — bellen via de app. Geen eigen scherm: één knop die het nummer bij
/// de server ophaalt en meteen de kiezer opent. Het nummer komt NOOIT als
/// tekst op het scherm; de gebruiker ziet alleen "Je belt Mevrouw de Vries."
///
/// Echt afschermen (een tussennummer van een telefoniedienst) is voor de
/// pilot bewust niet gebouwd; zie OPEN-PUNTEN-M6.
class BelKnop extends ConsumerStatefulWidget {
  const BelKnop({
    required this.klusId,
    required this.label,
    required this.onMelding,
    this.semantiekLabel,
    this.soort = HhKnopSoort.tweedeKeus,
    super.key,
  });

  final String klusId;
  final String label;

  /// Waar de melding ("Je belt ...", of waarom het niet lukt) heen gaat.
  final void Function(String tekst, HhMeldSoort soort) onMelding;

  final String? semantiekLabel;
  final HhKnopSoort soort;

  @override
  ConsumerState<BelKnop> createState() => _BelKnopState();
}

class _BelKnopState extends ConsumerState<BelKnop> {
  bool _isBezig = false;

  Future<void> _bel() async {
    setState(() => _isBezig = true);
    final uitkomst = await ref.read(belNummerProvider)(widget.klusId);
    if (!mounted) return;
    setState(() => _isBezig = false);

    switch (uitkomst) {
      case BelNummer(:final nummer, :final naam):
        widget.onMelding(
          TekstenUitvoerenNl.belBevestiging(naam),
          HhMeldSoort.informatie,
        );
        await _openKiezer(nummer);
      case BelGeweigerd(:final reden, :final melding):
        widget.onMelding(
          melding ??
              switch (reden) {
                UitvoerReden.geenNummer => TekstenUitvoerenNl.belGeenNummer,
                UitvoerReden.nietMeerMogelijk => TekstenUitvoerenNl.belNogNiet,
                _ => TekstenUitvoerenNl.belGeenNummer,
              },
          HhMeldSoort.waarschuwing,
        );
      case BelFout(:final fout):
        widget.onMelding(fout.melding, HhMeldSoort.fout);
    }
  }

  Future<void> _openKiezer(String nummer) async {
    final uri = Uri(scheme: 'tel', path: nummer);
    var gelukt = false;
    try {
      gelukt = await ref.read(urlOpenerProvider)(uri);
    } on Exception {
      gelukt = false;
    }
    if (!mounted || gelukt) return;
    // Het nummer blijft onzichtbaar, ook als bellen niet lukt.
    widget.onMelding(TekstenUitvoerenNl.belLuktNiet, HhMeldSoort.waarschuwing);
  }

  @override
  Widget build(BuildContext context) {
    return HhKnop(
      label: widget.label,
      semantiekLabel: widget.semantiekLabel,
      icoon: Icons.phone_outlined,
      soort: widget.soort,
      isBezig: _isBezig,
      onPressed: _bel,
    );
  }
}

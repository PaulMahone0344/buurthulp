import 'package:flutter/material.dart';

import '../../../design/components/hh_scherm.dart' show HhTerugKnop;
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_chat_nl.dart';
import '../../../theme.dart';

/// Vanaf deze tekstschaal staan terug en vlag boven de naam in plaats van
/// ernaast (M12: bij 200% tekst op 320 breed past één rij niet).
const _gestapeldVanaf = 1.3;

/// De groene bovenbalk van de chat (mockup Chat.dc.html): terug, de
/// voornaam van de ander met de klus eronder, en rechts de meldknop (vlag)
/// die het bestaande meldpad (O11) opent. Daaronder de smalle infobalk "Je
/// telefoonnummer blijft verborgen".
class ChatKop extends StatelessWidget {
  const ChatKop({
    required this.naam,
    required this.ondertitel,
    required this.onTerug,
    this.onMeld,
    this.onVerwijder,
    super.key,
  });

  final String naam;
  final String ondertitel;
  final VoidCallback onTerug;

  /// Leeg: geen meldknop (zolang de klus niet geladen is).
  final VoidCallback? onMeld;

  /// "Gesprek verwijderen" (integratie). Leeg: geen knop.
  final VoidCallback? onVerwijder;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final ruimte = HhRuimte.voor(HhRuimte.s, dichtheid);
    final isGestapeld =
        MediaQuery.textScalerOf(context).scale(1) >= _gestapeldVanaf;

    final terug = HhTerugKnop(onTerug: onTerug, kleur: HhKleuren.opPrimair);
    final vlag = _Vlag(onMeld: onMeld);
    final titel = _Titel(
      naam: naam,
      ondertitel: ondertitel,
      regels: isGestapeld ? 1 : 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: HhKleuren.primair,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(ruimte),
              child: isGestapeld
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: terug),
                            vlag,
                          ],
                        ),
                        titel,
                      ],
                    )
                  : Row(
                      children: [
                        Flexible(flex: 2, child: terug),
                        Expanded(flex: 3, child: titel),
                        Flexible(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: vlag,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        _InfoBalk(ruimte: ruimte, onVerwijder: onVerwijder),
      ],
    );
  }
}

class _Titel extends StatelessWidget {
  const _Titel({
    required this.naam,
    required this.ondertitel,
    required this.regels,
  });

  final String naam;
  final String ondertitel;

  /// Hoeveel regels de ondertitel mag (1 bij grote tekst).
  final int regels;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            naam.isEmpty ? TekstenChatNl.titelZonderNaam : naam,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tekst.titleLarge?.copyWith(color: HhKleuren.opPrimair),
          ),
          if (ondertitel.isNotEmpty)
            Text(
              ondertitel,
              textAlign: TextAlign.center,
              maxLines: regels,
              overflow: TextOverflow.ellipsis,
              style: tekst.bodySmall?.copyWith(color: HhKleuren.randZacht),
            ),
        ],
      ),
    );
  }
}

class _Vlag extends StatelessWidget {
  const _Vlag({required this.onMeld});

  final VoidCallback? onMeld;

  @override
  Widget build(BuildContext context) {
    final knop = HhMaten.knopHoogte(HhDichtheidScope.van(context));
    final meld = onMeld;
    if (meld == null) return SizedBox(width: knop, height: knop);
    return IconButton(
      onPressed: meld,
      tooltip: TekstenChatNl.meldProbleem,
      constraints: BoxConstraints.tightFor(width: knop, height: knop),
      style: IconButton.styleFrom(
        backgroundColor: HhKleuren.opPrimair.withValues(alpha: 0.12),
        foregroundColor: HhKleuren.opPrimair,
      ),
      icon: const Icon(Icons.outlined_flag),
    );
  }
}

class _InfoBalk extends StatelessWidget {
  const _InfoBalk({required this.ruimte, this.onVerwijder});

  final double ruimte;
  final VoidCallback? onVerwijder;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: HhKleuren.oppervlak,
        border: Border(bottom: BorderSide(color: HhKleuren.rand)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ruimte * 2, vertical: ruimte),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ruimte,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 16,
                color: HhKleuren.primair,
              ),
              SizedBox(width: ruimte),
              Flexible(
                child: Text(
                  TekstenChatNl.verborgen,
                  style: tekst.bodySmall?.copyWith(
                    color: HhKleuren.tekstGedempt,
                  ),
                ),
              ),
            ],
          ),
          if (onVerwijder != null)
            TextButton.icon(
              onPressed: onVerwijder,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text(TekstenChatNl.gesprekVerwijderen),
            ),
        ],
      ),
    );
  }
}

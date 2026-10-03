import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../theme.dart';

/// "Herhalen" (B4): alleen de knoppen. Eenmalig staat aan; wekelijks,
/// tweewekelijks en maandelijks zijn zichtbaar met een slotje en "Plus",
/// maar uitgeschakeld. Herhalen zelf (en Plus) komt in B7.
class KlusHerhalenSectie extends StatelessWidget {
  const KlusHerhalenSectie({super.key});

  /// Vanaf deze tekstschaal staan de keuzes onder elkaar.
  static const _grootVanaf = 1.3;

  static const _metPlus = [
    TekstenKlusNl.wekelijks,
    TekstenKlusNl.tweewekelijks,
    TekstenKlusNl.maandelijks,
  ];

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);
    final tekst = Theme.of(context).textTheme;
    final knoppen = <Widget>[
      const _Pil(label: TekstenKlusNl.eenmalig, isGekozen: true),
      for (final keuze in _metPlus) _Pil(label: keuze, isGekozen: false),
    ];

    // Twee naast elkaar (mockup); bij grote tekst één per regel.
    final perRegel = MediaQuery.textScalerOf(context).scale(1) > _grootVanaf
        ? 1
        : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < knoppen.length; i += perRegel) ...[
          if (i > 0) SizedBox(height: tussen),
          Row(
            children: [
              Expanded(child: knoppen[i]),
              if (perRegel == 2) ...[
                SizedBox(width: tussen),
                Expanded(child: knoppen[i + 1]),
              ],
            ],
          ),
        ],
        SizedBox(height: tussen),
        Text(TekstenKlusNl.herhalenUitleg, style: tekst.bodyMedium),
      ],
    );
  }
}

/// Eén keuze. [isGekozen] = Eenmalig (gekozen, niet te wijzigen); de rest
/// is op slot tot Plus er is.
class _Pil extends StatelessWidget {
  const _Pil({required this.label, required this.isGekozen});

  final String label;
  final bool isGekozen;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final kleur = isGekozen ? HhKleuren.opPrimair : HhKleuren.tekstGedempt;

    return Semantics(
      button: true,
      enabled: false,
      selected: isGekozen,
      label: isGekozen ? label : TekstenKlusNl.herhalenSlotSemantiek(label),
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: HhMaten.knopHoogte(dichtheid)),
        padding: EdgeInsets.symmetric(
          horizontal: HhRuimte.voor(HhRuimte.s, dichtheid),
        ),
        decoration: BoxDecoration(
          color: isGekozen ? HhKleuren.primair : HhKleuren.oppervlak,
          borderRadius: BorderRadius.circular(HhRadius.rond),
          border: isGekozen
              ? null
              : Border.all(color: HhKleuren.rand, width: HhLijn.dun(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isGekozen) ...[
              Icon(Icons.lock_outline, size: 16, color: kleur),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: tekst.bodyMedium?.copyWith(
                  color: kleur,
                  fontWeight: isGekozen ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (!isGekozen) ...[
              const SizedBox(width: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: HhKleuren.accent,
                  borderRadius: BorderRadius.circular(HhRadius.groot),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    TekstenKlusNl.plus,
                    style: tekst.labelSmall?.copyWith(
                      color: HhKleuren.tekst,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

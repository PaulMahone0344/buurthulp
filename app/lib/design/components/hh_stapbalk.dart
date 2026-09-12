import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';

/// "Stap 2 van 4" met een balk per stap. Het getal staat in woorden in de
/// regel erboven, niet als percentage; de balk is er voor het oog, de
/// schermlezer hoort alleen de zin.
class HhStapbalk extends StatelessWidget {
  const HhStapbalk({
    required this.stap,
    required this.totaal,
    this.titel,
    super.key,
  }) : assert(totaal > 0, 'totaal moet minstens 1 zijn'),
       assert(stap >= 1 && stap <= totaal, 'stap valt buiten 1..totaal');

  final int stap;
  final int totaal;

  /// Waar deze stap over gaat, bijvoorbeeld "Wat voor hulp".
  final String? titel;

  String get zin => 'Stap $stap van $totaal';

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final tussenruimte = HhRuimte.voor(HhRuimte.s, dichtheid);
    final balkHoogte = HhRuimte.voor(HhRuimte.xs, dichtheid);

    return Semantics(
      container: true,
      label: titel == null ? zin : '$zin, $titel',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tussenruimte,
            children: [
              Text(
                zin,
                style: tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
              ),
              if (titel != null) Text(titel!, style: tekst.bodyMedium),
            ],
          ),
          SizedBox(height: tussenruimte),
          Row(
            children: [
              for (var i = 0; i < totaal; i++) ...[
                if (i > 0)
                  SizedBox(width: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                Expanded(
                  child: SizedBox(
                    height: balkHoogte,
                    child: ColoredBox(
                      color: i < stap ? schema.primary : schema.outline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

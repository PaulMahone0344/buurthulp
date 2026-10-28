import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../theme.dart';
import '../domein/afgerond_overzicht.dart';

/// Kop boven, waarde eronder: leest rustig bij grote tekst en op een smal
/// scherm, zonder kolommen die afkappen.
class OverzichtLijst extends StatelessWidget {
  const OverzichtLijst({required this.regels, super.key});

  final List<OverzichtRegel> regels;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < regels.length; i++) ...[
          if (i > 0) SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  regels[i].kop,
                  style: tekst.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(regels[i].waarde, style: tekst.bodyLarge),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

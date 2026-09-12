import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';

/// Oppervlak met rand en grote radius, uit het CardTheme in theme.dart.
/// Optioneel een kop en een actie (meestal een [HhKnop] van soort tekst)
/// bovenin. Kop en actie staan in een Wrap zodat ze bij 200 procent tekst
/// onder elkaar vallen in plaats van af te kappen.
class HhKaart extends StatelessWidget {
  const HhKaart({
    required this.child,
    this.kop,
    this.actie,
    this.semantiekLabel,
    super.key,
  });

  final Widget child;
  final String? kop;
  final Widget? actie;

  /// Label voor de schermlezer; standaard de kop.
  final String? semantiekLabel;

  bool get heeftKop => kop != null || actie != null;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final binnenruimte = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussenruimte = HhRuimte.voor(HhRuimte.s, dichtheid);

    return Semantics(
      container: true,
      label: semantiekLabel ?? kop,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(binnenruimte),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (heeftKop) ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: tussenruimte,
                  runSpacing: tussenruimte,
                  children: [
                    if (kop != null) Text(kop!, style: tekst.titleLarge),
                    ?actie,
                  ],
                ),
                SizedBox(height: tussenruimte),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

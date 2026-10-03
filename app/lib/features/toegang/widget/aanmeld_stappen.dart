import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../theme.dart';

/// De stappen van aanmelden als helper (mockup H6): "1 Jij - 2 Ouder -
/// 3 Klaar". "Ouder" staat er alleen bij een helper onder de 18.
enum AanmeldStap { jij, ouder, klaar }

/// Welke stappen er zijn voor deze helper.
List<AanmeldStap> aanmeldStappen({required bool metOuder}) => [
  AanmeldStap.jij,
  if (metOuder) AanmeldStap.ouder,
  AanmeldStap.klaar,
];

String _naam(AanmeldStap stap) => switch (stap) {
  AanmeldStap.jij => TekstenAanmeldenNl.stapJij,
  AanmeldStap.ouder => TekstenAanmeldenNl.stapOuder,
  AanmeldStap.klaar => TekstenAanmeldenNl.stapKlaar,
};

/// Rondjes met een cijfer (of een vinkje als de stap gedaan is) en de naam
/// eronder, even breed verdeeld. De schermlezer hoort één zin:
/// "Stap 1 van 3: Jij".
class AanmeldStappen extends StatelessWidget {
  const AanmeldStappen({
    required this.huidig,
    required this.metOuder,
    super.key,
  });

  final AanmeldStap huidig;
  final bool metOuder;

  @override
  Widget build(BuildContext context) {
    final stappen = aanmeldStappen(metOuder: metOuder);
    final index = stappen.indexOf(huidig).clamp(0, stappen.length - 1);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final maat =
        HhMaten.icoonKeuzerij(dichtheid) + HhRuimte.voor(HhRuimte.s, dichtheid);

    return Semantics(
      container: true,
      label: TekstenAanmeldenNl.stappenZin(
        index + 1,
        stappen.length,
        _naam(stappen[index]),
      ),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stappen.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Rondje(nummer: i + 1, maat: maat, staat: _staat(i, index)),
                  SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                  Text(
                    _naam(stappen[i]),
                    textAlign: TextAlign.center,
                    style: tekst.bodyMedium!.copyWith(
                      fontWeight: i == index
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static _Staat _staat(int i, int huidig) => i < huidig
      ? _Staat.gedaan
      : i == huidig
      ? _Staat.nu
      : _Staat.later;
}

enum _Staat { gedaan, nu, later }

class _Rondje extends StatelessWidget {
  const _Rondje({
    required this.nummer,
    required this.maat,
    required this.staat,
  });

  final int nummer;
  final double maat;
  final _Staat staat;

  @override
  Widget build(BuildContext context) {
    final isGevuld = staat != _Staat.later;
    return Container(
      width: maat,
      height: maat,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isGevuld ? HhKleuren.primair : HhKleuren.achtergrond,
        border: Border.all(
          color: isGevuld ? HhKleuren.primair : HhKleuren.rand,
          width: 2,
        ),
      ),
      child: staat == _Staat.gedaan
          ? Icon(Icons.check, size: maat * 0.6, color: HhKleuren.opPrimair)
          : FittedBox(
              child: Text(
                '$nummer',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isGevuld
                      ? HhKleuren.opPrimair
                      : HhKleuren.tekstGedempt,
                ),
              ),
            ),
    );
  }
}

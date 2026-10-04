import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../design/lijn.dart';
import '../../../../theme.dart';

/// Een pil met het niveau ("Ervaren") of "Nieuw in de buurt". [isZacht] =
/// de rustige variant voor "Nieuw in de buurt" (KiesHelper).
class NiveauPil extends StatelessWidget {
  const NiveauPil({required this.tekst, this.isZacht = false, super.key});

  final String tekst;
  final bool isZacht;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final achter = isZacht ? HhKleuren.oppervlak : HhKleuren.accentZacht;
    final lijn = isZacht ? HhKleuren.rand : HhKleuren.accent;
    final kleur = isZacht ? HhKleuren.primair : HhKleuren.waarschuwing;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: HhRuimte.voor(HhRuimte.xs, dichtheid) / 2,
        horizontal: HhRuimte.voor(HhRuimte.s, dichtheid),
      ),
      decoration: BoxDecoration(
        color: achter,
        borderRadius: BorderRadius.circular(HhRadius.rond),
        border: Border.all(color: lijn, width: HhLijn.dun(context)),
      ),
      child: Text(
        tekst,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: kleur,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

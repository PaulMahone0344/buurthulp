import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_familie_nl.dart';
import '../../../theme.dart';

/// Eén gekoppelde oudere op F1. De hele tegel is een knop naar F3.
class OudereTegel extends StatelessWidget {
  const OudereTegel({required this.naam, required this.onTik, super.key});

  final String naam;
  final VoidCallback onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      side: BorderSide(color: schema.outline, width: HhLijn.dun(context)),
    );
    return Semantics(
      button: true,
      label: TekstenFamilieNl.f1TegelSemantiek(naam),
      onTap: onTik,
      excludeSemantics: true,
      child: Material(
        color: schema.surface,
        shape: vorm,
        child: InkWell(
          onTap: onTik,
          customBorder: vorm,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: HhMaten.knopHoogte(dichtheid),
            ),
            child: Padding(
              padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.l, dichtheid)),
              child: Row(
                children: [
                  Icon(
                    Icons.elderly_outlined,
                    size: HhMaten.icoonKeuzerij(dichtheid),
                    color: schema.primary,
                  ),
                  SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
                  Expanded(child: Text(naam, style: tekst.titleLarge)),
                  Icon(
                    Icons.chevron_right,
                    size: HhMaten.icoonKeuzerij(dichtheid),
                    color: HhKleuren.tekstDerde,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

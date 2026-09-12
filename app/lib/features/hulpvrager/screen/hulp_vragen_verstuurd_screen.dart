import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';

/// O6. Rustige bevestiging zonder cijfers en met een knop: naar het begin.
/// Geen terugknop: de stroom is klaar en de stapel is al weg (O5 gebruikt
/// go). Dit is de ene bewuste uitzondering op "altijd een terugknop".
class HulpVragenVerstuurdScreen extends StatelessWidget {
  const HulpVragenVerstuurdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);

    return HhScherm(
      titel: TekstenHulpvragerNl.verstuurdTitel,
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HhLegeStaat(
            icoon: Icons.check_circle_outline,
            titel: TekstenHulpvragerNl.verstuurdTitel,
            uitleg: TekstenHulpvragerNl.verstuurdUitleg,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenHulpvragerNl.verstuurdNaarBegin,
            semantiekLabel: TekstenHulpvragerNl.verstuurdNaarBeginSemantiek,
            icoon: Icons.home_outlined,
            onPressed: () => context.go(HhPaden.hulpvrager),
          ),
        ],
      ),
    );
  }
}

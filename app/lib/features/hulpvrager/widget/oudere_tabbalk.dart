import 'package:flutter/material.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_tabbalk.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../paden_hulpvrager.dart';
import '../status/paden_status.dart';

/// De vier plekken van de oudere (3 okt, indeling naar BuurtHeld).
enum OudereTab { start, mijnHulpvragen, belOns, meer }

/// Pad, woord en icoon per tab. "Bel ons" heeft een eigen pad onder
/// /hulpvrager, zodat /veiligheid/bel-ons voor de andere rollen blijft
/// zoals het was (met terugknop, zonder balk).
const oudereTabs = <HhTab>[
  HhTab(
    label: TekstenHulpvragerNl.tabStart,
    icoon: Icons.home_outlined,
    pad: HhPaden.hulpvrager,
  ),
  HhTab(
    label: TekstenHulpvragerNl.tabMijnHulpvragen,
    semantiekLabel: TekstenHulpvragerNl.tabMijnHulpvragenSemantiek,
    icoon: Icons.list_alt_outlined,
    pad: HhPadenStatus.hulpvragen,
  ),
  HhTab(
    label: TekstenHulpvragerNl.tabBelOns,
    icoon: Icons.phone_outlined,
    pad: HhPadenHulpvrager.belOnsTab,
  ),
  HhTab(
    label: TekstenHulpvragerNl.tabMeer,
    icoon: Icons.menu,
    pad: HhPadenHulpvrager.meer,
  ),
];

/// Een scherm van de oudere met de tabbalk eronder.
class OudereTabScherm extends StatelessWidget {
  const OudereTabScherm({required this.actief, required this.child, super.key});

  final OudereTab actief;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HhTabScherm(
      tabs: oudereTabs,
      actief: actief.index,
      semantiekLabel: TekstenHulpvragerNl.tabbalkLabel,
      child: child,
    );
  }
}

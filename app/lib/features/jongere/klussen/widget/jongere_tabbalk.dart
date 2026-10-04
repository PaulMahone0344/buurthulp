import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/paden.dart';
import '../../../../design/components/hh_tabbalk.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../meldingen/widget/meldingen_bel.dart';
import '../paden_klussen.dart';
import '../provider/klussen_providers.dart';
import '../../domein/helper_wacht.dart';
import '../../provider/screening_providers.dart';

/// De vier tabbladen van de helper (B10, mockup StartHelper): Start, Klussen,
/// Mijn klussen, Profiel. Instellingen zit sinds B10 onder het Profiel.
enum JongereTab {
  start,
  klussen,
  mijnKlussen,
  profiel;

  HhTab get tab => switch (this) {
    JongereTab.start => const HhTab(
      label: TekstenKlussenNl.tabStart,
      icoon: Icons.home_outlined,
      pad: HhPaden.jongere,
    ),
    JongereTab.klussen => const HhTab(
      label: TekstenKlussenNl.tabKlussen,
      icoon: Icons.search,
      pad: HhPadenKlussen.lijst,
    ),
    JongereTab.mijnKlussen => const HhTab(
      label: TekstenKlussenNl.tabMijnKlussen,
      icoon: Icons.assignment_turned_in_outlined,
      pad: HhPadenKlussen.mijnKlussen,
    ),
    JongereTab.profiel => const HhTab(
      label: TekstenKlussenNl.tabProfiel,
      icoon: Icons.person_outline,
      pad: HhPadenKlussen.profiel,
    ),
  };

  String get label => tab.label;
  String get pad => tab.pad;
}

final _jongereTabs = [for (final t in JongereTab.values) t.tab];

/// Onderste tabbalk van de helper: sinds B10 de gedeelde [HhTabbalk].
class JongereTabbalk extends StatelessWidget {
  const JongereTabbalk({required this.actief, super.key});

  final JongereTab actief;

  @override
  Widget build(BuildContext context) => HhTabbalk(
    tabs: _jongereTabs,
    actief: actief.index,
    semantiekLabel: TekstenKlussenNl.tabbalkLabel,
  );
}

/// Een scherm van de helper met de tabbalk eronder. Het kind is een gewoon
/// scherm met eigen Scaffold (HhScherm). M8: het belletje met de
/// ongelezen-teller staat in de kop.
class JongereTabScherm extends ConsumerWidget {
  const JongereTabScherm({
    required this.actief,
    required this.child,
    super.key,
  });

  final JongereTab actief;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // B10: zolang de helper in een tab is, volgen we de klussen van Start en
    // de tab Klussen. Anders raken ze "oud" terwijl hij op Profiel zit (bv.
    // na een taalwissel) en ververst Riverpod ze pas tijdens het bouwen van
    // de tab Klussen: "markNeedsBuild during build" (Riverpod 3.3.2).
    // Alleen voor een helper die klaar is: wie nog wacht, krijgt geen
    // verzoek naar de server (zoals in B2).
    if (ref.watch(helperWachtProvider) == HelperWacht.klaar) {
      ref.listen(gefilterdeKlussenProvider, (_, _) {});
      ref.listen(mijnKlussenProvider, (_, _) {});
    }
    return Scaffold(
      body: HhTabScope(child: MeldingenKop(child: child)),
      bottomNavigationBar: JongereTabbalk(actief: actief),
    );
  }
}

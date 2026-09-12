import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/paden.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../design/lijn.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../theme.dart';
import '../paden_klussen.dart';

/// De vier tabbladen van de jongere (M5; M6-M8 hergebruiken deze balk).
enum JongereTab {
  klussen,
  mijnKlussen,
  profiel,
  instellingen;

  String get label => switch (this) {
    JongereTab.klussen => TekstenKlussenNl.tabKlussen,
    JongereTab.mijnKlussen => TekstenKlussenNl.tabMijnKlussen,
    JongereTab.profiel => TekstenKlussenNl.tabProfiel,
    JongereTab.instellingen => TekstenKlussenNl.tabInstellingen,
  };

  IconData get icoon => switch (this) {
    JongereTab.klussen => Icons.search,
    JongereTab.mijnKlussen => Icons.assignment_turned_in_outlined,
    JongereTab.profiel => Icons.person_outline,
    JongereTab.instellingen => Icons.settings_outlined,
  };

  String get pad => switch (this) {
    JongereTab.klussen => HhPaden.jongere,
    JongereTab.mijnKlussen => HhPadenKlussen.mijnKlussen,
    JongereTab.profiel => HhPadenKlussen.profiel,
    JongereTab.instellingen => HhPadenKlussen.instellingen,
  };
}

/// Onderste tabbalk van de jongere. Eigen widget in plaats van de
/// Material NavigationBar: vaste raakhoogte uit theme.dart, kleuren uit
/// theme.dart, en labels die bij 200 procent wikkelen in plaats van
/// afkappen. Navigeert met context.go zodat er geen stapel ontstaat.
class JongereTabbalk extends StatelessWidget {
  const JongereTabbalk({required this.actief, super.key});

  final JongereTab actief;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);

    return Semantics(
      container: true,
      label: TekstenKlussenNl.tabbalkLabel,
      child: Material(
        color: HhKleuren.achtergrond,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: HhKleuren.rand,
                width: HhLijn.dun(context),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tab in JongereTab.values)
                    Expanded(
                      child: _TabKnop(
                        tab: tab,
                        isActief: tab == actief,
                        dichtheid: dichtheid,
                        onTik: tab == actief ? null : () => context.go(tab.pad),
                      ),
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

class _TabKnop extends StatelessWidget {
  const _TabKnop({
    required this.tab,
    required this.isActief,
    required this.dichtheid,
    required this.onTik,
  });

  final JongereTab tab;
  final bool isActief;
  final HhDichtheid dichtheid;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final kleur = isActief ? HhKleuren.primair : HhKleuren.tekstGedempt;

    return Semantics(
      button: true,
      selected: isActief,
      label: tab.label,
      onTap: onTik,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTik,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: HhMaten.knopHoogte(dichtheid)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: HhRuimte.voor(HhRuimte.s, dichtheid),
              horizontal: HhRuimte.voor(HhRuimte.xs, dichtheid),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tab.icoon,
                  size: HhMaten.icoonKeuzerij(dichtheid),
                  color: kleur,
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: tekst.bodyMedium!.copyWith(
                    color: kleur,
                    fontWeight: isActief ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Een scherm van de jongere met de tabbalk eronder. Het kind is een
/// gewoon scherm met eigen [Scaffold] (HhScherm); de buitenste Scaffold
/// haalt de onderste veilige rand uit het kind, de balk regelt hem zelf.
class JongereTabScherm extends StatelessWidget {
  const JongereTabScherm({
    required this.actief,
    required this.child,
    super.key,
  });

  final JongereTab actief;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: JongereTabbalk(actief: actief),
    );
  }
}

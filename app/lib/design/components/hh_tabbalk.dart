import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';
import '../lijn.dart';

/// Pagina voor een tab-route: zonder overgangsanimatie. Een tab is een
/// vaste plek; schuiven bij elke tik maakt duizelig (3 okt).
Page<void> hhTabPagina(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

/// Eén tab in de [HhTabbalk]: woord, icoon en het pad waar hij heen gaat.
@immutable
class HhTab {
  const HhTab({
    required this.label,
    required this.icoon,
    required this.pad,
    this.semantiekLabel,
    this.teller,
  });

  /// Kort woord onder het icoon.
  final String label;

  /// Wat een schermlezer zegt; standaard [label].
  final String? semantiekLabel;

  final IconData icoon;
  final String pad;

  /// B10: een korte teller onder het woord ("3 open"), in de foutkleur. Null
  /// = geen teller. Zet dan ook [semantiekLabel] met het aantal erin.
  final String? teller;
}

/// Onderste tabbalk (3 okt, indeling naar BuurtHeld): wit, dunne lijn
/// erboven, elke tab een icoon met één kort woord. De actieve tab is vet
/// en primair groen, met een amber streep erboven. Labels wikkelen bij
/// 200 procent in plaats van afkappen. Navigeert met context.go zodat er
/// geen stapel ontstaat: elke tab is een eigen plek.
class HhTabbalk extends StatelessWidget {
  const HhTabbalk({
    required this.tabs,
    required this.actief,
    required this.semantiekLabel,
    super.key,
  });

  final List<HhTab> tabs;

  /// Index in [tabs].
  final int actief;

  /// Wat een schermlezer over de hele balk zegt.
  final String semantiekLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semantiekLabel,
      child: Material(
        color: HhKleuren.achtergrond,
        child: DecoratedBox(
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
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _TabKnop(
                        tab: tabs[i],
                        isActief: i == actief,
                        onTik: i == actief
                            ? null
                            : () => context.go(tabs[i].pad),
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

/// Dikte van de amber streep boven de actieve tab.
const _streepDikte = 3.0;

class _TabKnop extends StatelessWidget {
  const _TabKnop({
    required this.tab,
    required this.isActief,
    required this.onTik,
  });

  final HhTab tab;
  final bool isActief;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final kleur = isActief ? HhKleuren.primair : HhKleuren.tekstGedempt;

    return Semantics(
      button: true,
      selected: isActief,
      label: tab.semantiekLabel ?? tab.label,
      onTap: onTik,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTik,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isActief ? HhKleuren.accent : Colors.transparent,
                width: _streepDikte,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: HhMaten.knopHoogte(dichtheid),
            ),
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
                  // Eén regel; past het woord niet (grote tekst, smal
                  // scherm), dan wordt het kleiner in plaats van midden in
                  // het woord af te breken.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: tekst.bodyMedium!.copyWith(
                        color: kleur,
                        fontWeight: isActief
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (tab.teller case final teller?) ...[
                    SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                    _Teller(tekst: teller),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "3 open" onder een tab. In de foutkleur: er wacht iets op iemand.
class _Teller extends StatelessWidget {
  const _Teller({required this.tekst});

  final String tekst;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: HhRuimte.voor(HhRuimte.s, dichtheid),
        vertical: HhRuimte.xs,
      ),
      decoration: BoxDecoration(
        color: HhKleuren.fout,
        borderRadius: BorderRadius.circular(HhRadius.rond),
      ),
      child: Text(
        tekst,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall!.copyWith(color: HhKleuren.opPrimair),
      ),
    );
  }
}

/// Markeert dat een scherm een tab is. [HhScherm] toont dan geen
/// terugknop: van een tab ga je met de balk naar een andere plek.
class HhTabScope extends InheritedWidget {
  const HhTabScope({required super.child, super.key});

  static bool isInTab(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HhTabScope>() != null;

  @override
  bool updateShouldNotify(HhTabScope oldWidget) => false;
}

/// Een scherm met de [HhTabbalk] eronder. Het kind is een gewoon scherm
/// met eigen Scaffold (HhScherm); de buitenste Scaffold haalt de onderste
/// veilige rand uit het kind, de balk regelt hem zelf.
class HhTabScherm extends StatelessWidget {
  const HhTabScherm({
    required this.tabs,
    required this.actief,
    required this.semantiekLabel,
    required this.child,
    super.key,
  });

  final List<HhTab> tabs;
  final int actief;
  final String semantiekLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HhTabScope(child: child),
      bottomNavigationBar: HhTabbalk(
        tabs: tabs,
        actief: actief,
        semantiekLabel: semantiekLabel,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';
import '../lijn.dart';

/// Een keuze in de [HhKeuzerij]: waarde, label en icoon.
@immutable
class HhKeuze<T> {
  const HhKeuze({
    required this.waarde,
    required this.label,
    required this.icoon,
  });

  final T waarde;
  final String label;
  final IconData icoon;
}

/// Rij van keuzeknoppen met icoon, naast elkaar en even breed. Met
/// [meerdere] false gedraagt de rij zich als radioknoppen (een keuze),
/// met true als vinkjes (nul of meer). [geselecteerd] wordt nooit
/// gemuteerd; [onGewijzigd] krijgt telkens een nieuwe set.
class HhKeuzerij<T> extends StatelessWidget {
  const HhKeuzerij({
    required this.keuzes,
    required this.geselecteerd,
    required this.onGewijzigd,
    this.meerdere = false,
    this.semantiekLabel,
    super.key,
  });

  final List<HhKeuze<T>> keuzes;
  final Set<T> geselecteerd;
  final ValueChanged<Set<T>>? onGewijzigd;
  final bool meerdere;

  /// Waar de rij over gaat, bijvoorbeeld "Soort klus".
  final String? semantiekLabel;

  bool get isActief => onGewijzigd != null;

  void _kies(T waarde) {
    if (!isActief) return;
    if (!meerdere) {
      onGewijzigd!({waarde});
      return;
    }
    final nieuw = geselecteerd.contains(waarde)
        ? geselecteerd.difference({waarde})
        : geselecteerd.union({waarde});
    onGewijzigd!(nieuw);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussenruimte = HhRuimte.voor(HhRuimte.s, dichtheid);

    return Semantics(
      container: true,
      label: semantiekLabel,
      // IntrinsicHeight: alle keuzes even hoog, ook als een label wikkelt.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < keuzes.length; i++) ...[
              if (i > 0) SizedBox(width: tussenruimte),
              Expanded(
                child: _KeuzeKnop(
                  keuze: keuzes[i],
                  isGekozen: geselecteerd.contains(keuzes[i].waarde),
                  isExclusief: !meerdere,
                  onTik: isActief ? () => _kies(keuzes[i].waarde) : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeuzeKnop<T> extends StatelessWidget {
  const _KeuzeKnop({
    required this.keuze,
    required this.isGekozen,
    required this.isExclusief,
    required this.onTik,
  });

  final HhKeuze<T> keuze;
  final bool isGekozen;
  final bool isExclusief;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final schema = Theme.of(context).colorScheme;
    final tekst = Theme.of(context).textTheme;
    final isActief = onTik != null;

    final kleur = isGekozen ? schema.primary : schema.onSurface;
    final rand = BorderSide(
      color: isGekozen ? schema.primary : schema.outline,
      width: isGekozen ? HhLijn.dik(context) : HhLijn.dun(context),
    );
    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.klein),
      side: rand,
    );

    return Semantics(
      button: true,
      enabled: isActief,
      checked: isGekozen,
      inMutuallyExclusiveGroup: isExclusief,
      label: keuze.label,
      onTap: onTik,
      excludeSemantics: true,
      child: Material(
        color: isGekozen ? HhKleuren.oppervlak : schema.surface,
        shape: vorm,
        child: InkWell(
          onTap: onTik,
          customBorder: vorm,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: HhMaten.knopHoogte(dichtheid),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: HhRuimte.voor(HhRuimte.m, dichtheid),
                horizontal: HhRuimte.voor(HhRuimte.s, dichtheid),
              ),
              child: Opacity(
                opacity: isActief ? 1 : _gedemptAlsUit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      keuze.icoon,
                      size: HhMaten.icoonKeuzerij(dichtheid),
                      color: kleur,
                    ),
                    SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                    Text(
                      keuze.label,
                      textAlign: TextAlign.center,
                      style: tekst.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kleur,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Zelfde demping als Material zelf gebruikt voor uitgeschakelde
  /// knoppen (onSurface op 38 procent).
  static const _gedemptAlsUit = 0.38;
}

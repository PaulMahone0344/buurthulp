import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../theme.dart';
import '../domein/sterren.dart';

/// Vijf sterren om een gemiddelde of één beoordeling te TONEN (J19), niet om
/// te kiezen. Halve sterren bij .5 en hoger. De schermlezer hoort [label];
/// de losse sterren zijn versiering.
class SterrenRij extends StatelessWidget {
  const SterrenRij({required this.waarde, required this.label, super.key});

  /// 0 t/m 5, zoals de server hem gaf.
  final double waarde;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final kleur = Theme.of(context).colorScheme.primary;
    final getoond = gemiddeldVoorWeergave(waarde);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Wrap(
        children: [
          for (var ster = 1; ster <= 5; ster++)
            Icon(
              getoond >= ster
                  ? Icons.star_rounded
                  : getoond >= ster - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: HhMaten.icoonKeuzerij(dichtheid),
              color: kleur,
            ),
        ],
      ),
    );
  }
}

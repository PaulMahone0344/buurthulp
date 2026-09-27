import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_beoordelen_nl.dart';
import '../../../../theme.dart';
import '../domein/sterren.dart';

/// Vijf sterren naast elkaar, elk een eigen tikvlak zo hoog als een knop
/// (48 normaal, 60 groot). Tik op de derde ster = drie sterren. Gevuld en
/// open verschillen in vorm, niet alleen in kleur. Onder de rij staat het
/// gekozen aantal in gewone woorden ("Goed"), zonder cijfer, zodat de
/// oudere nooit een getal hoeft te lezen.
///
/// Voor de schermlezer is het één groep met vijf keuzes; [metAantal] zet
/// bij de jongere het aantal erbij ("4 sterren, Goed"), bij de oudere
/// alleen het woord.
class SterrenKiezer extends StatelessWidget {
  const SterrenKiezer({
    required this.gekozen,
    required this.onGekozen,
    this.metAantal = true,
    super.key,
  });

  final int? gekozen;
  final ValueChanged<int>? onGekozen;
  final bool metAantal;

  static const aantal = 5;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final schema = Theme.of(context).colorScheme;
    final tekst = Theme.of(context).textTheme;
    final keuze = gekozen;

    return Semantics(
      container: true,
      label: TekstenBeoordelenNl.sterrenKiezerLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var ster = 1; ster <= aantal; ster++)
                Expanded(
                  child: _SterVlak(
                    ster: ster,
                    isGevuld: keuze != null && ster <= keuze,
                    isGekozen: keuze == ster,
                    label: metAantal
                        ? TekstenBeoordelenNl.sterrenSemantiek(
                            ster,
                            sterrenWoord(ster),
                          )
                        : sterrenWoord(ster),
                    kleur: schema.primary,
                    dichtheid: dichtheid,
                    onTik: onGekozen == null ? null : () => onGekozen!(ster),
                  ),
                ),
            ],
          ),
          if (keuze != null) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
            ExcludeSemantics(
              child: Text(
                sterrenWoord(keuze),
                textAlign: TextAlign.center,
                style: tekst.titleLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SterVlak extends StatelessWidget {
  const _SterVlak({
    required this.ster,
    required this.isGevuld,
    required this.isGekozen,
    required this.label,
    required this.kleur,
    required this.dichtheid,
    required this.onTik,
  });

  final int ster;
  final bool isGevuld;
  final bool isGekozen;
  final String label;
  final Color kleur;
  final HhDichtheid dichtheid;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final hoogte = HhMaten.knopHoogte(dichtheid);
    return Semantics(
      button: true,
      enabled: onTik != null,
      checked: isGekozen,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTik,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTik,
        customBorder: const CircleBorder(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: hoogte, minWidth: hoogte),
          child: Center(
            child: Icon(
              isGevuld ? Icons.star_rounded : Icons.star_outline_rounded,
              size: HhMaten.icoonKeuzerij(dichtheid),
              color: kleur,
            ),
          ),
        ),
      ),
    );
  }
}

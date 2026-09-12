import 'package:flutter/material.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';

/// Tijdelijk: "Mijn hulpvragen" tot O8 in M6/M7 wordt gebouwd. Alleen een
/// lege staat en de terugknop.
class MijnHulpvragenScreen extends StatelessWidget {
  const MijnHulpvragenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HhScherm(
      titel: TekstenHulpvragerNl.mijnHulpvragenTitel,
      onTerug: () => terugOf(context, HhPaden.hulpvrager),
      child: const HhLegeStaat(
        icoon: Icons.list_alt_outlined,
        titel: TekstenHulpvragerNl.mijnHulpvragenKomtBinnenkort,
        uitleg: TekstenHulpvragerNl.mijnHulpvragenUitleg,
      ),
    );
  }
}

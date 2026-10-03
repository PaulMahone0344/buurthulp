import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../model/hh_rol.dart';
import '../provider/sessie_providers.dart';
import '../widget/bewoner_formulier.dart';
import '../widget/helper_formulier.dart';

/// G4 (B2). Aanmelden in één scherm per rol: bewoner of helper. De rol komt
/// van G2 en gaat verplicht mee naar de server, samen met taal = nl. Na
/// succes stuurt de router-guard door naar G5 (bevestig je e-mailadres).
/// Familie en coordinator melden zich hier niet aan (familie staat sinds B0
/// niet meer in de rolkeuze; opruimen in B3).
class RegistrerenScreen extends ConsumerWidget {
  const RegistrerenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(gekozenRolProvider);
    void terug() => terugOf(context, HhPaden.welkom);

    return switch (rol) {
      HhRol.hulpvrager => HhScherm(
        titel: TekstenAanmeldenNl.bewonerTitel,
        onTerug: terug,
        child: const BewonerFormulier(),
      ),
      HhRol.jongere => HhScherm(
        titel: TekstenAanmeldenNl.helperTitel,
        onTerug: terug,
        child: const HelperFormulier(),
      ),
      _ => HhScherm(
        titel: TekstenNl.registrerenTitel,
        onTerug: terug,
        child: HhLegeStaat(
          icoon: Icons.person_add_alt_outlined,
          titel: TekstenNl.registrerenTitel,
          uitleg: TekstenNl.registrerenOnbekendeRol,
          knopLabel: TekstenNl.terug,
          onKnop: () => context.go(HhPaden.welkom),
        ),
      ),
    };
  }
}

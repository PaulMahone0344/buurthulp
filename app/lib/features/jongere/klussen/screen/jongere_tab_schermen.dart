import 'package:flutter/material.dart';

import '../../../toegang/screen/instellingen_screen.dart';
import '../../screen/screening_overzicht_screen.dart';
import '../widget/jongere_tabbalk.dart';

/// Tab Profiel (M5): het M3-overzicht J9 als tijdelijke inhoud, met de
/// tabbalk eronder. J19 (mijn profiel en reputatie, M7) vervangt de inhoud.
class JongereProfielScreen extends StatelessWidget {
  const JongereProfielScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const JongereTabScherm(
      actief: JongereTab.profiel,
      child: ScreeningOverzichtScreen(),
    );
  }
}

/// Tab Instellingen (M5): G7 met de tabbalk eronder.
class JongereInstellingenScreen extends StatelessWidget {
  const JongereInstellingenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const JongereTabScherm(
      actief: JongereTab.instellingen,
      child: InstellingenScreen(),
    );
  }
}

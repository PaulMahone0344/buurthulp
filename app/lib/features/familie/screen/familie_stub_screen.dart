import 'package:flutter/material.dart';

import '../../meldingen/widget/meldingen_bel.dart';
import '../../rol_landing_scherm.dart';
import '../../toegang/model/hh_rol.dart';

/// Landing voor de rol familie. Vult zich in latere opdrachten met de
/// schermen uit hoofdstuk 3 van het app-plan.
class FamilieStubScreen extends StatelessWidget {
  const FamilieStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // M8: het belletje met de ongelezen-teller in de kop.
    return const Scaffold(
      body: MeldingenKop(
        child: RolLandingScherm(
          rol: HhRol.familie,
          icoon: Icons.family_restroom,
        ),
      ),
    );
  }
}

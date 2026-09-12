import 'package:flutter/material.dart';

import '../../rol_landing_scherm.dart';
import '../../toegang/model/hh_rol.dart';

/// Landing voor de rol jongere. Vult zich in latere opdrachten met de
/// schermen uit hoofdstuk 3 van het app-plan.
class JongereStubScreen extends StatelessWidget {
  const JongereStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolLandingScherm(
      rol: HhRol.jongere,
      icoon: Icons.directions_run,
    );
  }
}

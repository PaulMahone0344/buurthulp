import 'package:flutter/material.dart';

import '../../rol_landing_scherm.dart';
import '../../toegang/model/hh_rol.dart';

/// Landing voor de rol coordinator. Vult zich in latere opdrachten met de
/// schermen uit hoofdstuk 3 van het app-plan.
class CoordinatorStubScreen extends StatelessWidget {
  const CoordinatorStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolLandingScherm(
      rol: HhRol.coordinator,
      icoon: Icons.support_agent,
    );
  }
}

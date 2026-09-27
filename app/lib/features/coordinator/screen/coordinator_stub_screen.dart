import 'package:flutter/material.dart';

import 'coordinator_incidenten_screen.dart';

/// Landing voor de rol coordinator: C1, de meldingen die binnenkomen, met
/// de tabbalk eronder (M10). Heette een stub tot M10 hem vulde; de naam
/// blijft staan zodat router.dart niets hoeft te veranderen.
class CoordinatorStubScreen extends StatelessWidget {
  const CoordinatorStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoordinatorIncidentenScreen();
  }
}

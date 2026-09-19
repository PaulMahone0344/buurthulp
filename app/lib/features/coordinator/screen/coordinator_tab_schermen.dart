import 'package:flutter/material.dart';

import '../../toegang/screen/instellingen_screen.dart';
import '../widget/coordinator_tabbalk.dart';

/// Tab Instellingen (M10): G7 met de tabbalk van de coordinator eronder.
class CoordinatorInstellingenScreen extends StatelessWidget {
  const CoordinatorInstellingenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoordinatorTabScherm(
      actief: CoordinatorTab.instellingen,
      child: InstellingenScreen(),
    );
  }
}

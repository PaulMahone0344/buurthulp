import 'package:flutter/material.dart';

import 'hulpvrager_home_screen.dart';

/// De rolroute /hulpvrager uit M2 wijst hierheen. Sinds M4 is dit O1
/// ([HulpvragerHomeScreen]); de naam blijft tot de router en de M2-tests
/// zijn samengevoegd (OPEN-PUNTEN-M4).
class HulpvragerStubScreen extends StatelessWidget {
  const HulpvragerStubScreen({super.key});

  @override
  Widget build(BuildContext context) => const HulpvragerHomeScreen();
}

import 'package:flutter/material.dart';

import '../../rol_stub_scherm.dart';

/// Stub voor de rol familie. Vult zich in latere opdrachten met de schermen
/// uit hoofdstuk 3 van het app-plan.
class FamilieStubScreen extends StatelessWidget {
  const FamilieStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolStubScherm(rol: 'Familie', icoon: Icons.family_restroom);
  }
}

import 'package:flutter/material.dart';

import '../../rol_stub_scherm.dart';

/// Stub voor de rol coordinator. Vult zich in latere opdrachten met de schermen
/// uit hoofdstuk 3 van het app-plan.
class CoordinatorStubScreen extends StatelessWidget {
  const CoordinatorStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolStubScherm(rol: 'Coordinator', icoon: Icons.support_agent);
  }
}

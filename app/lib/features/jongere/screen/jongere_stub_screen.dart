import 'package:flutter/material.dart';

import '../../rol_stub_scherm.dart';

/// Stub voor de rol jongere. Vult zich in latere opdrachten met de schermen
/// uit hoofdstuk 3 van het app-plan.
class JongereStubScreen extends StatelessWidget {
  const JongereStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolStubScherm(rol: 'Jongere', icoon: Icons.directions_bike);
  }
}

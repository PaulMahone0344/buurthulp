import 'package:flutter/material.dart';

import '../../rol_stub_scherm.dart';

/// Stub voor de rol hulpvrager. Vult zich in latere opdrachten met de schermen
/// uit hoofdstuk 3 van het app-plan.
class HulpvragerStubScreen extends StatelessWidget {
  const HulpvragerStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolStubScherm(rol: 'Hulpvrager', icoon: Icons.elderly);
  }
}

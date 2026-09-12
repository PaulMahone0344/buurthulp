import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../design/components/hh_lege_staat.dart';
import '../theme.dart';

/// Gedeelde steiger voor de vier rol-stubs van M0. Toont alleen de rol en
/// een weg terug; de echte schermen uit hoofdstuk 3 komen per feature.
class RolStubScherm extends StatelessWidget {
  const RolStubScherm({required this.rol, required this.icoon, super.key});

  final String rol;
  final IconData icoon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(rol)),
      body: Padding(
        padding: const EdgeInsets.all(HhRuimte.l),
        child: HhLegeStaat(
          icoon: icoon,
          titel: rol,
          uitleg: 'Dit deel van de app komt in een latere opdracht.',
          knopLabel: 'Terug naar rolwissel',
          onKnop: () => context.go(rolwisselPad),
        ),
      ),
    );
  }
}

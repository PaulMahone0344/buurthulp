import 'package:flutter/material.dart';

import '../klussen/screen/klussen_home_screen.dart';

/// Landing van de jongere (/jongere). Heet nog JongereStubScreen omdat
/// router.dart (M2) en de M2/M3-tests op die naam wijzen; sinds M5 bouwt hij
/// J11/J12 (klussen in de buurt) met de tabbalk van de jongere. Een jongere
/// die nog niet goedgekeurd is komt hier niet: de router-guard stuurt hem
/// naar J9. De M2-landing (naam, rol, uitloggen) is opgegaan in de tabbladen
/// Profiel en Instellingen.
class JongereStubScreen extends StatelessWidget {
  const JongereStubScreen({super.key});

  @override
  Widget build(BuildContext context) => const KlussenHomeScreen();
}

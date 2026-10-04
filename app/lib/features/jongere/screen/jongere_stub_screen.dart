import 'package:flutter/material.dart';

import '../start/helper_start_screen.dart';

/// Landing van de jongere (/jongere). Heet nog JongereStubScreen omdat
/// router.dart (M2) en de M2/M3-tests op die naam wijzen; sinds B10 bouwt
/// hij de Start van de helper (mockup StartHelper): niveau, klussen in de
/// buurt, volgende klus en verdiensten. De klussenlijst (J11/J12) is de tab
/// Klussen (/jongere/klussen). Een jongere die nog niet goedgekeurd is komt
/// hier niet: de router-guard stuurt hem naar J9.
class JongereStubScreen extends StatelessWidget {
  const JongereStubScreen({super.key});

  @override
  Widget build(BuildContext context) => const HelperStartScreen();
}

import 'package:flutter/material.dart';

import '../../../toegang/screen/instellingen_screen.dart';
import '../../reputatie/screen/mijn_reputatie_screen.dart';
import '../widget/jongere_tabbalk.dart';

/// Tab Profiel: J19 (mijn profiel en reputatie, M7) met de tabbalk eronder.
/// Het M3-overzicht J9 blijft bereikbaar via de knop "Mijn screening".
class JongereProfielScreen extends StatelessWidget {
  const JongereProfielScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const JongereTabScherm(
      actief: JongereTab.profiel,
      child: MijnReputatieScreen(),
    );
  }
}

/// Tab Instellingen (M5): G7 met de tabbalk eronder.
class JongereInstellingenScreen extends StatelessWidget {
  const JongereInstellingenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const JongereTabScherm(
      actief: JongereTab.instellingen,
      child: InstellingenScreen(),
    );
  }
}

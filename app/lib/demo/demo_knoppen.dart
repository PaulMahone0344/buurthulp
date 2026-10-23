// DEMO — één knop per rol op G2. Logt in bij de demo-fake; de guard
// stuurt daarna vanzelf naar de landing van die rol.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components/hh_kaart.dart';
import '../design/components/hh_knop.dart';
import '../design/dichtheid_scope.dart';
import '../features/toegang/model/hh_rol.dart';
import '../features/toegang/provider/sessie_providers.dart';
import '../theme.dart';
import 'demo_data.dart';

class DemoKnoppen extends ConsumerWidget {
  const DemoKnoppen({super.key});

  static const _kop = 'Demo: inloggen zonder wachtwoord';
  static const _uitleg =
      'Nepgegevens, geen server. Wat je hier doet, is weg na herstarten.';

  static const _rollen = [
    (HhRol.hulpvrager, 'Als bewoner', Icons.front_hand_outlined),
    (HhRol.jongere, 'Als strijder', Icons.volunteer_activism_outlined),
    (HhRol.coordinator, 'Als meldkamer', Icons.support_agent_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);

    return HhKaart(
      kop: _kop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_uitleg, style: Theme.of(context).textTheme.bodyMedium),
          for (final (rol, label, icoon) in _rollen) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            HhKnop(
              label: label,
              icoon: icoon,
              soort: HhKnopSoort.tweedeKeus,
              onPressed: () => ref
                  .read(sessieControllerProvider.notifier)
                  .inloggen(
                    email: demoGebruiker(rol).email,
                    wachtwoord: demoWachtwoord,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

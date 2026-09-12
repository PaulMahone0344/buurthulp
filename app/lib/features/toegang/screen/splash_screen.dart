import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/sessie_state.dart';
import '../provider/sessie_providers.dart';

/// G1. Getoond zolang de sessie onbekend is: het bewaarde token wordt
/// gecontroleerd. Geen verbinding geeft een meldbalk en een knop om het
/// opnieuw te proberen; het token blijft bewaard.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessie = ref.watch(sessieControllerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final fout = switch (sessie) {
      SessieOnbekend(:final fout) => fout,
      _ => null,
    };

    final rand = HhRuimte.voor(HhRuimte.xl, dichtheid);

    // Gecentreerd, maar scrollbaar zodra de tekst (200 procent) niet past.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, grenzen) => SingleChildScrollView(
            padding: EdgeInsets.all(rand),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: grenzen.maxHeight - 2 * rand,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      TekstenNl.appNaam,
                      style: tekst.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                  Text(
                    TekstenNl.splashOndertitel,
                    style: tekst.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: HhRuimte.voor(HhRuimte.xxl, dichtheid)),
                  if (fout == null)
                    const HhLaadStaat.spinner(label: TekstenNl.splashBezig)
                  else ...[
                    HhMeldBalk(
                      soort: HhMeldSoort.waarschuwing,
                      tekst: fout.melding,
                    ),
                    SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
                    HhKnop(
                      label: TekstenNl.opnieuwProberen,
                      icoon: Icons.refresh,
                      onPressed: () =>
                          ref.read(sessieControllerProvider.notifier).herstel(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

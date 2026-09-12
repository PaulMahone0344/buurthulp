import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';

/// Wacht op de screeninggegevens en bouwt pas dan het scherm. Laden toont
/// een skelet, een fout toont de Nederlandse melding met opnieuw proberen.
class ScreeningLader extends ConsumerWidget {
  const ScreeningLader({required this.builder, super.key});

  final Widget Function(BuildContext context, ScreeningGegevens gegevens)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(screeningControllerProvider);
    return switch (stand) {
      AsyncData<ScreeningGegevens>(:final value) => builder(context, value),
      AsyncError<ScreeningGegevens>(:final error) => HhLegeStaat(
        icoon: Icons.cloud_off_outlined,
        titel: TekstenJongereNl.ladenMislukt,
        uitleg: meldingVanFout(error),
        knopLabel: TekstenNl.opnieuwProberen,
        onKnop: () => ref.read(screeningControllerProvider.notifier).vernieuw(),
      ),
      _ => const HhLaadStaat.skelet(regels: 2),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_meldingen_nl.dart';
import '../../../theme.dart';
import '../../toegang/model/hh_rol.dart';
import '../domein/melding_domein.dart';
import '../provider/meldingen_providers.dart';

/// O1: de laatste melding als rustige regel bovenaan ("Sanne komt dinsdag
/// 15 september om 10:00."). Geen teller, geen lijst (ouderenregel). Tik
/// opent de hulpvraag (O7) en zet de melding op gelezen. Zonder melding
/// staat er niets.
class LaatsteMeldingRegel extends ConsumerWidget {
  const LaatsteMeldingRegel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final melding = ref.watch(laatsteMeldingProvider);
    if (melding == null) return const SizedBox.shrink();

    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final zin = melding.tekst.trim().isNotEmpty
        ? melding.tekst
        : titelVan(melding, HhRol.hulpvrager);
    final doel = doelVan(melding, HhRol.hulpvrager);

    Future<void> tik() async {
      await ref.read(meldingenProvider.notifier).markeerGelezen(melding);
      if (doel != null && context.mounted) await context.push(doel);
    }

    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      side: BorderSide(color: schema.outline, width: HhLijn.dun(context)),
    );

    return Semantics(
      button: doel != null,
      label: '${TekstenMeldingenNl.o1LaatsteSemantiek}: $zin',
      onTap: doel == null ? null : tik,
      excludeSemantics: true,
      child: Material(
        color: HhKleuren.oppervlak,
        shape: vorm,
        child: InkWell(
          onTap: doel == null ? null : tik,
          customBorder: vorm,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: HhMaten.knopHoogte(dichtheid),
            ),
            child: Padding(
              padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.m, dichtheid)),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: HhMaten.icoonKeuzerij(dichtheid),
                    color: schema.primary,
                  ),
                  SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                  Expanded(child: Text(zin, style: tekst.bodyLarge)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

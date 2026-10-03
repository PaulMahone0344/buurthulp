import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../theme.dart';
import '../provider/concept_controller.dart';

/// Besluit punt 5: de vaste nee-lijst en het verplichte vinkje "Mijn klus
/// valt hier niet onder". De server weigert een klus zonder vinkje; de
/// meldkamer ziet een markering bij woorden uit de lijst.
class KlusNeeLijstKaart extends ConsumerWidget {
  const KlusNeeLijstKaart({required this.toonFout, super.key});

  /// True na een tik op "Klus plaatsen" zonder vinkje.
  final bool toonFout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final akkoord = ref.watch(
      conceptProvider.select((c) => c.isNeeLijstAkkoord),
    );
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.xs, dichtheid);

    return HhKaart(
      kop: TekstenKlusNl.neeLijstTitel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final regel in TekstenKlusNl.neeLijst)
            Padding(
              padding: EdgeInsets.only(bottom: klein),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(Icons.block, size: 20, color: HhKleuren.fout),
                  ),
                  SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                  Expanded(child: Text(regel, style: tekst.bodyLarge)),
                ],
              ),
            ),
          SizedBox(height: klein),
          CheckboxListTile(
            value: akkoord,
            onChanged: (waarde) => ref
                .read(conceptProvider.notifier)
                .zetNeeLijstAkkoord(waarde ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              TekstenKlusNl.neeLijstAkkoord,
              style: tekst.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: toonFout && !akkoord
                ? Text(
                    TekstenKlusNl.ontbreektNeeLijst,
                    style: tekst.bodyMedium?.copyWith(color: HhKleuren.fout),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

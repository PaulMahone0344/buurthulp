import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../domein/reactie_regels.dart';
import '../provider/reactie_providers.dart';

/// "Ik kan nu helpen" op Start van de helper (punt 12). Aan = de server zet
/// beschikbaar_tot op nu + 3 uur: de helper telt mee bij "N helpers kunnen
/// nu" en krijgt meldingen van nieuwe klussen. Daarna gaat hij vanzelf uit.
class KanNuHelpenSchakelaar extends ConsumerStatefulWidget {
  const KanNuHelpenSchakelaar({super.key});

  @override
  ConsumerState<KanNuHelpenSchakelaar> createState() =>
      _KanNuHelpenSchakelaarState();
}

class _KanNuHelpenSchakelaarState extends ConsumerState<KanNuHelpenSchakelaar> {
  bool _isBezig = false;
  bool _mislukt = false;

  Future<void> _zet(bool aan) async {
    setState(() {
      _isBezig = true;
      _mislukt = false;
    });
    final gelukt = await ref.read(beschikbaarProvider.notifier).zet(aan);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      _mislukt = !gelukt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final dichtheid = HhDichtheidScope.van(context);
    final tot = ref.watch(beschikbaarProvider);
    final nu = ref.watch(klokProvider)();
    final aan = isNuBeschikbaar(tot, nu);

    return HhKaart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: aan,
            onChanged: _isBezig ? null : _zet,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: HhKleuren.opPrimair,
            activeTrackColor: HhKleuren.primair,
            title: Text(
              TekstenReactiesNl.nuHelpenTitel,
              style: tekst.titleMedium,
            ),
            subtitle: Text(
              aan && tot != null
                  ? TekstenReactiesNl.nuHelpenAan(tijdKort(tot))
                  : TekstenReactiesNl.nuHelpenUit,
              style: tekst.bodyMedium,
            ),
          ),
          if (_mislukt) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
            Text(
              TekstenReactiesNl.nuHelpenMislukt,
              style: tekst.bodyMedium!.copyWith(color: HhKleuren.fout),
            ),
          ],
        ],
      ),
    );
  }
}

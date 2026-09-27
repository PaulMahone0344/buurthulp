import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_meldingen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../theme.dart';
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../meldkamer_config.dart';
import '../paden_veiligheid.dart';
import '../provider/veiligheid_providers.dart';

/// O10. Eén grote knop die de meldkamer belt, de openingstijden eronder, en
/// als tweede keus "Probleem melden" (O11). Twee keuzes, altijd een
/// terugknop. Lukt bellen niet, dan staat het nummer in een meldbalk.
class BelOnsScreen extends ConsumerStatefulWidget {
  const BelOnsScreen({super.key});

  @override
  ConsumerState<BelOnsScreen> createState() => _BelOnsScreenState();
}

class _BelOnsScreenState extends ConsumerState<BelOnsScreen> {
  String? _melding;

  Future<void> _bel() async {
    setState(() => _melding = null);
    final gelukt = await ref.read(belMeldkamerProvider)();
    if (!mounted || gelukt) return;
    setState(
      () => _melding = TekstenNl.hulpBellenLuktNiet(MeldkamerConfig.telefoon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final rol = ref.watch(huidigeGebruikerProvider)?.rol ?? HhRol.hulpvrager;

    return HhScherm(
      titel: TekstenMeldingenNl.o10Titel,
      toonTerug: true,
      onTerug: () => terugOf(context, rol.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: HhMeldSoort.waarschuwing, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          Text(TekstenMeldingenNl.o10Uitleg, style: tekst.bodyLarge),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenMeldingenNl.o10Bellen,
            semantiekLabel: TekstenMeldingenNl.o10BellenSemantiek(
              MeldkamerConfig.telefoon,
            ),
            icoon: Icons.phone_outlined,
            maat: HhDichtheid.groot,
            onPressed: _bel,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Text(
            TekstenMeldingenNl.o10Openingstijden,
            style: tekst.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenMeldingenNl.o10ProbleemMelden,
            semantiekLabel: TekstenMeldingenNl.o10ProbleemMeldenSemantiek,
            icoon: Icons.report_problem_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPadenVeiligheid.probleem),
          ),
        ],
      ),
    );
  }
}

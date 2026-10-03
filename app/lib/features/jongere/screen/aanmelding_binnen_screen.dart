import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../toegang/widget/aanmeld_stappen.dart';
import '../provider/screening_providers.dart';

/// H6b "Aanmelding binnen": na het versturen. De stappen staan op "Klaar",
/// een groot vinkje, "De meldkamer kijkt hem na, meestal binnen 1 dag" en
/// de knop "Naar de start" (daar staat de gele wachtbalk).
class AanmeldingBinnenScreen extends ConsumerWidget {
  const AanmeldingBinnenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final nu = ref.watch(klokProvider)();
    final metOuder =
        ref.watch(screeningControllerProvider).value?.isMinderjarigOp(nu) ??
        false;

    return HhScherm(
      titel: TekstenAanmeldenNl.binnenTitel,
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AanmeldStappen(huidig: AanmeldStap.klaar, metOuder: metOuder),
          SizedBox(height: HhRuimte.voor(HhRuimte.xxl, dichtheid)),
          ExcludeSemantics(
            child: Icon(
              Icons.check_circle,
              size: HhMaten.icoonKeuzerij(dichtheid) * 3,
              color: HhKleuren.succes,
            ),
          ),
          SizedBox(height: tussen),
          Semantics(
            header: true,
            child: Text(
              TekstenAanmeldenNl.binnenKop,
              style: tekst.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Text(
            TekstenAanmeldenNl.binnenUitleg,
            style: tekst.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
          Text(
            TekstenAanmeldenNl.binnenMelding,
            style: tekst.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xxl, dichtheid)),
          HhKnop(
            label: TekstenAanmeldenNl.naarStart,
            icoon: Icons.arrow_forward,
            onPressed: () => context.go(HhPaden.jongere),
          ),
        ],
      ),
    );
  }
}

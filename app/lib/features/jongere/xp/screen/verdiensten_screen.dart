import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigatie.dart';
import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../../klussen/paden_klussen.dart';
import '../../provider/screening_providers.dart' show meldingVanFout;
import '../domein/xp_tekst.dart';
import '../model/hh_xp.dart';
import '../provider/xp_providers.dart';

/// "Mijn verdiensten" (B9): per maand en per jaar, zoals de server het
/// uitrekent uit de klaar-gemelde klussen. Voorlopig "verwacht".
class VerdienstenScreen extends ConsumerWidget {
  const VerdienstenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(xpOverzichtProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final waarde = stand.value;

    final Widget inhoud;
    if (waarde != null) {
      final v = waarde.verdiensten;
      inhoud = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            TekstenXpNl.verdienstenUitleg,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: tussen),
          if (v.maanden.isEmpty)
            Text(
              TekstenXpNl.verdienstenLeeg,
              style: Theme.of(context).textTheme.titleMedium,
            )
          else ...[
            _Lijst(kop: TekstenXpNl.perJaarKop, regels: v.jaren),
            SizedBox(height: tussen),
            _Lijst(kop: TekstenXpNl.perMaandKop, regels: v.maanden),
          ],
        ],
      );
    } else if (stand.hasError) {
      inhoud = HhLegeStaat(
        icoon: Icons.cloud_off_outlined,
        titel: TekstenXpNl.ladenMislukt,
        uitleg: meldingVanFout(stand.error),
        knopLabel: TekstenNl.opnieuwProberen,
        onKnop: () => ref.invalidate(xpOverzichtProvider),
      );
    } else {
      inhoud = const HhLaadStaat.skelet(regels: 4);
    }

    return HhScherm(
      titel: TekstenXpNl.verdienstenTitel,
      onTerug: () => terugOf(context, HhPadenKlussen.profiel),
      child: inhoud,
    );
  }
}

class _Lijst extends StatelessWidget {
  const _Lijst({required this.kop, required this.regels});

  final String kop;
  final List<HhVerdienstRegel> regels;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return HhKaart(
      kop: kop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < regels.length; i++) ...[
            if (i > 0) SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            MergeSemantics(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        periodeTekst(regels[i].periode),
                        style: tekst.bodyLarge,
                      ),
                      Text(
                        TekstenXpNl.klussenAantal(regels[i].klussen),
                        style: tekst.bodySmall,
                      ),
                    ],
                  ),
                  Text(
                    euroVanBedrag(regels[i].bedrag),
                    style: tekst.titleMedium!.copyWith(
                      color: HhKleuren.primair,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

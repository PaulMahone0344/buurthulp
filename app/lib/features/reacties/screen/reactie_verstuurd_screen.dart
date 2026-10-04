import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paden.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../jongere/klussen/model/hh_klus.dart';
import '../../jongere/klussen/paden_klussen.dart';
import '../../jongere/klussen/provider/klussen_providers.dart';

/// HReactieVerstuurd (B5): de helper reageerde. De bewoner kiest zelf; een
/// helper onder 18 wacht eerst op zijn ouder ("Goed" op de website). Twee
/// knoppen: meer klussen of naar Mijn klussen (tab Gereageerd).
class ReactieVerstuurdScreen extends ConsumerWidget {
  const ReactieVerstuurdScreen({
    required this.klusId,
    this.wachtOpOuder = false,
    super.key,
  });

  final String klusId;
  final bool wachtOpOuder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klus = ref.watch(klusDetailProvider(klusId)).value;
    final nu = ref.watch(klokProvider)();

    return HhScherm(
      titel: TekstenReactiesNl.verstuurdTitel,
      onTerug: () => context.go(HhPaden.jongere),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: tussen),
          const ExcludeSemantics(
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: HhKleuren.succes,
            ),
          ),
          SizedBox(height: tussen),
          Semantics(
            header: true,
            child: Text(
              TekstenReactiesNl.verstuurdKop,
              textAlign: TextAlign.center,
              style: tekst.headlineSmall,
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Text(
            wachtOpOuder
                ? TekstenReactiesNl.verstuurdOuderUitleg
                : TekstenReactiesNl.verstuurdUitleg,
            textAlign: TextAlign.center,
            style: tekst.bodyLarge,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          if (klus != null) ...[
            _KlusRegel(klus: klus, nu: nu, wachtOpOuder: wachtOpOuder),
            SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          ],
          HhKnop(
            label: TekstenReactiesNl.meerKlussen,
            icoon: Icons.search_rounded,
            onPressed: () => context.go(HhPaden.jongere),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenReactiesNl.naarMijnKlussen,
            icoon: Icons.assignment_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.go(HhPadenKlussen.mijnKlussen),
          ),
        ],
      ),
    );
  }
}

class _KlusRegel extends StatelessWidget {
  const _KlusRegel({
    required this.klus,
    required this.nu,
    required this.wachtOpOuder,
  });

  final HhKlus klus;
  final DateTime nu;
  final bool wachtOpOuder;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return HhKaart(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metHoofdletter(klus.klustypeNaam),
                  style: tekst.titleMedium,
                ),
                Text(
                  wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu),
                  style: tekst.bodyMedium,
                ),
              ],
            ),
          ),
          SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Container(
            padding: EdgeInsets.symmetric(
              vertical: HhRuimte.voor(HhRuimte.xs, dichtheid),
              horizontal: HhRuimte.voor(HhRuimte.m, dichtheid),
            ),
            decoration: BoxDecoration(
              color: HhKleuren.accentZacht,
              borderRadius: BorderRadius.circular(HhRadius.rond),
              border: Border.all(
                color: HhKleuren.accent,
                width: HhLijn.dun(context),
              ),
            ),
            child: Text(
              wachtOpOuder
                  ? TekstenReactiesNl.pilOuder
                  : TekstenReactiesNl.pilWacht,
              style: tekst.bodyMedium!.copyWith(
                color: HhKleuren.waarschuwing,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

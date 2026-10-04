import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/pb/reactie_gateway.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../../chat/paden_chat.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../hulpvrager/status/paden_status.dart';
import '../../hulpvrager/status/provider/status_providers.dart';
import '../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../jongere/klussen/model/hh_klus.dart';
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../../toegang/provider/sessie_providers.dart';
import '../model/hh_reactie.dart';
import '../provider/reactie_providers.dart';
import '../widget/helper_kaart.dart';
import '../widget/match_sheet.dart';

/// KiesHelper (B5): de helpers die willen helpen bij één klus van de
/// bewoner. "Kies [naam]" vraagt eerst een bevestiging; daarna het
/// match-blad met "Open de chat" (B6). Een weigering (iemand anders was net
/// eerder, helper niet meer beschikbaar) toont de melding van de server en
/// laadt de lijst opnieuw.
class KiesHelperScreen extends ConsumerStatefulWidget {
  const KiesHelperScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<KiesHelperScreen> createState() => _KiesHelperScreenState();
}

class _KiesHelperScreenState extends ConsumerState<KiesHelperScreen> {
  String? _bezigMet;
  String? _melding;

  HhKlus? _klus() {
    final lijst = ref.watch(mijnHulpvragenProvider).value ?? const <HhKlus>[];
    return lijst.where((k) => k.id == widget.klusId).firstOrNull;
  }

  Future<void> _kies(HhReactieKaart kaart, HhKlus? klus) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TekstenReactiesNl.kiesVraag(kaart.voornaam)),
        content: Text(TekstenReactiesNl.kiesUitleg(kaart.voornaam)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(TekstenReactiesNl.kiesNee),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(TekstenReactiesNl.kiesJa),
          ),
        ],
      ),
    );
    if (ja != true || !mounted) return;
    setState(() {
      _bezigMet = kaart.reactieId;
      _melding = null;
    });
    final uitkomst = await ref.read(kiesProvider)(
      widget.klusId,
      kaart.reactieId,
    );
    if (!mounted) return;
    setState(() => _bezigMet = null);
    switch (uitkomst) {
      case Gekozen(:final helperVoornaam):
        final ik = ref.read(huidigeGebruikerProvider)?.naam ?? '';
        final nu = ref.read(klokProvider)();
        final keuze = await MatchSheet.toon(
          context,
          bewonerVoornaam: ik.trim().split(RegExp(r'\s+')).first,
          helperVoornaam: helperVoornaam.isEmpty
              ? kaart.voornaam
              : helperVoornaam,
          klusTekst: klus == null
              ? TekstenReactiesNl.onbekendeKlus
              : '${metHoofdletter(klus.klustypeNaam)} '
                    '${wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu)}',
        );
        if (!mounted) return;
        if (keuze == MatchKeuze.chat) {
          context.go(HhPadenStatus.hulpvraag(widget.klusId));
          context.push(HhPadenChat.chat(widget.klusId));
        } else {
          context.go(HhPadenStatus.hulpvraag(widget.klusId));
        }
      case KiesGeweigerd(:final melding):
        setState(() => _melding = melding);
      case KiesFout(:final fout):
        setState(() => _melding = fout.melding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final stand = ref.watch(reactiesVoorKlusProvider(widget.klusId));
    final klus = _klus();
    final nu = ref.watch(klokProvider)();
    final melding = _melding;

    final kop = <Widget>[
      if (klus != null) ...[
        Text(
          '${metHoofdletter(klus.klustypeNaam)} – '
          '${wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu)}',
          style: tekst.titleMedium,
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
      ],
      if (stand case AsyncData<List<HhReactieKaart>>(:final value))
        Text(
          TekstenReactiesNl.aantalReacties(value.length),
          style: tekst.bodyMedium,
        ),
      SizedBox(height: tussen),
      if (melding != null) ...[
        HhMeldBalk(soort: HhMeldSoort.fout, tekst: melding),
        SizedBox(height: tussen),
      ],
    ];

    return HhScherm(
      titel: TekstenReactiesNl.kiesTitel,
      onTerug: () => terugOf(context, HhPaden.hulpvrager),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...kop,
          ...switch (stand) {
            AsyncData<List<HhReactieKaart>>(:final value) when value.isEmpty =>
              [
                const HhLegeStaat(
                  icoon: Icons.hourglass_empty_rounded,
                  titel: TekstenReactiesNl.geenReacties,
                  uitleg: TekstenReactiesNl.geenReactiesUitleg,
                ),
              ],
            AsyncData<List<HhReactieKaart>>(:final value) => [
              for (final kaart in value) ...[
                HelperKaart(
                  kaart: kaart,
                  isBezig: _bezigMet == kaart.reactieId,
                  onKies: _bezigMet == null ? () => _kies(kaart, klus) : null,
                ),
                SizedBox(height: tussen),
              ],
            ],
            AsyncError<List<HhReactieKaart>>(:final error) => [
              HhLegeStaat(
                icoon: Icons.cloud_off_outlined,
                titel: TekstenReactiesNl.reactiesMislukt,
                uitleg: meldingVanFout(error),
                knopLabel: TekstenNl.opnieuwProberen,
                onKnop: () =>
                    ref.invalidate(reactiesVoorKlusProvider(widget.klusId)),
              ),
            ],
            _ => const [HhLaadStaat.skelet(regels: 3)],
          },
        ],
      ),
    );
  }
}

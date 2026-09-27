import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../theme.dart';
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../model/hh_kandidaat.dart';
import '../provider/coordinator_providers.dart';

/// De koppellijst van C2: zoekveld op naam en daaronder de goedgekeurde
/// jongeren, eerst die uit dezelfde wijk als de klus. Een tik op een naam
/// vraagt om bevestiging in het scherm eromheen.
class KandidaatLijst extends ConsumerStatefulWidget {
  const KandidaatLijst({
    required this.wijkId,
    required this.isBezig,
    required this.onKies,
    super.key,
  });

  /// De wijk van de oudere; die jongeren komen bovenaan.
  final String wijkId;
  final bool isBezig;
  final void Function(HhKandidaat) onKies;

  @override
  ConsumerState<KandidaatLijst> createState() => _KandidaatLijstState();
}

class _KandidaatLijstState extends ConsumerState<KandidaatLijst> {
  final _zoek = TextEditingController();

  @override
  void dispose() {
    _zoek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final stand = ref.watch(kandidatenVoorKlusProvider(widget.wijkId));

    return HhKaart(
      kop: TekstenCoordinatorNl.c2KoppelenTitel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HhInvoer(
            label: TekstenCoordinatorNl.c2ZoekLabel,
            controller: _zoek,
            isActief: !widget.isBezig,
            onChanged: (waarde) =>
                ref.read(kandidaatZoekProvider.notifier).zet(waarde),
          ),
          SizedBox(height: tussen),
          switch (stand) {
            AsyncData<List<HhKandidaat>>(:final value) when value.isEmpty =>
              const HhLegeStaat(
                icoon: Icons.person_search_outlined,
                titel: TekstenCoordinatorNl.c2GeenKandidaten,
                uitleg: TekstenCoordinatorNl.c2GeenKandidatenUitleg,
              ),
            AsyncData<List<HhKandidaat>>(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final kandidaat in value) ...[
                  _KandidaatRij(
                    kandidaat: kandidaat,
                    isAndereWijk:
                        widget.wijkId.isNotEmpty &&
                        kandidaat.wijkId != widget.wijkId,
                    onTik: widget.isBezig
                        ? null
                        : () => widget.onKies(kandidaat),
                  ),
                  SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                ],
              ],
            ),
            AsyncError<List<HhKandidaat>>(:final error) => HhLegeStaat(
              icoon: Icons.cloud_off_outlined,
              titel: TekstenCoordinatorNl.c2KandidatenLadenMislukt,
              uitleg: meldingVanFout(error),
            ),
            _ => const HhLaadStaat.skelet(regels: 3),
          },
        ],
      ),
    );
  }
}

class _KandidaatRij extends StatelessWidget {
  const _KandidaatRij({
    required this.kandidaat,
    required this.isAndereWijk,
    required this.onTik,
  });

  final HhKandidaat kandidaat;
  final bool isAndereWijk;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final wijk = kandidaat.heeftWijk
        ? kandidaat.wijkNaam
        : TekstenCoordinatorNl.c2KandidaatGeenWijk;
    final klussen = TekstenCoordinatorNl.c2KandidaatKlussen(
      kandidaat.klussenAantal,
    );

    return Semantics(
      button: true,
      label: '${kandidaat.naam}, $wijk, $klussen',
      excludeSemantics: true,
      child: Material(
        color: HhKleuren.achtergrond,
        borderRadius: BorderRadius.circular(HhRadius.midden),
        child: InkWell(
          onTap: onTik,
          borderRadius: BorderRadius.circular(HhRadius.midden),
          child: Container(
            padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.m, dichtheid)),
            constraints: BoxConstraints(
              minHeight: HhMaten.knopHoogte(dichtheid),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HhRadius.midden),
              border: Border.all(
                color: HhKleuren.rand,
                width: HhLijn.dun(context),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kandidaat.naam, style: tekst.bodyLarge),
                      SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                      Text('$wijk · $klussen', style: tekst.bodyMedium),
                      if (isAndereWijk) ...[
                        SizedBox(
                          height: HhRuimte.voor(HhRuimte.xs, dichtheid),
                        ),
                        Text(
                          TekstenCoordinatorNl.c2AndereWijkKort,
                          style: tekst.labelSmall!.copyWith(
                            color: HhKleuren.waarschuwing,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: HhMaten.icoonKeuzerij(dichtheid),
                  color: HhKleuren.tekstGedempt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

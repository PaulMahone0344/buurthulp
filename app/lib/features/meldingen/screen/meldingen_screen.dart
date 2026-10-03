import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_meldingen_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/melding_domein.dart';
import '../model/hh_melding.dart';
import '../provider/meldingen_providers.dart';

/// Het meldingen-overzicht (/meldingen) voor jongere en coordinator: nieuwste bovenaan, een stip bij ongelezen. Tik zet de
/// melding op gelezen en opent de klus (of het incident). Nieuwe meldingen
/// komen live binnen; pull-to-refresh haalt alles opnieuw op.
class MeldingenScreen extends ConsumerWidget {
  const MeldingenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(meldingenProvider);
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final rol = gebruiker?.rol ?? HhRol.jongere;
    final nu = ref.watch(klokProvider)();
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    Future<void> tik(HhMelding melding) async {
      await ref.read(meldingenProvider.notifier).markeerGelezen(melding);
      final doel = doelVan(melding, rol);
      if (doel != null && context.mounted) await context.push(doel);
    }

    final lijst = stand.value;
    final List<Widget> inhoud;
    if (lijst != null) {
      inhoud = lijst.isEmpty
          ? const [
              HhLegeStaat(
                icoon: Icons.notifications_none_outlined,
                titel: TekstenMeldingenNl.overzichtLeeg,
                uitleg: TekstenMeldingenNl.overzichtLeegUitleg,
              ),
            ]
          : [
              for (final melding in lijst) ...[
                MeldingTegel(
                  melding: melding,
                  titel: titelVan(melding, rol),
                  tijd: melding.gemaakt == null
                      ? ''
                      : meldingTijd(melding.gemaakt!, nu),
                  onTik: () => tik(melding),
                ),
                SizedBox(height: tussen),
              ],
            ];
    } else if (stand.hasError) {
      inhoud = [
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenMeldingenNl.overzichtLadenMislukt,
          uitleg: meldingVanFout(stand.error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.read(meldingenProvider.notifier).vernieuw(),
        ),
      ];
    } else {
      inhoud = const [HhLaadStaat.skelet(regels: 3)];
    }

    return HhScherm(
      titel: TekstenMeldingenNl.overzichtTitel,
      onTerug: () => terugOf(context, rol.pad),
      scrollbaar: false,
      child: RefreshIndicator(
        onRefresh: () => ref.read(meldingenProvider.notifier).vernieuw(),
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            rand,
            0,
            rand,
            HhRuimte.voor(HhRuimte.xl, dichtheid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: inhoud,
          ),
        ),
      ),
    );
  }
}

/// Eén melding in de lijst: stip (ongelezen), titel, tekst, tijd. De hele
/// tegel is een knop.
class MeldingTegel extends StatelessWidget {
  const MeldingTegel({
    required this.melding,
    required this.titel,
    required this.tijd,
    required this.onTik,
    super.key,
  });

  final HhMelding melding;
  final String titel;
  final String tijd;
  final VoidCallback onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final isNieuw = !melding.isGelezen;
    final stip = HhRuimte.voor(HhRuimte.s, dichtheid);

    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      side: BorderSide(
        color: isNieuw ? schema.primary : schema.outline,
        width: isNieuw ? HhLijn.dik(context) : HhLijn.dun(context),
      ),
    );

    return Semantics(
      button: true,
      label: TekstenMeldingenNl.tegelSemantiek(
        titel,
        melding.tekst,
        tijd,
        isNieuw,
      ),
      onTap: onTik,
      excludeSemantics: true,
      child: Material(
        color: schema.surface,
        shape: vorm,
        child: InkWell(
          onTap: onTik,
          customBorder: vorm,
          child: Padding(
            padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.l, dichtheid)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: HhRuimte.voor(HhRuimte.s, dichtheid),
                  ),
                  child: isNieuw
                      ? Container(
                          key: const ValueKey('ongelezen-stip'),
                          width: stip,
                          height: stip,
                          decoration: BoxDecoration(
                            color: schema.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      : SizedBox(width: stip, height: stip),
                ),
                SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titel,
                        style: tekst.titleLarge?.copyWith(
                          fontWeight: isNieuw
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (melding.tekst.trim().isNotEmpty) ...[
                        SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                        Text(melding.tekst, style: tekst.bodyLarge),
                      ],
                      if (tijd.isNotEmpty) ...[
                        SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                        Text(
                          tijd,
                          style: tekst.bodyMedium?.copyWith(
                            color: HhKleuren.tekstGedempt,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

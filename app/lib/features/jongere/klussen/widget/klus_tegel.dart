import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../design/lijn.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../theme.dart';
import '../../../hulpvrager/domein/klustype_icoon.dart';
import '../domein/afstand.dart';
import '../domein/wanneer_tekst.dart';
import '../model/hh_klus.dart';
import 'klus_status_pil.dart';

/// Een klus in de lijst (J11, J14): icoon van de klussoort, de soort als
/// kop, wanneer in gewone taal, de afstand (of "Locatie onbekend") en de
/// vergoeding. In J14 komt de statuspil erbij. De hele tegel is een knop.
class KlusTegel extends StatelessWidget {
  const KlusTegel({
    required this.klus,
    required this.nu,
    required this.onTik,
    this.middelpunt,
    this.toonStatus = false,
    super.key,
  });

  final HhKlus klus;
  final DateTime nu;
  final VoidCallback? onTik;
  final HhPunt? middelpunt;
  final bool toonStatus;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final avatar = HhMaten.avatar(dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);

    final soort = metHoofdletter(klus.klustypeNaam);
    final wanneer = wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu);
    final afstand = afstandVanKlus(klus, middelpunt);
    final afstandLabel = afstand == null
        ? TekstenKlussenNl.zonderLocatie
        : afstandTekst(afstand);
    final vergoeding = vergoedingVoorHelper(klus.vergoedingJongereCenten);
    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      side: BorderSide(color: schema.outline, width: HhLijn.dun(context)),
    );

    return Semantics(
      button: true,
      enabled: onTik != null,
      label: TekstenKlussenNl.klusTegelSemantiek(
        soort: soort,
        wanneer: wanneer,
        afstand: afstandLabel,
        vergoeding: toonStatus
            ? '$vergoeding, ${TekstenKlussenNl.statusSemantiek(KlusStatusPil.naamVan(klus.status))}'
            : vergoeding,
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
                Container(
                  width: avatar,
                  height: avatar,
                  decoration: const BoxDecoration(
                    color: HhKleuren.oppervlak,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    KlustypeIcoon.voor(klus.klustypeIcoon),
                    size: HhMaten.icoonKeuzerij(dichtheid),
                    color: schema.primary,
                  ),
                ),
                SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(soort, style: tekst.titleLarge),
                      if (wanneer.isNotEmpty) ...[
                        SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                        Text(wanneer, style: tekst.bodyLarge),
                      ],
                      SizedBox(height: tussen),
                      Wrap(
                        spacing: HhRuimte.voor(HhRuimte.m, dichtheid),
                        runSpacing: HhRuimte.voor(HhRuimte.xs, dichtheid),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Regel(
                            icoon: afstand == null
                                ? Icons.location_off_outlined
                                : Icons.place_outlined,
                            tekst: afstandLabel,
                          ),
                          _Regel(
                            icoon: Icons.payments_outlined,
                            tekst: vergoeding,
                          ),
                          if (toonStatus) KlusStatusPil(status: klus.status),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: HhMaten.icoonKeuzerij(dichtheid),
                  color: HhKleuren.tekstDerde,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Regel extends StatelessWidget {
  const _Regel({required this.icoon, required this.tekst});

  final IconData icoon;
  final String tekst;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final stijl = Theme.of(context).textTheme.bodyMedium!;
    // Flexible: bij 200 procent wikkelt de tekst in plaats van dat de rij
    // uit de tegel loopt.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icoon, size: stijl.fontSize! * 1.2, color: HhKleuren.tekstGedempt),
        SizedBox(width: HhRuimte.voor(HhRuimte.xs, dichtheid)),
        Flexible(child: Text(tekst, style: stijl)),
      ],
    );
  }
}

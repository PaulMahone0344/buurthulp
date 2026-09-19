import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../design/lijn.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../../jongere/klussen/model/hh_klus.dart';
import '../../domein/klustype_icoon.dart';
import '../domein/hulpvraag_indeling.dart';

/// Eén hulpvraag in de lijst van O8: icoon van de soort hulp, de soort als
/// kop, wanneer in gewone taal, en eronder in één zin waar het staat
/// ("Sanne is onderweg naar u"). Geen cijfers, geen statuspil met jargon.
/// De hele tegel is een knop.
class HulpvraagTegel extends StatelessWidget {
  const HulpvraagTegel({
    required this.klus,
    required this.nu,
    required this.onTik,
    super.key,
  });

  final HhKlus klus;
  final DateTime nu;
  final VoidCallback? onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final avatar = HhMaten.avatar(dichtheid);

    final soort = metHoofdletter(klus.klustypeNaam);
    final afgesproken = wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu);
    final wanneer = afgesproken.isEmpty
        ? TekstenUitvoerenNl.o7GeenTijd
        : afgesproken;
    final zin = klus.jongereVoornaam.isEmpty && klus.status == HhKlusStatus.open
        ? TekstenUitvoerenNl.o8NogNiemand
        : statusZin(klus);

    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      side: BorderSide(color: schema.outline, width: HhLijn.dun(context)),
    );

    return Semantics(
      button: true,
      enabled: onTik != null,
      label: TekstenUitvoerenNl.o8TegelSemantiek(soort, wanneer, zin),
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
                      SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                      Text(wanneer, style: tekst.bodyLarge),
                      SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                      Text(zin, style: tekst.bodyLarge),
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

import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../theme.dart';
import '../../jongere/klussen/domein/wanneer_tekst.dart' show wanneerTekst;
import '../model/hh_incident.dart';

/// Eén melding in de lijst van C1. Een noodmelding krijgt de gevaar-stijl
/// uit theme.dart (de vulling van status "probleem": foutkleur met witte
/// tekst) en een dikke rand, zodat hij ook zonder kleur opvalt tussen de
/// gewone meldingen.
class IncidentTegel extends StatelessWidget {
  const IncidentTegel({
    required this.incident,
    required this.nu,
    required this.onTik,
    super.key,
  });

  final HhIncident incident;
  final DateTime nu;
  final VoidCallback onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final binnen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.xs, dichtheid);

    final stijl = hhStatusStijlen[HhKlusStatus.probleem]!;
    final isNood = incident.isNood;
    final wanneer = wanneerTekst(incident.aangemaaktOp, null, nu);

    return Semantics(
      button: true,
      label: TekstenCoordinatorNl.c1RijSemantiek(
        incident.soort.naam,
        incident.melderNaam,
        wanneer,
      ),
      excludeSemantics: true,
      child: Material(
        color: HhKleuren.achtergrond,
        borderRadius: BorderRadius.circular(HhRadius.groot),
        child: InkWell(
          onTap: onTik,
          borderRadius: BorderRadius.circular(HhRadius.groot),
          child: Container(
            padding: EdgeInsets.all(binnen),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HhRadius.groot),
              border: Border.all(
                color: isNood ? stijl.vulling : HhKleuren.rand,
                width: isNood ? HhLijn.dik(context) : HhLijn.dun(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isNood
                          ? Icons.warning_amber_rounded
                          : Icons.flag_outlined,
                      size: HhMaten.icoonKeuzerij(dichtheid),
                      color: isNood ? stijl.vulling : HhKleuren.tekstGedempt,
                    ),
                    SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                    Expanded(
                      child: Text(
                        incident.soort.naam,
                        style: tekst.titleLarge!.copyWith(
                          color: isNood ? stijl.vulling : HhKleuren.tekst,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: klein),
                Text(
                  incident.melderNaam,
                  style: tekst.bodyLarge,
                ),
                SizedBox(height: klein),
                Text(wanneer, style: tekst.bodyMedium),
                if (incident.omschrijving.isNotEmpty) ...[
                  SizedBox(height: klein),
                  Text(
                    incident.omschrijving,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tekst.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

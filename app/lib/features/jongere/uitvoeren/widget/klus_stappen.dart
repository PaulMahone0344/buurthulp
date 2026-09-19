import 'package:flutter/material.dart';

import '../../../../design/components/hh_stapbalk.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../klussen/domein/wanneer_tekst.dart';
import '../../klussen/widget/klus_status_pil.dart';
import '../domein/klus_overgang.dart';
import '../provider/uitvoeren_providers.dart';

/// De stappenbalk van J15: vier standen (aangenomen, onderweg, aangekomen,
/// afgerond) met per gezette stap het tijdstip uit de logregels. "Bezig"
/// heet voor de jongere "Aangekomen" (J15 in het plan).
class KlusStappen extends StatelessWidget {
  const KlusStappen({required this.stand, super.key});

  final KlusMetGeschiedenis stand;

  /// De vier standen in volgorde, met hun naam voor de jongere.
  static const _standen = <(HhKlusStatus, String)>[
    (HhKlusStatus.geaccepteerd, TekstenKlussenNl.statusGeaccepteerd),
    (HhKlusStatus.onderweg, TekstenUitvoerenNl.j15StapOnderweg),
    (HhKlusStatus.bezig, TekstenUitvoerenNl.j15StapAangekomen),
    (HhKlusStatus.afgerond, TekstenUitvoerenNl.j15StapAfgerond),
  ];

  /// De naam die de jongere bij een stap ziet.
  static String naamVan(HhKlusStatus status) {
    for (final (stand, naam) in _standen) {
      if (stand == status) return naam;
    }
    return KlusStatusPil.naamVan(status);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    // Stap 1 = aangenomen, 4 = afgerond. gezetteStappen telt de drie stappen
    // ná het aannemen.
    final stap = (gezetteStappen(stand.klus.status) + 1).clamp(
      1,
      _standen.length,
    );
    final huidige = _standen[stap - 1];

    final gezet = <Widget>[];
    for (final (status, naam) in _standen) {
      final tijd = stand.tijdVan(status);
      if (tijd == null) continue;
      gezet.add(
        Padding(
          padding: EdgeInsets.only(top: klein),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(naam, style: tekst.bodyMedium)),
              SizedBox(width: klein),
              Text(
                tijdTekst(tijd),
                style: tekst.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HhStapbalk(stap: stap, totaal: _standen.length, titel: huidige.$2),
        ...gezet,
      ],
    );
  }
}

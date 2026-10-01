import 'package:flutter/material.dart';

import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../theme.dart';

/// Doorzetten (C2): de jongere van een klus halen. De reden is verplicht —
/// hij komt in het logboek te staan, zodat later te zien is waarom een klus
/// uit iemands handen werd gehaald. De knop heeft de gevaar-stijl: de
/// jongere die erop staat raakt zijn klus kwijt.
class VrijgeefBlok extends StatefulWidget {
  const VrijgeefBlok({
    required this.isBezig,
    required this.onVrijgeven,
    super.key,
  });

  final bool isBezig;
  final void Function(String reden) onVrijgeven;

  @override
  State<VrijgeefBlok> createState() => _VrijgeefBlokState();
}

class _VrijgeefBlokState extends State<VrijgeefBlok> {
  final _reden = TextEditingController();
  bool _toonLeegFout = false;

  @override
  void dispose() {
    _reden.dispose();
    super.dispose();
  }

  void _vrijgeven() {
    final tekst = _reden.text.trim();
    if (tekst.isEmpty) {
      setState(() => _toonLeegFout = true);
      return;
    }
    setState(() => _toonLeegFout = false);
    widget.onVrijgeven(tekst);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);

    return HhKaart(
      kop: TekstenCoordinatorNl.c2VrijgevenTitel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HhInvoer(
            label: TekstenCoordinatorNl.c2VrijgevenRedenLabel,
            controller: _reden,
            hulptekst: TekstenCoordinatorNl.c2VrijgevenRedenHulp,
            fouttekst: _toonLeegFout
                ? TekstenCoordinatorNl.c2VrijgevenRedenLeeg
                : null,
            maxRegels: 3,
            isActief: !widget.isBezig,
            onChanged: (_) {
              if (_toonLeegFout) setState(() => _toonLeegFout = false);
            },
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
          HhKnop(
            label: TekstenCoordinatorNl.c2Vrijgeven,
            icoon: Icons.person_remove_outlined,
            soort: HhKnopSoort.gevaar,
            isBezig: widget.isBezig,
            onPressed: _vrijgeven,
          ),
        ],
      ),
    );
  }
}

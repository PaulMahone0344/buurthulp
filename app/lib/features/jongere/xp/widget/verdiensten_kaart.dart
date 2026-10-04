import 'package:flutter/material.dart';

import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../domein/xp_tekst.dart';
import '../model/hh_xp.dart';

/// "Verdiensten (verwacht)": deze maand en dit jaar, met een knop naar alle
/// maanden. Echt geld komt met B7/B8; de server zegt wat het hoort te zijn.
class VerdienstenKaart extends StatelessWidget {
  const VerdienstenKaart({
    required this.verdiensten,
    required this.nu,
    required this.onAlles,
    super.key,
  });

  final HhVerdiensten verdiensten;
  final DateTime nu;
  final VoidCallback onAlles;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final maand = maandSleutel(nu);
    return HhKaart(
      kop: TekstenXpNl.verdienstenKop,
      actie: Text(
        TekstenXpNl.verdienstenVerwacht,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Regel(
            label: TekstenXpNl.dezeMaand,
            bedrag: euroVanBedrag(verdiensten.bedragIn(maand)),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          _Regel(
            label: TekstenXpNl.ditJaar,
            bedrag: euroVanBedrag(verdiensten.bedragIn(maand.substring(0, 4))),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
          HhKnop(
            label: TekstenXpNl.alleVerdiensten,
            icoon: Icons.payments_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: onAlles,
          ),
        ],
      ),
    );
  }
}

class _Regel extends StatelessWidget {
  const _Regel({required this.label, required this.bedrag});

  final String label;
  final String bedrag;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label, style: tekst.bodyLarge),
          Text(
            bedrag,
            style: tekst.titleMedium!.copyWith(color: HhKleuren.primair),
          ),
        ],
      ),
    );
  }
}

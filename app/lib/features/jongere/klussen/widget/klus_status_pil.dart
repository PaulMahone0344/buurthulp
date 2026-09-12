import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../design/lijn.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../theme.dart';

/// Statuspil voor een klus, met de kleuren uit [hhStatusStijlen]: actieve
/// statussen gevuld, wachtende met alleen een rand.
class KlusStatusPil extends StatelessWidget {
  const KlusStatusPil({required this.status, super.key});

  final HhKlusStatus status;

  static String naamVan(HhKlusStatus status) => switch (status) {
    HhKlusStatus.concept => TekstenKlussenNl.statusConcept,
    HhKlusStatus.open => TekstenKlussenNl.statusOpen,
    HhKlusStatus.geaccepteerd => TekstenKlussenNl.statusGeaccepteerd,
    HhKlusStatus.onderweg => TekstenKlussenNl.statusOnderweg,
    HhKlusStatus.bezig => TekstenKlussenNl.statusBezig,
    HhKlusStatus.afgerond => TekstenKlussenNl.statusAfgerond,
    HhKlusStatus.geannuleerd => TekstenKlussenNl.statusGeannuleerd,
    HhKlusStatus.probleem => TekstenKlussenNl.statusProbleem,
  };

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final stijl = hhStatusStijlen[status]!;
    final naam = naamVan(status);

    return Semantics(
      container: true,
      label: TekstenKlussenNl.statusSemantiek(naam),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: HhRuimte.voor(HhRuimte.xs, dichtheid),
          horizontal: HhRuimte.voor(HhRuimte.m, dichtheid),
        ),
        decoration: BoxDecoration(
          color: stijl.vulling,
          borderRadius: BorderRadius.circular(HhRadius.rond),
          border: Border.all(
            color: stijl.rand ?? stijl.vulling,
            width: HhLijn.dun(context),
          ),
        ),
        child: Text(
          naam,
          style: tekst.bodyMedium!.copyWith(
            color: stijl.tekst,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

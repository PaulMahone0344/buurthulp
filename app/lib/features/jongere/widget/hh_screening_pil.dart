import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../theme.dart';
import '../model/hh_screening_status.dart';

/// Statuspil voor de screening (verificatiestatus en vog_status). Bewust
/// niet hhStatusStijlen: dat zijn klusstatussen. Kleur uit theme.dart:
/// nieuw = info (rand), in behandeling = waarschuwing (rand op accentZacht),
/// goedgekeurd = succes (gevuld), afgewezen = fout (gevuld). Net als bij de
/// klussen: wachtend heeft een rand, beslist is gevuld.
class HhScreeningPil extends StatelessWidget {
  const HhScreeningPil({required this.status, this.label, super.key});

  final HhScreeningStatus status;

  /// Waar de pil over gaat, voor de schermlezer: "VOG: goedgekeurd".
  final String? label;

  static Color kleurVan(HhScreeningStatus status) => switch (status) {
    HhScreeningStatus.nieuw => HhKleuren.info,
    HhScreeningStatus.inBehandeling => HhKleuren.waarschuwing,
    HhScreeningStatus.goedgekeurd => HhKleuren.succes,
    HhScreeningStatus.afgewezen => HhKleuren.fout,
  };

  static bool isGevuld(HhScreeningStatus status) =>
      status == HhScreeningStatus.goedgekeurd ||
      status == HhScreeningStatus.afgewezen;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final kleur = kleurVan(status);
    final gevuld = isGevuld(status);
    final achtergrond = gevuld
        ? kleur
        : status == HhScreeningStatus.inBehandeling
        ? HhKleuren.accentZacht
        : HhKleuren.achtergrond;
    final tekstKleur = gevuld ? HhKleuren.opPrimair : kleur;

    return Semantics(
      container: true,
      label: label == null
          ? TekstenJongereNl.statusLabel(status.naam)
          : '$label: ${status.naam}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: HhRuimte.voor(HhRuimte.xs, dichtheid),
          horizontal: HhRuimte.voor(HhRuimte.m, dichtheid),
        ),
        decoration: BoxDecoration(
          color: achtergrond,
          borderRadius: BorderRadius.circular(HhRadius.rond),
          border: Border.all(color: kleur, width: HhLijn.dun(context)),
        ),
        child: Text(
          status.naam,
          style: tekst.bodyMedium!.copyWith(
            color: tekstKleur,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

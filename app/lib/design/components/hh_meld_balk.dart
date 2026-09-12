import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';
import '../lijn.dart';

/// Vier soorten melding. Altijd icoon plus tekst, nooit alleen kleur.
enum HhMeldSoort { informatie, geslaagd, waarschuwing, fout }

/// Melding in de pagina: rustig vlak met een gekleurde linkerrand. De
/// foutmelding is de enige met een rand rondom, zodat hij ook zonder
/// kleur opvalt. Wordt als live-region voorgelezen zodra hij verschijnt.
class HhMeldBalk extends StatelessWidget {
  const HhMeldBalk({required this.soort, required this.tekst, super.key});

  final HhMeldSoort soort;
  final String tekst;

  static const _naam = {
    HhMeldSoort.informatie: 'Informatie',
    HhMeldSoort.geslaagd: 'Geslaagd',
    HhMeldSoort.waarschuwing: 'Waarschuwing',
    HhMeldSoort.fout: 'Fout',
  };

  static const _icoon = {
    HhMeldSoort.informatie: Icons.info_outline,
    HhMeldSoort.geslaagd: Icons.check_circle_outline,
    HhMeldSoort.waarschuwing: Icons.warning_amber_outlined,
    HhMeldSoort.fout: Icons.error_outline,
  };

  static const _kleur = {
    HhMeldSoort.informatie: HhKleuren.info,
    HhMeldSoort.geslaagd: HhKleuren.succes,
    HhMeldSoort.waarschuwing: HhKleuren.waarschuwing,
    HhMeldSoort.fout: HhKleuren.fout,
  };

  static const _achtergrond = {
    HhMeldSoort.informatie: HhKleuren.oppervlak,
    HhMeldSoort.geslaagd: HhKleuren.oppervlak,
    HhMeldSoort.waarschuwing: HhKleuren.accentZacht,
    HhMeldSoort.fout: HhKleuren.achtergrond,
  };

  /// Kleur van tekst en icoon per soort; ook gebruikt door de contrasttest.
  static Color kleurVan(HhMeldSoort soort) => _kleur[soort]!;

  /// Achtergrond per soort; ook gebruikt door de contrasttest.
  static Color achtergrondVan(HhMeldSoort soort) => _achtergrond[soort]!;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final stijl = Theme.of(context).textTheme.bodyLarge!;
    final kleur = kleurVan(soort);
    final isFout = soort == HhMeldSoort.fout;

    final dunneRand = BorderSide(
      color: HhKleuren.rand,
      width: HhLijn.dun(context),
    );
    final accentRand = BorderSide(
      color: kleur,
      width: HhRuimte.voor(HhRuimte.xs, dichtheid),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${_naam[soort]}: $tekst',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: HhRuimte.voor(HhRuimte.m, dichtheid),
          horizontal: HhRuimte.voor(HhRuimte.l, dichtheid),
        ),
        decoration: BoxDecoration(
          color: achtergrondVan(soort),
          border: Border(
            left: accentRand,
            top: isFout ? dunneRand : BorderSide.none,
            right: isFout ? dunneRand : BorderSide.none,
            bottom: isFout ? dunneRand : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _icoon[soort],
              size: HhMaten.icoonKeuzerij(dichtheid),
              color: kleur,
            ),
            SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
            Expanded(
              child: Text(tekst, style: stijl.copyWith(color: kleur)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Lijndiktes, afgeleid van wat theme.dart al vastlegt. theme.dart kent
/// geen losse tokens voor lijndikte; in plaats van er zelf een getal bij
/// te verzinnen lezen we de dikte van de divider (dun) en van de
/// focusrand op invoervelden (dik). Staat in OPEN-PUNTEN.txt.
class HhLijn {
  const HhLijn._();

  /// Dunne rand: kaartranden, niet-gekozen keuzes, skeletkaders.
  static double dun(BuildContext context) =>
      Theme.of(context).dividerTheme.thickness!;

  /// Dikke rand: gekozen keuze, actieve accenten.
  static double dik(BuildContext context) {
    final rand = Theme.of(context).inputDecorationTheme.focusedBorder;
    return (rand! as OutlineInputBorder).borderSide.width;
  }
}

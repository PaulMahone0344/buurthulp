// HeitjeHulp - ontwerptokens
//
// Bron: mockup richting 1b "klinisch helder" uit Claude Design,
// 22 augustus 2026. Dit bestand is de enige plek waar een kleur,
// tekstmaat, afstand of radius staat. Staat een waarde ergens
// anders in de app, dan is dat een fout.
//
// Twee dichtheden. Normaal is voor de jongere, de familie en de
// coordinator. Groot is voor de hulpvrager: tekst vanaf 20, knoppen
// 60 hoog, een stap meer ruimte. De radius blijft in beide gelijk;
// vorm is hier geen signaal, maat en contrast zijn dat.

import 'package:flutter/material.dart';

enum HhDichtheid { normaal, groot }

@immutable
class HhKleuren {
  const HhKleuren();

  static const achtergrond = Color(0xFFFFFFFF);
  static const oppervlak = Color(0xFFF1F5F3);
  static const oppervlakZacht = Color(0xFFEEF2F0);
  static const tekst = Color(0xFF0E1C1A);
  static const tekstGedempt = Color(0xFF4A5754);
  static const tekstDerde = Color(0xFF8A9691);
  static const rand = Color(0xFFC7D4CF);
  static const randZacht = Color(0xFFE3EAE7);

  static const primair = Color(0xFF17453E);
  static const primairDonker = Color(0xFF0B2A25);
  static const opPrimair = Color(0xFFFFFFFF);

  static const accent = Color(0xFFF2B052);
  static const accentDonker = Color(0xFFEDA63F);
  static const accentZacht = Color(0xFFFBEED6);

  static const succes = Color(0xFF17594A);
  static const waarschuwing = Color(0xFF7A4E06);
  static const fout = Color(0xFF8F1F1F);
  static const info = Color(0xFF14556F);
}

/// De acht klusstatussen. Actieve statussen zijn gevuld, wachtende
/// hebben alleen een rand, zodat de lijst op vorm leesbaar is nog
/// voordat kleur meespeelt.
enum HhKlusStatus {
  concept,
  open,
  geaccepteerd,
  onderweg,
  bezig,
  afgerond,
  geannuleerd,
  probleem,
}

@immutable
class HhStatusStijl {
  const HhStatusStijl({
    required this.vulling,
    required this.tekst,
    this.rand,
  });

  final Color vulling;
  final Color tekst;
  final Color? rand;

  bool get isGevuld => rand == null;
}

const Map<HhKlusStatus, HhStatusStijl> hhStatusStijlen = {
  HhKlusStatus.concept: HhStatusStijl(
    vulling: Color(0xFFFFFFFF),
    tekst: HhKleuren.tekstGedempt,
    rand: HhKleuren.rand,
  ),
  HhKlusStatus.open: HhStatusStijl(
    vulling: Color(0xFFFFFFFF),
    tekst: HhKleuren.info,
    rand: HhKleuren.info,
  ),
  HhKlusStatus.geaccepteerd: HhStatusStijl(
    vulling: Color(0xFF3A3F8F),
    tekst: Color(0xFFFFFFFF),
  ),
  HhKlusStatus.onderweg: HhStatusStijl(
    vulling: Color(0xFF6B3F8F),
    tekst: Color(0xFFFFFFFF),
  ),
  HhKlusStatus.bezig: HhStatusStijl(
    vulling: HhKleuren.accentZacht,
    tekst: HhKleuren.waarschuwing,
    rand: HhKleuren.waarschuwing,
  ),
  HhKlusStatus.afgerond: HhStatusStijl(
    vulling: HhKleuren.succes,
    tekst: Color(0xFFFFFFFF),
  ),
  HhKlusStatus.geannuleerd: HhStatusStijl(
    vulling: Color(0xFFFFFFFF),
    tekst: HhKleuren.tekstGedempt,
    rand: HhKleuren.tekstGedempt,
  ),
  HhKlusStatus.probleem: HhStatusStijl(
    vulling: HhKleuren.fout,
    tekst: Color(0xFFFFFFFF),
  ),
};

@immutable
class HhRuimte {
  const HhRuimte._();

  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// In de grote dichtheid gaat elke afstand een stap omhoog.
  static double voor(double basis, HhDichtheid d) {
    if (d == HhDichtheid.normaal) return basis;
    const trap = [xs, s, m, l, xl, xxl, xxxl];
    final i = trap.indexOf(basis);
    if (i == -1 || i == trap.length - 1) return basis;
    return trap[i + 1];
  }
}

@immutable
class HhRadius {
  const HhRadius._();

  static const klein = 4.0;
  static const midden = 6.0;
  static const groot = 10.0;
  static const rond = 999.0;
}

@immutable
class HhMaten {
  const HhMaten._();

  /// Hoogte van een knop en van elk ander raakvlak.
  static double knopHoogte(HhDichtheid d) =>
      d == HhDichtheid.normaal ? 48.0 : 60.0;

  /// Iconen in de Keuzerij. Onder deze maat verliezen de dikke
  /// lijnen hun voordeel voor een oog dat minder scherp ziet.
  static double icoonKeuzerij(HhDichtheid d) =>
      d == HhDichtheid.normaal ? 24.0 : 32.0;

  /// Lijndikte van de iconen: zacht en dik.
  static const icoonLijn = 2.4;

  /// De avatar van de jongere draagt het vertrouwen bij de oudere
  /// en is daarom een hoofdelement, geen versiering.
  static double avatar(HhDichtheid d) =>
      d == HhDichtheid.normaal ? 44.0 : 64.0;
}

@immutable
class HhTekst {
  const HhTekst._();

  static const kopFamilie = 'Bricolage Grotesque';
  static const tekstFamilie = 'IBM Plex Sans';
  static const monoFamilie = 'IBM Plex Mono';

  static TextTheme themaVoor(HhDichtheid d) {
    final groot = d == HhDichtheid.groot;
    return TextTheme(
      // Titel groot
      displaySmall: TextStyle(
        fontFamily: kopFamilie,
        fontSize: groot ? 34 : 32,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.6,
        color: HhKleuren.tekst,
      ),
      // Titel
      headlineMedium: TextStyle(
        fontFamily: kopFamilie,
        fontSize: groot ? 26 : 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: HhKleuren.tekst,
      ),
      // Kop
      titleLarge: TextStyle(
        fontFamily: tekstFamilie,
        fontSize: groot ? 22 : 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: HhKleuren.tekst,
      ),
      // Tekst, de gewone leesregel
      bodyLarge: TextStyle(
        fontFamily: tekstFamilie,
        fontSize: groot ? 20 : 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: HhKleuren.tekst,
      ),
      // Tekst klein, hulptekst en uitleg
      bodyMedium: TextStyle(
        fontFamily: tekstFamilie,
        fontSize: groot ? 18 : 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: HhKleuren.tekstGedempt,
      ),
      // Label
      labelSmall: TextStyle(
        fontFamily: monoFamilie,
        fontSize: groot ? 14 : 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 1.2,
        color: HhKleuren.tekstGedempt,
      ),
    );
  }
}

ThemeData hhThema(HhDichtheid dichtheid) {
  final tekst = HhTekst.themaVoor(dichtheid);
  final knopHoogte = HhMaten.knopHoogte(dichtheid);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: HhKleuren.achtergrond,
    textTheme: tekst,
    colorScheme: const ColorScheme.light(
      primary: HhKleuren.primair,
      onPrimary: HhKleuren.opPrimair,
      secondary: HhKleuren.accent,
      onSecondary: HhKleuren.tekst,
      surface: HhKleuren.achtergrond,
      onSurface: HhKleuren.tekst,
      error: HhKleuren.fout,
      onError: Color(0xFFFFFFFF),
      outline: HhKleuren.rand,
    ),
    dividerTheme: const DividerThemeData(
      color: HhKleuren.rand,
      thickness: 1,
      space: 1,
    ),
    // Rand in plaats van schaduw. Dat houdt de schermen rustig en
    // leest beter bij fel omgevingslicht.
    cardTheme: CardThemeData(
      elevation: 0,
      color: HhKleuren.achtergrond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HhRadius.groot),
        side: const BorderSide(color: HhKleuren.rand),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, knopHoogte),
        backgroundColor: HhKleuren.primair,
        foregroundColor: HhKleuren.opPrimair,
        textStyle: tekst.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HhRadius.midden),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, knopHoogte),
        foregroundColor: HhKleuren.primair,
        side: const BorderSide(color: HhKleuren.rand, width: 1.5),
        textStyle: tekst.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HhRadius.midden),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HhKleuren.achtergrond,
      contentPadding: EdgeInsets.symmetric(
        horizontal: HhRuimte.voor(HhRuimte.l, dichtheid),
        vertical: HhRuimte.voor(HhRuimte.m, dichtheid),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HhRadius.midden),
        borderSide: const BorderSide(color: HhKleuren.rand),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HhRadius.midden),
        borderSide: const BorderSide(color: HhKleuren.primair, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HhRadius.midden),
        borderSide: const BorderSide(color: HhKleuren.fout, width: 2),
      ),
    ),
  );
}

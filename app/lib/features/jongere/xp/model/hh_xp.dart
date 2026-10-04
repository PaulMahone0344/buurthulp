import 'package:flutter/foundation.dart';

/// B9: wat de server over XP, niveaus, badges en verdiensten teruggeeft
/// (backend/pb_hooks/hh_xp_hulp.js). De app rekent hier NIETS zelf uit: hij
/// leest de getallen en toont ze. Onveranderlijk; onbekende of ontbrekende
/// velden worden een nette lege waarde, nooit een crash.

int _int(Object? v) => v is num ? v.toInt() : 0;
double _getal(Object? v) => v is num ? v.toDouble() : 0;
String _tekst(Object? v) => v == null ? '' : '$v'.trim();
DateTime? _datum(Object? v) {
  final t = _tekst(v);
  if (t.isEmpty) return null;
  return DateTime.tryParse(t.replaceFirst(' ', 'T'));
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.map((k, w) => MapEntry('$k', w)) : const {};
List<Map<String, dynamic>> _lijst(Object? v) =>
    v is List ? [for (final x in v) _map(x)] : const [];

/// Een niveau: code (nieuw, ervaren, top, geverifieerd) en de naam die de app
/// laat zien.
@immutable
class HhNiveau {
  const HhNiveau({required this.code, required this.naam});

  static const nieuw = HhNiveau(code: 'nieuw', naam: 'Nieuw');

  final String code;
  final String naam;

  factory HhNiveau.vanJson(Object? json) {
    final m = _map(json);
    final code = _tekst(m['code']);
    if (code.isEmpty) return nieuw;
    return HhNiveau(
      code: code,
      naam: _tekst(m['naam']).isEmpty ? code : _tekst(m['naam']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhNiveau && other.code == code && other.naam == naam;

  @override
  int get hashCode => Object.hash(code, naam);
}

/// Wat er nog nodig is voor het volgende niveau, plus de grenzen voor de
/// XP-balk ([xpVanaf] .. [xpTot]).
@immutable
class HhVolgendNiveau {
  const HhVolgendNiveau({
    required this.niveau,
    this.xpNodig = 0,
    this.klussenNodig = 0,
    this.sterrenNodig = 0,
    this.xpVanaf = 0,
    this.xpTot = 0,
  });

  final HhNiveau niveau;
  final int xpNodig;
  final int klussenNodig;
  final double sterrenNodig;
  final int xpVanaf;
  final int xpTot;

  static HhVolgendNiveau? vanJson(Object? json) {
    final m = _map(json);
    if (_tekst(m['code']).isEmpty) return null;
    return HhVolgendNiveau(
      niveau: HhNiveau.vanJson(m),
      xpNodig: _int(m['xp_nodig']),
      klussenNodig: _int(m['klussen_nodig']),
      sterrenNodig: _getal(m['sterren_nodig']),
      xpVanaf: _int(m['xp_vanaf']),
      xpTot: _int(m['xp_tot']),
    );
  }

  /// Hoe ver de balk staat (0..1) bij [xp] XP. De grenzen komen van de
  /// server; dit is alleen tekenen.
  double voortgang(int xp) {
    final breedte = xpTot - xpVanaf;
    if (breedte <= 0) return 1;
    return ((xp - xpVanaf) / breedte).clamp(0.0, 1.0);
  }
}

/// Een prestatie-badge. [behaaldOp] is null zolang hij nog niet behaald is.
/// [icoon] is de naam van een Material-icoon (alleen voorwerpen en vormen).
@immutable
class HhBadge {
  const HhBadge({
    required this.code,
    required this.naam,
    this.uitleg = '',
    this.icoon = '',
    this.behaaldOp,
  });

  final String code;
  final String naam;
  final String uitleg;
  final String icoon;
  final DateTime? behaaldOp;

  bool get isBehaald => behaaldOp != null;

  factory HhBadge.vanJson(Map<String, dynamic> m) => HhBadge(
    code: _tekst(m['code']),
    naam: _tekst(m['naam']),
    uitleg: _tekst(m['uitleg']),
    icoon: _tekst(m['icoon']),
    behaaldOp: _datum(m['behaald_op']),
  );
}

/// Een vertrouwensbadge met datum (ouder-toestemming, VOG, ID, iDIN).
@immutable
class HhVertrouwen {
  const HhVertrouwen({
    required this.code,
    required this.naam,
    this.icoon = '',
    this.datum,
    this.geldigTot,
    this.isVerlopen = false,
  });

  final String code;
  final String naam;
  final String icoon;
  final DateTime? datum;
  final DateTime? geldigTot;
  final bool isVerlopen;

  factory HhVertrouwen.vanJson(Map<String, dynamic> m) => HhVertrouwen(
    code: _tekst(m['code']),
    naam: _tekst(m['naam']),
    icoon: _tekst(m['icoon']),
    datum: _datum(m['datum']),
    geldigTot: _datum(m['geldig_tot']),
    isVerlopen: m['verlopen'] == true,
  );
}

/// Verdiensten in één maand ("2026-10") of één jaar ("2026"). Voorlopig
/// "verwacht": echt geld komt met B7/B8.
@immutable
class HhVerdienstRegel {
  const HhVerdienstRegel({
    required this.periode,
    required this.bedrag,
    required this.klussen,
  });

  final String periode;
  final double bedrag;
  final int klussen;
}

@immutable
class HhVerdiensten {
  const HhVerdiensten({
    this.maanden = const [],
    this.jaren = const [],
    this.totaal = 0,
  });

  static const leeg = HhVerdiensten();

  /// Nieuwste eerst, zoals de server ze geeft.
  final List<HhVerdienstRegel> maanden;
  final List<HhVerdienstRegel> jaren;
  final double totaal;

  factory HhVerdiensten.vanJson(Object? json) {
    final m = _map(json);
    return HhVerdiensten(
      maanden: [
        for (final r in _lijst(m['maanden']))
          HhVerdienstRegel(
            periode: _tekst(r['maand']),
            bedrag: _getal(r['bedrag']),
            klussen: _int(r['klussen']),
          ),
      ],
      jaren: [
        for (final r in _lijst(m['jaren']))
          HhVerdienstRegel(
            periode: _tekst(r['jaar']),
            bedrag: _getal(r['bedrag']),
            klussen: _int(r['klussen']),
          ),
      ],
      totaal: _getal(m['totaal']),
    );
  }

  /// De regel van [periode] ("2026-10" of "2026"), of 0 als er niets is.
  double bedragIn(String periode) {
    for (final r in [...maanden, ...jaren]) {
      if (r.periode == periode) return r.bedrag;
    }
    return 0;
  }
}

/// Een recensie zoals de helper hem op zijn profiel ziet (nooit een
/// achternaam; een recensie die de meldkamer verborg, stuurt de server niet).
@immutable
class HhRecensie {
  const HhRecensie({
    required this.sterren,
    required this.tekst,
    this.voornaam = '',
    this.datum,
  });

  final int sterren;
  final String tekst;
  final String voornaam;
  final DateTime? datum;

  factory HhRecensie.vanJson(Map<String, dynamic> m) => HhRecensie(
    sterren: _int(m['sterren']),
    tekst: _tekst(m['tekst']),
    voornaam: _tekst(m['voornaam']),
    datum: _datum(m['datum']),
  );
}

/// GET /api/hh/xp/mijn: alles voor het Profiel, het Start-blok en
/// "Mijn verdiensten".
@immutable
class HhXpOverzicht {
  const HhXpOverzicht({
    this.xpTotaal = 0,
    this.niveau = HhNiveau.nieuw,
    this.volgend,
    this.klussenAantal = 0,
    this.sterren = 0,
    this.beoordelingenAantal = 0,
    this.badges = const [],
    this.vertrouwen = const [],
    this.verdiensten = HhVerdiensten.leeg,
    this.recensies = const [],
  });

  final int xpTotaal;
  final HhNiveau niveau;

  /// null op het hoogste niveau dat je kunt verdienen (Top).
  final HhVolgendNiveau? volgend;
  final int klussenAantal;
  final double sterren;
  final int beoordelingenAantal;
  final List<HhBadge> badges;
  final List<HhVertrouwen> vertrouwen;
  final HhVerdiensten verdiensten;
  final List<HhRecensie> recensies;

  int get badgesBehaald => badges.where((b) => b.isBehaald).length;

  factory HhXpOverzicht.vanJson(Map<String, dynamic> m) => HhXpOverzicht(
    xpTotaal: _int(m['xp_totaal']),
    niveau: HhNiveau.vanJson(m['niveau']),
    volgend: HhVolgendNiveau.vanJson(m['volgend']),
    klussenAantal: _int(m['klussen_aantal']),
    sterren: _getal(m['sterren']),
    beoordelingenAantal: _int(m['beoordelingen_aantal']),
    badges: [for (final b in _lijst(m['badges'])) HhBadge.vanJson(b)],
    vertrouwen: [
      for (final v in _lijst(m['vertrouwen'])) HhVertrouwen.vanJson(v),
    ],
    verdiensten: HhVerdiensten.vanJson(m['verdiensten']),
    recensies: [for (final r in _lijst(m['recensies'])) HhRecensie.vanJson(r)],
  );
}

/// Wat de statusroute na "afgerond" meestuurt: de beloning voor HBeloning.
@immutable
class HhBeloning {
  const HhBeloning({
    this.xpErbij = 0,
    this.totaal = 0,
    this.niveau = HhNiveau.nieuw,
    this.isNiveauOmhoog = false,
    this.nieuweBadges = const [],
  });

  final int xpErbij;
  final int totaal;
  final HhNiveau niveau;
  final bool isNiveauOmhoog;
  final List<HhBadge> nieuweBadges;

  /// Iets om te vieren? Zonder XP, badge of niveau geen beloningsscherm.
  bool get isIetsTeVieren =>
      xpErbij > 0 || isNiveauOmhoog || nieuweBadges.isNotEmpty;

  static HhBeloning? vanJson(Object? json) {
    if (json is! Map) return null;
    final m = _map(json);
    return HhBeloning(
      xpErbij: _int(m['xp_erbij']),
      totaal: _int(m['totaal']),
      niveau: HhNiveau.vanJson(m['niveau']),
      isNiveauOmhoog: m['niveau_omhoog'] == true,
      nieuweBadges: [
        for (final b in _lijst(m['nieuwe_badges'])) HhBadge.vanJson(b),
      ],
    );
  }
}

/// De "Verklaring van inzet" (POST /api/hh/xp/verklaring): een snapshot met
/// een controlecode die de meldkamer (of wie hem krijgt) kan nakijken.
@immutable
class HhVerklaring {
  const HhVerklaring({
    required this.code,
    this.uitgegevenOp,
    this.voornaam = '',
    this.klussen = 0,
    this.uren = 0,
    this.periodeVan = '',
    this.periodeTot = '',
    this.niveau = '',
    this.badges = const [],
    this.vertrouwen = const [],
  });

  final String code;
  final DateTime? uitgegevenOp;
  final String voornaam;
  final int klussen;
  final double uren;
  final String periodeVan;
  final String periodeTot;
  final String niveau;

  /// (naam, datum "2026-10-01")
  final List<(String, String)> badges;
  final List<(String, String)> vertrouwen;

  factory HhVerklaring.vanJson(Map<String, dynamic> m) {
    final g = _map(m['gegevens']);
    List<(String, String)> paren(Object? v) => [
      for (final x in _lijst(v)) (_tekst(x['naam']), _tekst(x['datum'])),
    ];
    return HhVerklaring(
      code: _tekst(m['code']),
      uitgegevenOp: _datum(m['uitgegeven_op']),
      voornaam: _tekst(g['voornaam']),
      klussen: _int(g['klussen']),
      uren: _getal(g['uren']),
      periodeVan: _tekst(g['periode_van']),
      periodeTot: _tekst(g['periode_tot']),
      niveau: _tekst(g['niveau']),
      badges: paren(g['badges']),
      vertrouwen: paren(g['vertrouwen']),
    );
  }
}

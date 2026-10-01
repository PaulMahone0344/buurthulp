import '../model/hh_kandidaat.dart';

/// De volgorde van de koppellijst in C2: eerst de jongeren uit dezelfde
/// wijk als de klus (die hoeven het minst te reizen), daarna de rest.
/// Binnen elke groep op naam, hoofdletterongevoelig, zodat de lijst bij
/// elke opening hetzelfde staat.
///
/// [wijkId] leeg (de oudere heeft geen wijk): dan is er niets voor te
/// trekken en telt alleen de naam.
List<HhKandidaat> sorteerKandidaten(
  Iterable<HhKandidaat> kandidaten,
  String wijkId,
) {
  final gesorteerd = [...kandidaten];
  gesorteerd.sort((a, b) {
    if (wijkId.isNotEmpty) {
      final aEigen = a.wijkId == wijkId;
      final bEigen = b.wijkId == wijkId;
      if (aEigen != bEigen) return aEigen ? -1 : 1;
    }
    return a.naam.toLowerCase().compareTo(b.naam.toLowerCase());
  });
  return gesorteerd;
}

/// Zoekveld op naam: hoofdletterongevoelig, op een deel van de naam, en
/// spaties eromheen tellen niet mee. Leeg zoekwoord laat alles staan.
List<HhKandidaat> zoekKandidaten(
  Iterable<HhKandidaat> kandidaten,
  String zoek,
) {
  final woord = zoek.trim().toLowerCase();
  if (woord.isEmpty) return [...kandidaten];
  return [
    for (final kandidaat in kandidaten)
      if (kandidaat.naam.toLowerCase().contains(woord)) kandidaat,
  ];
}

/// Zoeken en sorteren in één stap: wat de koppellijst toont.
List<HhKandidaat> kandidatenVoorKlus(
  Iterable<HhKandidaat> kandidaten,
  String wijkId,
  String zoek,
) => sorteerKandidaten(zoekKandidaten(kandidaten, zoek), wijkId);

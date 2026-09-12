/// Datum als dag-maand-jaar, zoals de gebruiker hem typt en ziet.
/// Alleen dit; geen datumkiezer, want die spreekt Engels zolang de app geen
/// vertalingen laadt.
final _datumPatroon = RegExp(r'^\s*(\d{1,2})[-/. ](\d{1,2})[-/. ](\d{4})\s*$');

/// Null als het geen bestaande datum is (31-02-2008 is er geen).
DateTime? parseDatumNl(String invoer) {
  final match = _datumPatroon.firstMatch(invoer);
  if (match == null) return null;
  final dag = int.parse(match.group(1)!);
  final maand = int.parse(match.group(2)!);
  final jaar = int.parse(match.group(3)!);
  if (maand < 1 || maand > 12 || dag < 1) return null;
  final datum = DateTime.utc(jaar, maand, dag);
  if (datum.month != maand || datum.day != dag) return null;
  return datum;
}

String _twee(int n) => n.toString().padLeft(2, '0');

String toonDatumNl(DateTime datum) =>
    '${_twee(datum.day)}-${_twee(datum.month)}-${datum.year}';

/// Wat naar hh_users.geboortedatum of hh_profielen.vog_aangevraagd_op gaat.
String datumVoorServer(DateTime datum) => datum.toUtc().toIso8601String();

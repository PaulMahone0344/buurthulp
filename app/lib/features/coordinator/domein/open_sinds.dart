import '../../../l10n/teksten_coordinator_nl.dart';

/// Hoe lang een klus al open staat, in gewone taal: "3 dagen", "4 uur",
/// "12 minuten", of "zojuist geplaatst" onder een minuut. Eén eenheid, de
/// grootste die past — de coordinator hoeft niet op de minuut te weten hoe
/// oud iets is, hij wil zien wat blijft liggen.
///
/// Beide tijden gaan eerst naar UTC: de server rekent in UTC en de app in
/// lokale tijd, en dat verschil mag het aantal dagen niet verschuiven.
/// Een tijd in de toekomst (klok die naloopt) geeft "zojuist geplaatst".
String openSindsTekst(DateTime aangemaaktOp, DateTime nu) {
  final verschil = nu.toUtc().difference(aangemaaktOp.toUtc());
  if (verschil.inMinutes < 1) return TekstenCoordinatorNl.c2OpenSindsNet;
  if (verschil.inHours < 1) {
    return TekstenCoordinatorNl.c2OpenSindsMinuten(verschil.inMinutes);
  }
  if (verschil.inDays < 1) {
    return TekstenCoordinatorNl.c2OpenSindsUren(verschil.inHours);
  }
  return TekstenCoordinatorNl.c2OpenSindsDagen(verschil.inDays);
}

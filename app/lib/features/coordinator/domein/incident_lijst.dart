import '../model/hh_incident.dart';

/// Welke meldingen C1 toont. Afgehandeld = het veld afhandeling is gevuld;
/// de server kent geen apart statusveld op hh_incidenten.
enum IncidentFilter { open, afgehandeld }

/// Nieuwste bovenaan: zo staat een melding die net binnenkwam meteen in
/// beeld, ook als de coordinator de lijst al open had. Bij een gelijke tijd
/// beslist het id, zodat de volgorde nooit springt.
int vergelijkIncidenten(HhIncident a, HhIncident b) {
  final opTijd = b.aangemaaktOp.compareTo(a.aangemaaktOp);
  if (opTijd != 0) return opTijd;
  return b.id.compareTo(a.id);
}

List<HhIncident> sorteerIncidenten(Iterable<HhIncident> incidenten) =>
    [...incidenten]..sort(vergelijkIncidenten);

List<HhIncident> filterIncidenten(
  Iterable<HhIncident> incidenten,
  IncidentFilter filter,
) => sorteerIncidenten([
  for (final incident in incidenten)
    if (incident.isAfgehandeld == (filter == IncidentFilter.afgehandeld))
      incident,
]);

int telOpenIncidenten(Iterable<HhIncident> incidenten) {
  var aantal = 0;
  for (final incident in incidenten) {
    if (!incident.isAfgehandeld) aantal++;
  }
  return aantal;
}

/// Verwerkt een melding van de realtime-verbinding in de lijst die de app al
/// heeft: een onbekend id komt erbij, een bekend id vervangt de oude rij.
/// Altijd een nieuwe lijst; de oude wordt nooit gewijzigd.
List<HhIncident> metIncident(List<HhIncident> huidige, HhIncident incident) =>
    sorteerIncidenten([
      for (final bestaand in huidige)
        if (bestaand.id != incident.id) bestaand,
      incident,
    ]);

/// Haalt een verwijderde melding uit de lijst.
List<HhIncident> zonderIncident(List<HhIncident> huidige, String id) => [
  for (final bestaand in huidige)
    if (bestaand.id != id) bestaand,
];

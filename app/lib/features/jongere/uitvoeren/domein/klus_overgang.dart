import '../../../../theme.dart';

/// De statusmachine, zoals de server hem kent (backend/pb_hooks/
/// hh_klussen.pb.js). Deze kopie in de app is er ALLEEN om de goede knop te
/// tonen; de server beslist. Wijkt de app af, dan komt er een 409 terug en
/// laadt het scherm opnieuw.
///
///   geaccepteerd -> onderweg -> bezig -> afgerond
///
/// Geen stap overslaan, nooit terug.
const Map<HhKlusStatus, HhKlusStatus> klusOvergangen = {
  HhKlusStatus.geaccepteerd: HhKlusStatus.onderweg,
  HhKlusStatus.onderweg: HhKlusStatus.bezig,
  HhKlusStatus.bezig: HhKlusStatus.afgerond,
};

/// De volgende stap, of null als er geen is (concept, open, afgerond,
/// geannuleerd, probleem).
HhKlusStatus? volgendeStap(HhKlusStatus huidige) => klusOvergangen[huidige];

/// De drie stappen van J15, in volgorde. De stappenbalk toont ze allemaal;
/// de knop toont er telkens één.
const List<HhKlusStatus> uitvoerStappen = [
  HhKlusStatus.onderweg,
  HhKlusStatus.bezig,
  HhKlusStatus.afgerond,
];

/// Hoeveel van de drie stappen al gezet zijn: 0 bij geaccepteerd, 3 bij
/// afgerond. Een klus die niet in uitvoering is telt als 0.
int gezetteStappen(HhKlusStatus status) => switch (status) {
  HhKlusStatus.onderweg => 1,
  HhKlusStatus.bezig => 2,
  HhKlusStatus.afgerond => 3,
  _ => 0,
};

/// Is de klus voor de jongere nog in uitvoering (er is nog iets te doen)?
bool isInUitvoering(HhKlusStatus status) => klusOvergangen.containsKey(status);

/// De oudere annuleert: mag bij open, geaccepteerd en onderweg. Bij bezig
/// annuleert niemand — dat wordt "probleem melden" (M8).
bool magOudereAnnuleren(HhKlusStatus status) =>
    status == HhKlusStatus.open ||
    status == HhKlusStatus.geaccepteerd ||
    status == HhKlusStatus.onderweg;

/// De jongere geeft de klus terug: mag bij geaccepteerd en onderweg. De klus
/// gaat dan terug naar open; de oudere heeft de hulp nog steeds nodig.
bool magJongereAnnuleren(HhKlusStatus status) =>
    status == HhKlusStatus.geaccepteerd || status == HhKlusStatus.onderweg;

/// Bellen kan zodra de klus is aangenomen en zolang hij loopt.
bool magBellenBij(HhKlusStatus status) =>
    status == HhKlusStatus.geaccepteerd ||
    status == HhKlusStatus.onderweg ||
    status == HhKlusStatus.bezig;

/// De reden bij annuleren: verplicht, 5 tot en met 300 tekens (gelijk aan
/// de hook, die anders 400 teruggeeft).
const redenMinLengte = 5;
const redenMaxLengte = 300;

bool isGeldigeReden(String reden) {
  final schoon = reden.trim();
  return schoon.length >= redenMinLengte && schoon.length <= redenMaxLengte;
}

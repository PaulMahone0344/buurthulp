// DEMO — nepgegevens voor de demomodus (HH_DEMO=true). Alles is verzonnen;
// er gaat niets naar de server. Tijden zijn relatief aan "nu", zodat de
// lijsten er elke dag gevuld uitzien.

import '../features/chat/model/hh_bericht.dart';
import '../features/coordinator/model/hh_coordinator_klus.dart';
import '../features/coordinator/model/hh_incident.dart';
import '../features/coordinator/model/hh_kandidaat.dart';
import '../features/hulpvrager/model/hh_gegevens.dart';
import '../features/hulpvrager/model/hh_klustype.dart';
import '../features/jongere/klussen/model/hh_klus.dart';
import '../features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import '../features/jongere/xp/model/hh_xp.dart';
import '../features/meldingen/model/hh_melding.dart';
import '../features/toegang/domein/werkgebied.dart';
import '../features/toegang/model/hh_gebruiker.dart';
import '../features/toegang/model/hh_rol.dart';
import '../theme.dart';

/// Wachtwoord van de demo-accounts. Bestaat alleen in de fake.
const demoWachtwoord = 'demo';

const demoBewonerId = 'demo-bewoner';
const demoStrijderId = 'demo-strijder';
const demoCoordinatorId = 'demo-coordinator';

const _bewonerNaam = 'Mevrouw de Vries';
const _strijderNaam = 'Sanne Bakker';
const _adres = 'Prins Bernhardlaan 12, 4003 AB Tiel';
const _wijkId = 'wijk-west';
const _wijkNaam = 'Tiel-West';
const _wijkLat = 51.8865;
const _wijkLon = 5.4126;

HhGebruiker demoGebruiker(HhRol rol) => switch (rol) {
  HhRol.hulpvrager => const HhGebruiker(
    id: demoBewonerId,
    naam: _bewonerNaam,
    email: 'bewoner@demo.heitjehulp',
    rol: HhRol.hulpvrager,
    isBevestigd: true,
    wijkId: _wijkId,
    werkgebiedStatus: HhWerkgebiedStatus.binnen,
    postcode: '4003 AB',
    huisnummer: '12',
  ),
  HhRol.jongere => const HhGebruiker(
    id: demoStrijderId,
    naam: _strijderNaam,
    email: 'strijder@demo.heitjehulp',
    rol: HhRol.jongere,
    isBevestigd: true,
    wijkId: _wijkId,
    werkgebiedStatus: HhWerkgebiedStatus.binnen,
    postcode: '4001 MA',
    huisnummer: '1',
  ),
  HhRol.coordinator => const HhGebruiker(
    id: demoCoordinatorId,
    naam: 'Meldkamer Mozaïek',
    email: 'meldkamer@demo.heitjehulp',
    rol: HhRol.coordinator,
    isBevestigd: true,
  ),
};

/// Een klus van de demo-bewoner. [dagen] en [uur] zetten het tijdstip
/// ten opzichte van vandaag; [afstandKm] schuift hem op de kaart.
HhKlus demoKlus({
  required DateTime nu,
  required String id,
  HhKlusStatus status = HhKlusStatus.open,
  int dagen = 1,
  int uur = 10,
  String klustypeId = 'kt-boodschappen',
  String klustypeNaam = 'Boodschappen',
  String klustypeIcoon = 'shopping_cart',
  String omschrijving = 'Weekboodschappen bij de Jumbo',
  double afstandKm = 0.5,
  int vergoedingCenten = 1000,
  bool metStrijder = false,
}) {
  final dag = DateTime(nu.year, nu.month, nu.day + dagen, uur);
  return HhKlus(
    id: id,
    hulpvragerId: demoBewonerId,
    status: status,
    klustypeId: klustypeId,
    klustypeNaam: klustypeNaam,
    klustypeIcoon: klustypeIcoon,
    richtduurMinuten: 60,
    omschrijving: omschrijving,
    adres: _adres,
    lat: _wijkLat + afstandKm * 0.009,
    lon: _wijkLon,
    wanneerVan: dag,
    wanneerTot: dag.add(const Duration(hours: 1)),
    vergoedingJongereCenten: vergoedingCenten,
    toegewezenJongereId: metStrijder ? demoStrijderId : '',
    oudereNaam: _bewonerNaam,
    oudereWijkId: _wijkId,
    oudereContactNaam: 'Dochter Jansen',
    jongereNaam: metStrijder ? _strijderNaam : '',
  );
}

/// Open klussen in de wijk: wat de strijder kan oppakken.
List<HhKlus> demoOpenKlussen(DateTime nu) => [
  demoKlus(nu: nu, id: 'demo-open-1', afstandKm: 0.3),
  demoKlus(
    nu: nu,
    id: 'demo-open-2',
    uur: 14,
    klustypeId: 'kt-tuin',
    klustypeNaam: 'Tuin',
    klustypeIcoon: 'yard',
    omschrijving: 'Heg knippen aan de voorkant',
    afstandKm: 1.2,
    vergoedingCenten: 1500,
  ),
  demoKlus(
    nu: nu,
    id: 'demo-open-3',
    dagen: 2,
    uur: 16,
    klustypeId: 'kt-computer',
    klustypeNaam: 'Computer',
    klustypeIcoon: 'computer',
    omschrijving: 'Nieuwe telefoon instellen',
    afstandKm: 0.8,
  ),
];

/// Klussen waar de demo-strijder aan vastzit: vandaag, gepland, klaar.
List<HhKlus> demoMijnKlussen(DateTime nu) => [
  demoKlus(
    nu: nu,
    id: 'demo-vandaag',
    status: HhKlusStatus.geaccepteerd,
    dagen: 0,
    uur: 17,
    metStrijder: true,
  ),
  demoKlus(
    nu: nu,
    id: 'demo-gepland',
    status: HhKlusStatus.geaccepteerd,
    dagen: 3,
    klustypeId: 'kt-tuin',
    klustypeNaam: 'Tuin',
    klustypeIcoon: 'yard',
    omschrijving: 'Bladeren harken in de achtertuin',
    metStrijder: true,
  ),
  demoKlus(
    nu: nu,
    id: 'demo-klaar',
    status: HhKlusStatus.afgerond,
    dagen: -4,
    omschrijving: 'Medicijnen ophalen bij de apotheek',
    metStrijder: true,
  ),
];

/// Alles van de demo-bewoner: open, toegewezen en afgerond.
List<HhKlus> demoAlleKlussen(DateTime nu) => [
  ...demoOpenKlussen(nu),
  ...demoMijnKlussen(nu),
];

/// De statusgeschiedenis die bij een klus hoort.
List<HhKlusLogregel> demoLogregels(HhKlus klus, DateTime nu) {
  final reeks = <(HhKlusStatus?, HhKlusStatus)>[
    (null, HhKlusStatus.open),
    if (klus.status != HhKlusStatus.open)
      (HhKlusStatus.open, HhKlusStatus.geaccepteerd),
    if (klus.status == HhKlusStatus.afgerond) ...[
      (HhKlusStatus.geaccepteerd, HhKlusStatus.onderweg),
      (HhKlusStatus.onderweg, HhKlusStatus.bezig),
      (HhKlusStatus.bezig, HhKlusStatus.afgerond),
    ],
  ];
  final begin = nu.subtract(const Duration(days: 5));
  return [
    for (var i = 0; i < reeks.length; i++)
      HhKlusLogregel(
        id: 'log-${klus.id}-$i',
        klusId: klus.id,
        van: reeks[i].$1,
        naar: reeks[i].$2,
        doorId: reeks[i].$1 == null ? demoBewonerId : demoStrijderId,
        wanneer: begin.add(Duration(hours: 6 * i)),
      ),
  ];
}

const demoKlustypes = [
  HhKlustype(
    id: 'kt-tuin',
    naam: 'Tuin',
    icoon: 'yard',
    minLeeftijd: 13,
    volgorde: 1,
  ),
  HhKlustype(
    id: 'kt-schoonmaak',
    naam: 'Schoonmaak',
    icoon: 'cleaning_services',
    minLeeftijd: 16,
    volgorde: 2,
  ),
  HhKlustype(
    id: 'kt-boodschappen',
    naam: 'Boodschappen',
    icoon: 'shopping_cart',
    minLeeftijd: 10,
    volgorde: 3,
  ),
  HhKlustype(
    id: 'kt-dieren',
    naam: 'Dieren',
    icoon: 'pets',
    minLeeftijd: 10,
    volgorde: 4,
  ),
  HhKlustype(
    id: 'kt-computer',
    naam: 'Computer',
    icoon: 'computer',
    minLeeftijd: 13,
    volgorde: 5,
  ),
  HhKlustype(
    id: 'kt-hand',
    naam: 'Helpende hand',
    icoon: 'favorite_border',
    minLeeftijd: 10,
    volgorde: 6,
  ),
  HhKlustype(
    id: 'kt-klusje',
    naam: 'Kleine klusjes',
    icoon: 'handyman',
    minLeeftijd: 10,
    volgorde: 7,
  ),
  HhKlustype(
    id: 'kt-overig',
    naam: 'Overig',
    icoon: 'more_horiz',
    minLeeftijd: 13,
    volgorde: 8,
  ),
];

const demoGegevens = HhGegevens(
  id: demoBewonerId,
  naam: _bewonerNaam,
  telefoon: '0344-100001',
  adres: 'Prins Bernhardlaan 12',
  postcode: '4003 AB',
  plaats: 'Tiel',
  contactNaam: 'Dochter Jansen',
  contactTelefoon: '0612345678',
);

List<HhMelding> demoMeldingen(String ontvanger, DateTime nu) => [
  HhMelding(
    id: 'demo-m1',
    ontvangerId: ontvanger,
    soort: HhMeldingSoort.toegewezen,
    klusId: 'demo-vandaag',
    incidentId: '',
    titel: ontvanger == demoBewonerId
        ? 'Sanne helpt u vandaag'
        : 'Je helpt vandaag Mevrouw de Vries',
    tekst: 'Weekboodschappen bij de Jumbo, vandaag om 17:00.',
    gemaakt: nu.subtract(const Duration(minutes: 20)),
  ),
  HhMelding(
    id: 'demo-m2',
    ontvangerId: ontvanger,
    soort: HhMeldingSoort.nieuweKlus,
    klusId: 'demo-open-2',
    incidentId: '',
    titel: 'Nieuwe klus in de wijk',
    tekst: 'Heg knippen aan de voorkant.',
    gemaakt: nu.subtract(const Duration(hours: 3)),
    gelezenOp: nu.subtract(const Duration(hours: 2)),
  ),
];

List<HhBericht> demoBerichten(DateTime nu) => [
  HhBericht(
    id: 'demo-b1',
    klusId: 'demo-vandaag',
    afzenderId: demoStrijderId,
    helperId: demoStrijderId,
    tekst: 'Goedemiddag! Ik kom om 17:00. Heeft u een boodschappenlijstje?',
    soort: HhBerichtSoort.tekst,
    gemaakt: nu.subtract(const Duration(minutes: 40)),
    gelezenOp: nu.subtract(const Duration(minutes: 35)),
  ),
  HhBericht(
    id: 'demo-b2',
    klusId: 'demo-vandaag',
    afzenderId: demoBewonerId,
    helperId: demoStrijderId,
    tekst: 'Ja, het ligt op de keukentafel. Tot straks!',
    soort: HhBerichtSoort.tekst,
    gemaakt: nu.subtract(const Duration(minutes: 30)),
  ),
];

List<HhIncident> demoIncidenten(DateTime nu) => [
  HhIncident(
    id: 'demo-i1',
    soort: HhIncidentSoort.probleem,
    aangemaaktOp: nu.subtract(const Duration(hours: 2)),
    melderId: demoStrijderId,
    melderNaam: _strijderNaam,
    melderTelefoon: '06-10000003',
    klusId: 'demo-open-2',
    klusOmschrijving: 'Heg knippen aan de voorkant',
    omschrijving: 'Heggenschaar is bot, kan de klus niet afmaken.',
    afhandeling: '',
  ),
  HhIncident(
    id: 'demo-i2',
    soort: HhIncidentSoort.probleem,
    aangemaaktOp: nu.subtract(const Duration(days: 1)),
    melderId: demoBewonerId,
    melderNaam: _bewonerNaam,
    melderTelefoon: '0344-100001',
    klusId: '',
    klusOmschrijving: '',
    omschrijving: 'Kon de app niet openen.',
    afhandeling: 'Gebeld, opgelost.',
  ),
];

HhCoordinatorKlus _coordinatorKlus(HhKlus klus, DateTime nu) =>
    HhCoordinatorKlus(
      id: klus.id,
      status: klus.status,
      aangemaaktOp: nu.subtract(const Duration(days: 1)),
      klustypeNaam: klus.klustypeNaam,
      omschrijving: klus.omschrijving,
      adres: klus.adres,
      wanneerVan: klus.wanneerVan,
      wanneerTot: klus.wanneerTot,
      oudereId: demoBewonerId,
      oudereNaam: _bewonerNaam,
      oudereWijkId: _wijkId,
      oudereWijkNaam: _wijkNaam,
      toegewezenJongereId: klus.toegewezenJongereId,
      toegewezenJongereNaam: klus.jongereNaam,
    );

List<HhCoordinatorKlus> demoCoordinatorKlussen(DateTime nu) => [
  for (final klus in demoAlleKlussen(nu))
    if (klus.status != HhKlusStatus.afgerond) _coordinatorKlus(klus, nu),
];

const demoKandidaten = [
  HhKandidaat(
    id: demoStrijderId,
    naam: _strijderNaam,
    wijkId: _wijkId,
    wijkNaam: _wijkNaam,
    klussenAantal: 5,
  ),
  HhKandidaat(
    id: 'demo-strijder-2',
    naam: 'Yusuf el Amrani',
    wijkId: _wijkId,
    wijkNaam: _wijkNaam,
    klussenAantal: 2,
  ),
];

HhXpOverzicht demoXp() => HhXpOverzicht.vanJson({
  'xp_totaal': 605,
  'niveau': {'code': 'ervaren', 'naam': 'Ervaren'},
  'volgend': {
    'code': 'top',
    'naam': 'Top',
    'xp_nodig': 395,
    'klussen_nodig': 10,
    'sterren_nodig': 4.5,
    'xp_vanaf': 300,
    'xp_tot': 1000,
  },
  'klussen_aantal': 5,
  'sterren': 4.8,
  'badges': [
    {
      'code': 'eerste_klus',
      'naam': 'Eerste klus',
      'icoon': 'flag',
      'behaald_op': '2026-09-01 08:00:00.000Z',
    },
    {
      'code': 'vijf_klussen',
      'naam': '5 klussen',
      'icoon': 'handyman',
      'behaald_op': '2026-10-12 08:00:00.000Z',
    },
    {
      'code': 'tien_klussen',
      'naam': '10 klussen',
      'icoon': 'construction',
      'behaald_op': '',
    },
  ],
  'vertrouwen': [
    {
      'code': 'vog',
      'naam': 'VOG gezien',
      'icoon': 'shield',
      'datum': '2026-09-01 10:00:00.000Z',
      'geldig_tot': '2029-09-01 10:00:00.000Z',
      'verlopen': false,
    },
  ],
  'verdiensten': {
    'maanden': [
      {'maand': '2026-10', 'bedrag': 37.5, 'klussen': 4},
      {'maand': '2026-09', 'bedrag': 10, 'klussen': 1},
    ],
    'jaren': [
      {'jaar': '2026', 'bedrag': 47.5, 'klussen': 5},
    ],
    'totaal': 47.5,
  },
  'recensies': [],
});

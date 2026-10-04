// M14 — de vormen waarin het beheerpaneel met de hh_-collecties praat.
// Bewust plat en Nederlands: wat uit PocketBase komt wordt in de data-laag
// omgezet naar deze typen, zodat de schermen niets van PocketBase weten.

export type Klusstatus =
  | 'concept'
  | 'open'
  | 'geaccepteerd'
  | 'onderweg'
  | 'bezig'
  | 'afgerond'
  | 'geannuleerd'
  | 'probleem'

// B3 (K5): de familie-rol is weg uit de code. Oude accounts met rol
// "familie" kunnen op de server nog bestaan; die komen hier binnen als ''.
export type Rol = 'hulpvrager' | 'jongere' | 'coordinator'
export const ROLLEN: Rol[] = ['hulpvrager', 'jongere', 'coordinator']

export type Screeningstatus = 'nieuw' | 'in_behandeling' | 'goedgekeurd' | 'afgewezen'

export type Betaalstatus = 'open' | 'betaald' | 'mislukt' | 'terugbetaald'

export type Klusbron = 'app' | 'telefoon'

/** De ingelogde beheerder. Alleen rol coordinator komt hier ooit terecht. */
export type Coordinator = {
  id: string
  naam: string
  email: string
}

export type Klus = {
  id: string
  status: Klusstatus
  bron: Klusbron | ''
  omschrijving: string
  adres: string
  aangemaaktOp: string
  wanneerVan: string
  wanneerTot: string
  hulpvragerId: string
  hulpvragerNaam: string
  hulpvragerTelefoon: string
  /** Wijk van de oudere; voor het sorteren bij handmatig koppelen. */
  hulpvragerWijkNaam?: string
  jongereId: string
  jongereNaam: string
  klustypeId: string
  klustypeNaam: string
  bedragBruto: number
  vergoedingJongere: number
  commissie: number
}

export type Incident = {
  id: string
  gemeldOp: string
  // B5: 'signaal' = "nee" op de geheime vraag na de klus (zachter dan probleem)
  soort: 'nood' | 'probleem' | 'overig' | 'signaal' | ''
  omschrijving: string
  afhandeling: string
  melderId: string
  melderNaam: string
  melderTelefoon: string
  klusId: string
}

export type Profiel = {
  id: string
  gebruikerId: string
  naam: string
  email: string
  wijkNaam: string
  verificatiestatus: Screeningstatus | ''
  vogStatus: Screeningstatus | ''
  vogGeldigTot: string
  vogAangevraagdOp: string
  /** B2: dag waarop de meldkamer de VOG zag "JJJJ-MM-DD"; leeg = nog niet. */
  vogGezienOp: string
  ibanGeverifieerd: boolean
  iban: string
  overMij: string
  screeningNotitie: string
  bijgewerktOp: string
  /** Kant-en-klare url met bestandstoken; leeg als er geen bestand is. */
  documentFotoUrl: string
  /** B3: hh_users.ouder_toestemming_op (ISO); leeg = geen toestemming. */
  ouderToestemmingOp: string
  /** B3: AVP-vinkje van de ouder (hh_ouder_toestemming); null = geen rij. */
  ouderAvp: boolean | null
  /** B3: status in hh_ouder_toestemming ('' = geen rij). */
  ouderStatus: string
  /** ADRES: hh_users.adres_bron van de helper. */
  adresBron?: AdresBron
  /** B9: niveau-code (nieuw|ervaren|top|geverifieerd) en XP van de hook. */
  niveau?: string
  xpTotaal?: number
}

/** B9: een recensie (beoordeling met tekst) voor de meldkamer. */
export type Recensie = {
  id: string
  sterren: number
  tekst: string
  vanNaam: string
  naarNaam: string
  gemaaktOp: string
  verborgen: boolean
  verborgenReden: string
}

/** B9: wat er op een "Verklaring van inzet" stond (controle met de code). */
export type Verklaring = {
  code: string
  uitgegevenOp: string
  voornaam: string
  klussen: number
  uren: number
  periodeVan: string
  periodeTot: string
  niveau: string
  badges: { naam: string; datum: string }[]
  vertrouwen: { naam: string; datum: string }[]
}

export type Wijk = {
  id: string
  gemeente: string
  wijk: string
  postcodes: string[]
  actief: boolean
}

export type Klustype = {
  id: string
  naam: string
  icoon: string
  richtduur: number
  richtvergoeding: number
}

export type Gebruiker = {
  id: string
  naam: string
  email: string
  rol: Rol | ''
  telefoon: string
  geblokkeerd: boolean
  /** B2: hh_users.werkgebied_status; onbekend = de server vond het adres niet. */
  werkgebiedStatus: Werkgebiedstatus
  /** ADRES: hh_users.adres_bron ('' = van vóór ADRES). */
  adresBron?: AdresBron
}

/** ADRES: pdok = bevestigd; handmatig = uitzondering meldkamer; ongecontroleerd = PDOK was weg. */
export type AdresBron = '' | 'pdok' | 'handmatig' | 'ongecontroleerd'

export type Werkgebiedstatus = '' | 'binnen' | 'buiten' | 'onbekend'

export type Instelling = {
  id: string
  sleutel: string
  waarde: string
}

export type Betaling = {
  id: string
  klusId: string
  klusOmschrijving: string
  bedrag: number
  status: Betaalstatus | ''
  betaaldOp: string
}

export type Auditregel = {
  id: string
  gebeurdOp: string
  doorId: string
  doorNaam: string
  actie: string
  doelCollectie: string
  doelId: string
  detail: string
}

/** Een jongere die gekoppeld kan worden (D1, handmatig koppelen). */
export type Koppelkandidaat = {
  id: string
  naam: string
  wijkNaam: string
  klussenAantal: number
}

/** Een oudere die telefonisch belt (D1, telefonische aanmelding). */
export type Oudere = {
  id: string
  naam: string
  email: string
  telefoon: string
  adres: string
  postcode: string
  plaats: string
  wijkId: string
}

/** ADRES (4 okt): een adres zoals GET /api/hh/adres het van PDOK teruggeeft. */
export type AdresSuggestie = {
  straat: string
  huisnummer: string
  /** Huisletter en toevoeging zoals BAG: "A", "2", "a-01". */
  toevoeging: string
  /** Altijd "4001 MA". */
  postcode: string
  plaats: string
  gemeente: string
  lat: number
  lon: number
  /** Regel voor hh_users.adres: "Kerkstraat 1a-01". */
  adres: string
  /** Regel op het kaartje: "Kerkstraat 1, 4001 MA Tiel". */
  weergave: string
  binnenWerkgebied: boolean
}

export type AdresZoekUitkomst =
  | { soort: 'gevonden'; adressen: AdresSuggestie[] }
  | { soort: 'nietgevonden'; melding: string; keuzes: AdresSuggestie[] }
  | { soort: 'ongeldig'; melding: string }
  | { soort: 'limiet'; melding: string }
  | { soort: 'dienst' }

/**
 * Nieuwe telefonische oudere. ADRES: postcode + huisnummer (+ toevoeging) en
 * het daarmee bij PDOK gevonden adres ([gekozen]). Alleen als uitzondering
 * ([handmatig]) vrij getypt [adres] en [plaats], met een [wijkId].
 */
export type NieuweOudere = {
  naam: string
  telefoon: string
  email: string
  postcode: string
  huisnummer: string
  toevoeging: string
  gekozen: AdresSuggestie | null
  handmatig: boolean
  adres: string
  plaats: string
  wijkId: string
}

export type NieuweKlus = {
  hulpvragerId: string
  klustypeId: string
  omschrijving: string
  adres: string
  wanneerVan: string
  wanneerTot: string
}

/** Het besluit van de coordinator over een jongere (D2). */
export type Screeningbesluit = {
  verificatiestatus: 'goedgekeurd' | 'afgewezen'
  notitie: string
  vogStatus: Screeningstatus | ''
  vogGeldigTot: string
  ibanGeverifieerd: boolean
  /** B2: "JJJJ-MM-DD" of leeg (VOG nog niet gezien). */
  vogGezienOp: string
}

export type Auditactie = 'aanmaken' | 'wijzigen' | 'verwijderen'

// ---- B4: klussen nakijken (meldkamer keurt elke klus) ------------------

/** Wat het voorfilter van de server in de tekst vond (blokkeert niets). */
export type Markering = 'telefoon' | 'email' | 'link' | 'neelijst'

/** Een open klus die de meldkamer nog niet keurde. */
export type KlusNaTeKijken = {
  id: string
  aangemaaktOp: string
  bron: Klusbron | ''
  hulpvragerNaam: string
  klustypeNaam: string
  /** Vanaf welke leeftijd een helper hem mag doen (categorie of tijdregel). */
  minLeeftijd: number
  wanneerVan: string
  wanneerTot: string
  omschrijving: string
  markering: Markering[]
  /** Kant-en-klare url met bestandstoken; leeg als er geen foto is. */
  fotoUrl: string
}

export type Klusbesluit = { besluit: 'goedkeuren' } | { besluit: 'afkeuren'; reden: string }

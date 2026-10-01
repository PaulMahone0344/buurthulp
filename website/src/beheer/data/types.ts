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

export type Rol = 'hulpvrager' | 'jongere' | 'familie' | 'coordinator'

export type Screeningstatus = 'nieuw' | 'in_behandeling' | 'goedgekeurd' | 'afgewezen'

export type Betaalstatus = 'open' | 'betaald' | 'mislukt' | 'terugbetaald'

export type Klusbron = 'app' | 'telefoon' | 'familie'

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
  soort: 'nood' | 'probleem' | 'overig' | ''
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
  ibanGeverifieerd: boolean
  iban: string
  overMij: string
  screeningNotitie: string
  bijgewerktOp: string
  /** Kant-en-klare url met bestandstoken; leeg als er geen bestand is. */
  documentFotoUrl: string
  selfieUrl: string
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
}

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

export type NieuweOudere = {
  naam: string
  telefoon: string
  email: string
  adres: string
  postcode: string
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
}

export type Auditactie = 'aanmaken' | 'wijzigen' | 'verwijderen'

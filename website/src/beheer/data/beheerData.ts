// M14 — de ene ingang van het beheerpaneel naar de server. De schermen
// kennen alleen deze interface; in productie zit er PocketBase achter
// (pocketbaseBeheerData.ts), in de tests een nep-versie (fakeBeheerData.ts).
//
// Elke methode gooit bij een fout een BeheerFout met een Nederlandse melding
// die zo op het scherm kan.

import type {
  AdresZoekUitkomst,
  Auditregel,
  Betaling,
  Coordinator,
  Gebruiker,
  Incident,
  Instelling,
  Klus,
  Klusbesluit,
  KlusNaTeKijken,
  Klustype,
  Koppelkandidaat,
  NieuweKlus,
  NieuweOudere,
  Oudere,
  Profiel,
  Rol,
  Screeningbesluit,
  Wijk,
  Recensie,
  Verklaring,
} from './types'

export class BeheerFout extends Error {
  constructor(melding: string) {
    super(melding)
    this.name = 'BeheerFout'
  }
}

export type Inlogresultaat = { ok: true; coordinator: Coordinator } | { ok: false; melding: string }

export type NieuweWijk = Omit<Wijk, 'id'>
export type NieuwKlustype = Omit<Klustype, 'id'>

export interface BeheerData {
  // ---- toegang --------------------------------------------------------
  /** Inloggen als hh_users; elke andere rol dan coordinator wordt uitgelogd. */
  inloggen(email: string, wachtwoord: string): Promise<Inlogresultaat>
  /** De coordinator van een eerdere sessie, of null. */
  huidige(): Coordinator | null
  uitloggen(): void

  // ---- D1 meldkamer ---------------------------------------------------
  klussen(): Promise<Klus[]>
  incidenten(): Promise<Incident[]>
  incidentAfhandelen(id: string, afhandeling: string): Promise<void>
  /** Realtime op hh_klussen en hh_incidenten. Geeft de afmeld-functie terug. */
  abonneer(opWijziging: () => void): () => void
  zoekOuderen(zoek: string): Promise<Oudere[]>
  /** ADRES: GET /api/hh/adres (PDOK), dezelfde route als de app. */
  zoekAdres(postcode: string, huisnummer: string, toevoeging: string): Promise<AdresZoekUitkomst>
  maakOudere(oudere: NieuweOudere): Promise<Oudere>
  /** Klus met bron telefoon, status open; geeft het id terug. */
  maakTelefonischeKlus(klus: NieuweKlus): Promise<string>
  koppelkandidaten(): Promise<Koppelkandidaat[]>
  koppelen(klusId: string, jongereId: string): Promise<{ andereWijk: boolean }>
  vrijgeven(klusId: string, reden: string): Promise<void>
  annuleren(klusId: string, reden: string): Promise<void>

  // ---- B4 klussen nakijken --------------------------------------------
  /** Open klussen die nog niet gekeurd zijn, oudste eerst, foto met token. */
  klussenNaTeKijken(): Promise<KlusNaTeKijken[]>
  /** POST /api/hh/klussen/{id}/keuren (hh_klusplaatsen.pb.js). */
  keurKlus(klusId: string, besluit: Klusbesluit): Promise<void>

  // ---- D2 screening ---------------------------------------------------
  /** Profielen van alle jongeren, met bestandstoken in de foto-url's. */
  profielen(): Promise<Profiel[]>
  beoordeel(profielId: string, besluit: Screeningbesluit): Promise<void>
  /** B3: de ouder trok in; de meldkamer laat het kind de ouder opnieuw mailen. */
  ouderVrijgeven(helperId: string): Promise<void>

  // ---- D4 systeembeheer -----------------------------------------------
  wijken(): Promise<Wijk[]>
  maakWijk(wijk: NieuweWijk): Promise<void>
  wijzigWijk(id: string, wijk: Partial<NieuweWijk>): Promise<void>
  klustypes(): Promise<Klustype[]>
  maakKlustype(klustype: NieuwKlustype): Promise<void>
  wijzigKlustype(id: string, klustype: Partial<NieuwKlustype>): Promise<void>
  zoekGebruikers(zoek: string): Promise<Gebruiker[]>
  wijzigRol(id: string, rol: Rol): Promise<void>
  zetGeblokkeerd(id: string, geblokkeerd: boolean): Promise<void>
  instellingen(): Promise<Instelling[]>
  slaInstellingOp(sleutel: string, waarde: string): Promise<void>
  betalingen(): Promise<Betaling[]>
  auditlog(): Promise<Auditregel[]>

  // ---- B9 recensies en verklaringen ------------------------------------
  /** De nieuwste beoordelingen met tekst (ook verborgen), nieuwste eerst. */
  recensies(): Promise<Recensie[]>
  /** POST /api/hh/beoordelingen/{id}/verbergen; de hook rekent sterren en XP opnieuw. */
  verbergRecensie(id: string, verbergen: boolean, reden: string): Promise<void>
  /** GET /api/hh/verklaring/{code}; null als de code onbekend is. */
  zoekVerklaring(code: string): Promise<Verklaring | null>
}

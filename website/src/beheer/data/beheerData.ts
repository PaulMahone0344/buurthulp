// M14 — de ene ingang van het beheerpaneel naar de server. De schermen
// kennen alleen deze interface; in productie zit er PocketBase achter
// (pocketbaseBeheerData.ts), in de tests een nep-versie (fakeBeheerData.ts).
//
// Elke methode gooit bij een fout een BeheerFout met een Nederlandse melding
// die zo op het scherm kan.

import type {
  Auditregel,
  Betaling,
  Coordinator,
  Gebruiker,
  Incident,
  Instelling,
  Klus,
  Klustype,
  Koppelkandidaat,
  NieuweKlus,
  NieuweOudere,
  Oudere,
  Profiel,
  Rol,
  Screeningbesluit,
  Wijk,
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
  maakOudere(oudere: NieuweOudere): Promise<Oudere>
  /** Klus met bron telefoon, status open; geeft het id terug. */
  maakTelefonischeKlus(klus: NieuweKlus): Promise<string>
  koppelkandidaten(): Promise<Koppelkandidaat[]>
  koppelen(klusId: string, jongereId: string): Promise<{ andereWijk: boolean }>
  vrijgeven(klusId: string, reden: string): Promise<void>
  annuleren(klusId: string, reden: string): Promise<void>

  // ---- D2 screening ---------------------------------------------------
  /** Profielen van alle jongeren, met bestandstoken in de foto-url's. */
  profielen(): Promise<Profiel[]>
  beoordeel(profielId: string, besluit: Screeningbesluit): Promise<void>

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
}

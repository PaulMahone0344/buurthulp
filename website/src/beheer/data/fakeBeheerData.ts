// M14 — nep-data voor de tests van het beheerpaneel. Houdt alles in het
// geheugen en schrijft elke schrijvende aanroep in `aanroepen`, zodat een test
// kan nagaan wat het scherm naar de server zou sturen. Bootst de regels van
// de server na voor zover de schermen erop leunen (alleen coordinator, M10-
// en M6-routes, de bedragen van een telefonische klus).

import { BeheerFout, type BeheerData, type Inlogresultaat, type NieuweWijk, type NieuwKlustype } from './beheerData'
import { besluitBody } from './screening'
import { telefonischEmail, telefonischeKlusBody } from './telefonisch'
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

export type FakeAccount = { email: string; wachtwoord: string; rol: Rol; naam: string; id: string; geblokkeerd?: boolean }

export type FakeStand = {
  accounts: FakeAccount[]
  klussen: Klus[]
  incidenten: Incident[]
  ouderen: Oudere[]
  kandidaten: Koppelkandidaat[]
  profielen: Profiel[]
  wijken: Wijk[]
  klustypes: Klustype[]
  gebruikers: Gebruiker[]
  instellingen: Instelling[]
  betalingen: Betaling[]
  auditlog: Auditregel[]
}

export type Aanroep = { methode: string; args: unknown[] }

export function legeStand(): FakeStand {
  return {
    accounts: [],
    klussen: [],
    incidenten: [],
    ouderen: [],
    kandidaten: [],
    profielen: [],
    wijken: [],
    klustypes: [],
    gebruikers: [],
    instellingen: [],
    betalingen: [],
    auditlog: [],
  }
}

export class FakeBeheerData implements BeheerData {
  stand: FakeStand
  aanroepen: Aanroep[] = []
  ingelogd: Coordinator | null = null
  /** Laat de volgende schrijvende aanroep mislukken met deze melding. */
  volgendeFout = ''
  private luisteraars = new Set<() => void>()
  private teller = 0

  constructor(stand: Partial<FakeStand> = {}, ingelogd: Coordinator | null = null) {
    this.stand = { ...legeStand(), ...stand }
    this.ingelogd = ingelogd
  }

  /** Bootst een realtime-bericht van de server na. */
  meldWijziging() {
    for (const luisteraar of this.luisteraars) luisteraar()
  }

  get aantalAbonnees() {
    return this.luisteraars.size
  }

  private schrijf(methode: string, ...args: unknown[]) {
    this.aanroepen.push({ methode, args })
    if (!this.ingelogd) throw new BeheerFout('Dit mag alleen een coordinator.')
    if (this.volgendeFout) {
      const melding = this.volgendeFout
      this.volgendeFout = ''
      throw new BeheerFout(melding)
    }
  }

  private nieuwId(voorvoegsel: string) {
    this.teller += 1
    return `${voorvoegsel}${this.teller}`
  }

  private lees<T>(lijst: T[]): Promise<T[]> {
    if (!this.ingelogd) return Promise.reject(new BeheerFout('Dit mag alleen een coordinator.'))
    return Promise.resolve(structuredClone(lijst))
  }

  async inloggen(email: string, wachtwoord: string): Promise<Inlogresultaat> {
    const account = this.stand.accounts.find((a) => a.email === email.trim() && a.wachtwoord === wachtwoord)
    if (!account) return { ok: false, melding: 'Controleer je e-mail en wachtwoord.' }
    if (account.geblokkeerd) {
      return { ok: false, melding: 'Dit account is geblokkeerd. Neem contact op met de meldkamer.' }
    }
    if (account.rol !== 'coordinator') {
      this.ingelogd = null
      return { ok: false, melding: 'Dit beheerpaneel is alleen voor coordinatoren. Je bent weer uitgelogd.' }
    }
    this.ingelogd = { id: account.id, naam: account.naam, email: account.email }
    return { ok: true, coordinator: this.ingelogd }
  }

  huidige() {
    return this.ingelogd
  }

  uitloggen() {
    this.ingelogd = null
  }

  klussen() {
    return this.lees(this.stand.klussen)
  }

  incidenten() {
    return this.lees(this.stand.incidenten)
  }

  async incidentAfhandelen(id: string, afhandeling: string) {
    this.schrijf('incidentAfhandelen', id, afhandeling)
    const incident = this.stand.incidenten.find((i) => i.id === id)
    if (incident) incident.afhandeling = afhandeling.trim()
  }

  abonneer(opWijziging: () => void) {
    this.luisteraars.add(opWijziging)
    return () => {
      this.luisteraars.delete(opWijziging)
    }
  }

  async zoekOuderen(zoek: string) {
    const q = zoek.trim().toLowerCase()
    return (await this.lees(this.stand.ouderen)).filter(
      (o) => !q || o.naam.toLowerCase().includes(q) || o.telefoon.includes(q) || o.email.toLowerCase().includes(q),
    )
  }

  async maakOudere(oudere: NieuweOudere) {
    this.schrijf('maakOudere', oudere)
    const nieuw: Oudere = {
      id: this.nieuwId('o'),
      naam: oudere.naam.trim(),
      email: oudere.email.trim() || telefonischEmail(oudere.telefoon),
      telefoon: oudere.telefoon.trim(),
      adres: oudere.adres.trim(),
      postcode: oudere.postcode.trim(),
      plaats: oudere.plaats.trim(),
      wijkId: oudere.wijkId,
    }
    this.stand.ouderen.push(nieuw)
    return nieuw
  }

  async maakTelefonischeKlus(klus: NieuweKlus) {
    this.schrijf('maakTelefonischeKlus', klus)
    const klustype = this.stand.klustypes.find((t) => t.id === klus.klustypeId)
    if (!klustype) throw new BeheerFout('Dit klustype bestaat niet.')
    const body = telefonischeKlusBody(klus, klustype, this.ingelogd?.id ?? '')
    this.aanroepen.push({ methode: 'hh_klussen.create', args: [body] })
    const oudere = this.stand.ouderen.find((o) => o.id === klus.hulpvragerId)
    const id = this.nieuwId('k')
    this.stand.klussen.unshift({
      id,
      status: 'open',
      bron: 'telefoon',
      omschrijving: body.omschrijving,
      adres: body.adres,
      aangemaaktOp: new Date().toISOString(),
      wanneerVan: body.wanneer_van,
      wanneerTot: body.wanneer_tot,
      hulpvragerId: klus.hulpvragerId,
      hulpvragerNaam: oudere?.naam ?? '',
      hulpvragerTelefoon: oudere?.telefoon ?? '',
      jongereId: '',
      jongereNaam: '',
      klustypeId: klustype.id,
      klustypeNaam: klustype.naam,
      bedragBruto: body.bedrag_bruto,
      vergoedingJongere: body.vergoeding_jongere,
      commissie: body.commissie,
    })
    return id
  }

  koppelkandidaten() {
    return this.lees(this.stand.kandidaten)
  }

  async koppelen(klusId: string, jongereId: string) {
    this.schrijf('koppelen', klusId, jongereId)
    const klus = this.stand.klussen.find((k) => k.id === klusId)
    const jongere = this.stand.kandidaten.find((k) => k.id === jongereId)
    if (!klus) throw new BeheerFout('Deze klus bestaat niet meer.')
    if (klus.status !== 'open' || klus.jongereId) {
      throw new BeheerFout('Deze klus is niet meer open; hij is al aan iemand toegewezen.')
    }
    if (!jongere) throw new BeheerFout('Deze jongere bestaat niet.')
    klus.status = 'geaccepteerd'
    klus.jongereId = jongere.id
    klus.jongereNaam = jongere.naam
    return { andereWijk: !!klus.hulpvragerWijkNaam && klus.hulpvragerWijkNaam !== jongere.wijkNaam }
  }

  async vrijgeven(klusId: string, reden: string) {
    this.schrijf('vrijgeven', klusId, reden)
    const klus = this.stand.klussen.find((k) => k.id === klusId)
    if (!klus) throw new BeheerFout('Deze klus bestaat niet meer.')
    if (klus.status !== 'geaccepteerd' && klus.status !== 'onderweg') {
      throw new BeheerFout('Deze klus staat niet op geaccepteerd of onderweg en kan niet worden vrijgegeven.')
    }
    klus.status = 'open'
    klus.jongereId = ''
    klus.jongereNaam = ''
  }

  async annuleren(klusId: string, reden: string) {
    this.schrijf('annuleren', klusId, reden)
    const klus = this.stand.klussen.find((k) => k.id === klusId)
    if (!klus) throw new BeheerFout('Deze klus bestaat niet meer.')
    klus.status = 'geannuleerd'
  }

  profielen() {
    return this.lees(this.stand.profielen)
  }

  async beoordeel(profielId: string, besluit: Screeningbesluit) {
    this.schrijf('beoordeel', profielId, besluitBody(besluit))
    const profiel = this.stand.profielen.find((p) => p.id === profielId)
    if (!profiel) throw new BeheerFout('Dit profiel bestaat niet meer.')
    profiel.verificatiestatus = besluit.verificatiestatus
    profiel.screeningNotitie = besluit.notitie.trim()
    profiel.vogStatus = besluit.vogStatus
    profiel.vogGeldigTot = besluit.vogGeldigTot
    profiel.intakeOp = besluit.intakeOp
    profiel.ibanGeverifieerd = besluit.ibanGeverifieerd
    profiel.bijgewerktOp = new Date().toISOString()
  }

  wijken() {
    return this.lees(this.stand.wijken)
  }

  async maakWijk(wijk: NieuweWijk) {
    this.schrijf('maakWijk', wijk)
    this.stand.wijken.push({ id: this.nieuwId('w'), ...wijk })
  }

  async wijzigWijk(id: string, wijk: Partial<NieuweWijk>) {
    this.schrijf('wijzigWijk', id, wijk)
    const bestaand = this.stand.wijken.find((w) => w.id === id)
    if (bestaand) Object.assign(bestaand, wijk)
  }

  klustypes() {
    return this.lees(this.stand.klustypes)
  }

  async maakKlustype(klustype: NieuwKlustype) {
    this.schrijf('maakKlustype', klustype)
    this.stand.klustypes.push({ id: this.nieuwId('t'), ...klustype })
  }

  async wijzigKlustype(id: string, klustype: Partial<NieuwKlustype>) {
    this.schrijf('wijzigKlustype', id, klustype)
    const bestaand = this.stand.klustypes.find((t) => t.id === id)
    if (bestaand) Object.assign(bestaand, klustype)
  }

  async zoekGebruikers(zoek: string) {
    const q = zoek.trim().toLowerCase()
    return (await this.lees(this.stand.gebruikers)).filter(
      (g) => !q || g.naam.toLowerCase().includes(q) || g.email.toLowerCase().includes(q) || g.telefoon.includes(q),
    )
  }

  async wijzigRol(id: string, rol: Rol) {
    this.schrijf('wijzigRol', id, rol)
    const gebruiker = this.stand.gebruikers.find((g) => g.id === id)
    if (gebruiker) gebruiker.rol = rol
  }

  async zetGeblokkeerd(id: string, geblokkeerd: boolean) {
    this.schrijf('zetGeblokkeerd', id, geblokkeerd)
    const gebruiker = this.stand.gebruikers.find((g) => g.id === id)
    if (gebruiker) gebruiker.geblokkeerd = geblokkeerd
  }

  instellingen() {
    return this.lees(this.stand.instellingen)
  }

  async slaInstellingOp(sleutel: string, waarde: string) {
    this.schrijf('slaInstellingOp', sleutel, waarde)
    const bestaand = this.stand.instellingen.find((i) => i.sleutel === sleutel)
    if (bestaand) bestaand.waarde = waarde
    else this.stand.instellingen.push({ id: this.nieuwId('i'), sleutel, waarde })
  }

  betalingen() {
    return this.lees(this.stand.betalingen)
  }

  auditlog() {
    return this.lees(this.stand.auditlog)
  }
}

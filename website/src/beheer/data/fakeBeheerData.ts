// M14 — nep-data voor de tests van het beheerpaneel. Houdt alles in het
// geheugen en schrijft elke schrijvende aanroep in `aanroepen`, zodat een test
// kan nagaan wat het scherm naar de server zou sturen. Bootst de regels van
// de server na voor zover de schermen erop leunen (alleen coordinator, M10-
// en M6-routes, de bedragen van een telefonische klus).

import { BeheerFout, type BeheerData, type Inlogresultaat, type NieuweWijk, type NieuwKlustype } from './beheerData'
import { besluitBody } from './screening'
import { telefonischEmail, telefonischeKlusBody } from './telefonisch'
import type {
  AdresSuggestie,
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
  naTeKijken: KlusNaTeKijken[]
}

export type Aanroep = { methode: string; args: unknown[] }

const nepAdres = (straat: string, nr: string, toev: string, postcode: string, plaats: string, binnen: boolean): AdresSuggestie => {
  const regel = `${straat} ${nr}${toev}`
  return {
    straat,
    huisnummer: nr,
    toevoeging: toev,
    postcode,
    plaats,
    gemeente: plaats,
    lat: 51.88,
    lon: 5.43,
    adres: regel,
    weergave: `${regel}, ${postcode} ${plaats}`,
    binnenWerkgebied: binnen,
  }
}

/** ADRES: de adressen die de nep-PDOK kent (zelfde als de app-fake). */
const NEP_ADRESSEN: Record<string, AdresSuggestie[]> = {
  '4001MA:1': [nepAdres('Kerkstraat', '1', '', '4001 MA', 'Tiel', true)],
  '4001JS:1': [nepAdres('Nieuwe Tielseweg', '1', 'a-01', '4001 JS', 'Tiel', true), nepAdres('Nieuwe Tielseweg', '1', 'a-02', '4001 JS', 'Tiel', true)],
  '1012JS:1': [nepAdres('Dam', '1', '', '1012 JS', 'Amsterdam', false)],
}

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
    naTeKijken: [],
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

  /** ADRES: elke opzoeking, voor tests ("geen dubbele verzoeken"). */
  adresVerzoeken: { postcode: string; huisnummer: string; toevoeging: string }[] = []

  async zoekAdres(postcode: string, huisnummer: string, toevoeging: string): Promise<AdresZoekUitkomst> {
    this.adresVerzoeken.push({ postcode, huisnummer, toevoeging })
    const alle = NEP_ADRESSEN[`${postcode.replace(/\s/g, '').toUpperCase()}:${huisnummer}`] ?? []
    if (!alle.length) {
      return { soort: 'nietgevonden', melding: 'We vinden dit adres niet. Klopt de postcode en het huisnummer?', keuzes: [] }
    }
    const s = (t: string) => t.toLowerCase().replace(/[^a-z0-9]/g, '')
    const passend = toevoeging.trim() ? alle.filter((a) => s(a.toevoeging) === s(toevoeging)) : alle
    if (!passend.length) {
      return { soort: 'nietgevonden', melding: 'Deze toevoeging kennen we niet op dit huisnummer. Kies er een uit de lijst.', keuzes: alle }
    }
    return { soort: 'gevonden', adressen: passend }
  }

  async maakOudere(oudere: NieuweOudere) {
    this.schrijf('maakOudere', oudere)
    const a = oudere.handmatig ? null : oudere.gekozen
    const nieuw: Oudere = {
      id: this.nieuwId('o'),
      naam: oudere.naam.trim(),
      email: oudere.email.trim() || telefonischEmail(oudere.telefoon),
      telefoon: oudere.telefoon.trim(),
      adres: a ? a.adres : oudere.adres.trim(),
      postcode: a ? a.postcode : oudere.postcode.trim(),
      plaats: a ? a.plaats : oudere.plaats.trim(),
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

  klussenNaTeKijken() {
    return this.lees(this.stand.naTeKijken)
  }

  /** Zoals de keur-route: alleen een open, ongekeurde klus; afkeuren met een reden. */
  async keurKlus(klusId: string, besluit: Klusbesluit) {
    this.schrijf('keurKlus', klusId, besluit)
    const klus = this.stand.naTeKijken.find((k) => k.id === klusId)
    if (!klus) throw new BeheerFout('Deze klus staat niet meer open; keuren kan niet meer.')
    if (besluit.besluit === 'afkeuren' && besluit.reden.trim().length < 5) {
      throw new BeheerFout('Vul een reden in van 5 tot 300 tekens; de bewoner krijgt hem te zien.')
    }
    this.stand.naTeKijken = this.stand.naTeKijken.filter((k) => k.id !== klusId)
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
    profiel.vogGezienOp = besluit.vogGezienOp
    profiel.ibanGeverifieerd = besluit.ibanGeverifieerd
    profiel.bijgewerktOp = new Date().toISOString()
  }

  async ouderVrijgeven(helperId: string) {
    this.schrijf('ouderVrijgeven', helperId)
    const profiel = this.stand.profielen.find((p) => p.gebruikerId === helperId)
    if (!profiel || profiel.ouderStatus !== 'ingetrokken') {
      throw new BeheerFout('De toestemming is niet ingetrokken; er is niets vrij te geven.')
    }
    profiel.ouderStatus = 'vrijgegeven'
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

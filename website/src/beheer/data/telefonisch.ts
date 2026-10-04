// M14 — de telefonische aanmelding (D1). Een oudere belt de meldkamer; de
// coordinator zoekt hem op of maakt hem aan en zet de klus erin. Daarna loopt
// de klus EXACT zoals een klus uit de app: zelfde velden, zelfde status open,
// zelfde bedragen. Alleen bron (telefoon) en geplaatst_door (de coordinator)
// verschillen.

import type { AdresSuggestie, AdresZoekUitkomst, Klustype, NieuweKlus, NieuweOudere } from './types'

/** PocketBase eist een e-mail op hh_users; zonder e-mail maken we er een. */
export const TELEFONISCH_DOMEIN = 'telefonisch.heitjehulp.invalid'

export function alleenCijfers(telefoon: string): string {
  return telefoon.replace(/\D/g, '')
}

export function telefonischEmail(telefoon: string): string {
  return `${alleenCijfers(telefoon)}@${TELEFONISCH_DOMEIN}`
}

/** Een wachtwoord dat niemand kent; de oudere logt (nog) niet zelf in. */
export function willekeurigWachtwoord(): string {
  const bytes = new Uint8Array(18)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
}

/** Een postcode tijdens het typen: hooguit 4 cijfers, dan 2 hoofdletters met een spatie. */
export function postcodeOpmaak(invoer: string): string {
  let cijfers = ''
  let letters = ''
  for (const teken of invoer.toUpperCase()) {
    if (cijfers.length < 4) {
      if (/\d/.test(teken)) cijfers += teken
    } else if (letters.length < 2 && /[A-Z]/.test(teken)) {
      letters += teken
    }
  }
  return letters ? `${cijfers} ${letters}` : cijfers
}

const POSTCODE = /^[1-9]\d{3} ?[A-Za-z]{2}$/
const HUISNUMMER = /^\d{1,5}$/

/** Genoeg ingevuld om het adres op te zoeken (zelfde regels als de server). */
export function kanAdresZoeken(postcode: string, huisnummer: string, toevoeging: string): boolean {
  return (
    POSTCODE.test(postcode.trim()) &&
    HUISNUMMER.test(huisnummer.trim()) &&
    Number(huisnummer) > 0 &&
    toevoeging.trim().length <= 6
  )
}

/** De klusregel zoals de app hem maakt ("Kerkstraat 1, 4001 MA Tiel"): dan krijgt de klus het PDOK-punt van de oudere. */
export function klusAdresVoor(o: { adres: string; postcode: string; plaats: string }): string {
  const achter = [o.postcode.trim(), o.plaats.trim()].filter(Boolean).join(' ')
  return [o.adres.trim(), achter].filter(Boolean).join(', ')
}

/** Wat er mis is met de gegevens van een nieuwe oudere, of "" als het klopt. */
export function controleerOudere(oudere: NieuweOudere): string {
  if (!oudere.naam.trim()) return 'Vul de naam van de oudere in.'
  if (alleenCijfers(oudere.telefoon).length < 10) return 'Vul een telefoonnummer van tien cijfers in.'
  if (oudere.handmatig) {
    if (!oudere.adres.trim()) return 'Vul straat en huisnummer in.'
    if (!oudere.plaats.trim()) return 'Vul de plaats in.'
    if (!oudere.wijkId) return 'Kies de wijk van de oudere (zonder controle bepaalt de server die niet).'
    return ''
  }
  if (!oudere.gekozen) return 'Zoek het adres op met postcode en huisnummer, of kies "adres handmatig".'
  return ''
}

/** De body voor hh_users bij een nieuwe oudere. */
export function nieuweOudereBody(oudere: NieuweOudere, wachtwoord: string) {
  const email = oudere.email.trim() || telefonischEmail(oudere.telefoon)
  const basis = {
    email,
    emailVisibility: false,
    password: wachtwoord,
    passwordConfirm: wachtwoord,
    rol: 'hulpvrager',
    naam: oudere.naam.trim(),
    telefoon: oudere.telefoon.trim(),
    taal: 'nl',
  }
  if (oudere.handmatig) {
    // Uitzondering: geen PDOK, markering voor de meldkamer, wijk zoals gekozen.
    return {
      ...basis,
      adres: oudere.adres.trim(),
      postcode: oudere.postcode.trim(),
      huisnummer: oudere.huisnummer.trim(),
      toevoeging: oudere.toevoeging.trim(),
      plaats: oudere.plaats.trim(),
      adres_bron: 'handmatig',
      wijk: oudere.wijkId,
    }
  }
  const a = oudere.gekozen as AdresSuggestie
  // De server zoekt het adres zelf ook op en bepaalt de wijk uit het punt.
  return {
    ...basis,
    postcode: a.postcode,
    huisnummer: a.huisnummer,
    toevoeging: a.toevoeging,
    adres: a.adres,
    plaats: a.plaats,
    ...(oudere.wijkId ? { wijk: oudere.wijkId } : {}),
  }
}

/** Het antwoord van GET /api/hh/adres als uitkomst (zie de app: PocketBaseAdresGateway). */
export function leesAdresAntwoord(status: number, body: unknown): AdresZoekUitkomst {
  const data = (body ?? {}) as { gevonden?: unknown; reden?: unknown; melding?: unknown; adressen?: unknown }
  const melding = typeof data.melding === 'string' ? data.melding : ''
  if (status === 429) return { soort: 'limiet', melding }
  if (status === 400 && melding) return { soort: 'ongeldig', melding }
  if (status !== 200) return { soort: 'dienst' }
  const adressen = Array.isArray(data.adressen) ? data.adressen.map(naarAdres) : []
  if (data.gevonden === true && adressen.length) return { soort: 'gevonden', adressen }
  if (data.reden === 'dienst') return { soort: 'dienst' }
  return { soort: 'nietgevonden', melding, keuzes: adressen }
}

function naarAdres(r: unknown): AdresSuggestie {
  const a = (r ?? {}) as Record<string, unknown>
  const t = (v: unknown) => (v == null ? '' : String(v))
  const n = (v: unknown) => (typeof v === 'number' ? v : Number(v) || 0)
  return {
    straat: t(a.straat),
    huisnummer: t(a.huisnummer),
    toevoeging: t(a.toevoeging),
    postcode: t(a.postcode),
    plaats: t(a.plaats),
    gemeente: t(a.gemeente),
    lat: n(a.lat),
    lon: n(a.lon),
    adres: t(a.adres),
    weergave: t(a.weergave),
    binnenWerkgebied: a.binnen_werkgebied === true,
  }
}

/** Wat er mis is met een telefonische klus, of "" als het klopt. */
export function controleerKlus(klus: NieuweKlus): string {
  if (!klus.hulpvragerId) return 'Kies eerst de oudere.'
  if (!klus.klustypeId) return 'Kies wat voor klus het is.'
  if (!klus.adres.trim()) return 'Vul het adres in.'
  if (!klus.wanneerVan || !klus.wanneerTot) return 'Vul in wanneer de klus is.'
  if (new Date(klus.wanneerTot).getTime() <= new Date(klus.wanneerVan).getTime()) {
    return 'Het einde moet na het begin liggen.'
  }
  return ''
}

/**
 * De body voor hh_klussen. Bedragen uit de richtvergoeding van het
 * klustype, zonder commissie (zelfde regel als de app, M4 OPEN-PUNT 17).
 */
export function telefonischeKlusBody(klus: NieuweKlus, klustype: Klustype, coordinatorId: string) {
  const richt = Math.max(0, Math.round(klustype.richtvergoeding || 0))
  return {
    hulpvrager: klus.hulpvragerId,
    geplaatst_door: coordinatorId,
    klustype: klus.klustypeId,
    omschrijving: klus.omschrijving.trim(),
    adres: klus.adres.trim(),
    wanneer_van: new Date(klus.wanneerVan).toISOString(),
    wanneer_tot: new Date(klus.wanneerTot).toISOString(),
    status: 'open',
    bedrag_bruto: richt,
    vergoeding_jongere: richt,
    commissie: 0,
    bron: 'telefoon',
  }
}

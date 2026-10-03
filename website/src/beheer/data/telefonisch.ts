// M14 — de telefonische aanmelding (D1). Een oudere belt de meldkamer; de
// coordinator zoekt hem op of maakt hem aan en zet de klus erin. Daarna loopt
// de klus EXACT zoals een klus uit de app: zelfde velden, zelfde status open,
// zelfde bedragen. Alleen bron (telefoon) en geplaatst_door (de coordinator)
// verschillen.

import type { Klustype, NieuweKlus, NieuweOudere } from './types'

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

/** Wat er mis is met de gegevens van een nieuwe oudere, of "" als het klopt. */
export function controleerOudere(oudere: NieuweOudere): string {
  if (!oudere.naam.trim()) return 'Vul de naam van de oudere in.'
  if (alleenCijfers(oudere.telefoon).length < 10) return 'Vul een telefoonnummer van tien cijfers in.'
  if (!oudere.wijkId) return 'Kies de wijk van de oudere.'
  return ''
}

/** De body voor hh_users bij een nieuwe oudere. */
export function nieuweOudereBody(oudere: NieuweOudere, wachtwoord: string) {
  const email = oudere.email.trim() || telefonischEmail(oudere.telefoon)
  return {
    email,
    emailVisibility: false,
    password: wachtwoord,
    passwordConfirm: wachtwoord,
    rol: 'hulpvrager',
    naam: oudere.naam.trim(),
    telefoon: oudere.telefoon.trim(),
    adres: oudere.adres.trim(),
    postcode: oudere.postcode.trim(),
    plaats: oudere.plaats.trim(),
    wijk: oudere.wijkId,
    taal: 'nl',
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

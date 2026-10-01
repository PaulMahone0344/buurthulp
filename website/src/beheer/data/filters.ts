// M14 — filters en sorteringen van het beheerpaneel. Pure functies; de
// filterwaarden komen uit de URL (zie navigatie.ts).

import type { Auditregel, Incident, Klus, Klusstatus, Koppelkandidaat } from './types'

/** De vier filters uit D1, plus "alle". */
export type Hulpvraaggroep = 'nieuw' | 'gematcht' | 'in_uitvoering' | 'afgerond'
export type Hulpvraagfilter = Hulpvraaggroep | 'alle'
export const HULPVRAAGFILTERS: Hulpvraagfilter[] = ['alle', 'nieuw', 'gematcht', 'in_uitvoering', 'afgerond']

export type Incidentfilter = 'open' | 'afgehandeld' | 'alle'
export const INCIDENTFILTERS: Incidentfilter[] = ['open', 'afgehandeld', 'alle']

const GROEP: Record<Klusstatus, Hulpvraaggroep> = {
  concept: 'nieuw',
  open: 'nieuw',
  geaccepteerd: 'gematcht',
  onderweg: 'in_uitvoering',
  bezig: 'in_uitvoering',
  afgerond: 'afgerond',
  geannuleerd: 'afgerond',
  probleem: 'afgerond',
}

export function hulpvraagGroep(status: Klusstatus): Hulpvraaggroep {
  return GROEP[status]
}

export function isHulpvraagfilter(waarde: string | undefined): waarde is Hulpvraagfilter {
  return HULPVRAAGFILTERS.includes(waarde as Hulpvraagfilter)
}

export function isIncidentfilter(waarde: string | undefined): waarde is Incidentfilter {
  return INCIDENTFILTERS.includes(waarde as Incidentfilter)
}

export function filterKlussen(klussen: Klus[], filter: Hulpvraagfilter): Klus[] {
  if (filter === 'alle') return klussen
  return klussen.filter((k) => hulpvraagGroep(k.status) === filter)
}

/** Nieuwste melding bovenaan; de invoer blijft ongemoeid. */
export function sorteerIncidenten(incidenten: Incident[]): Incident[] {
  return [...incidenten].sort((a, b) => b.gemeldOp.localeCompare(a.gemeldOp))
}

export function filterIncidenten(incidenten: Incident[], filter: Incidentfilter): Incident[] {
  if (filter === 'alle') return incidenten
  const open = filter === 'open'
  return incidenten.filter((i) => (i.afhandeling.trim() === '') === open)
}

/**
 * Verlopen = de geldig-tot-datum ligt vóór vandaag (UTC, zoals de server).
 * De dag zelf telt nog mee. Geen datum = niet verlopen.
 */
export function isVogVerlopen(vogGeldigTot: string, nu: Date): boolean {
  const geldigTot = vogGeldigTot.slice(0, 10)
  if (!geldigTot) return false
  return geldigTot < nu.toISOString().slice(0, 10)
}

/** Jongeren uit de wijk van de oudere eerst, daarbinnen op naam. */
export function sorteerKoppelkandidaten(kandidaten: Koppelkandidaat[], wijkNaam: string): Koppelkandidaat[] {
  return [...kandidaten].sort((a, b) => {
    const aEigen = a.wijkNaam === wijkNaam ? 0 : 1
    const bEigen = b.wijkNaam === wijkNaam ? 0 : 1
    if (aEigen !== bEigen) return aEigen - bEigen
    return a.naam.localeCompare(b.naam, 'nl')
  })
}

export type Auditfilter = { actie: string; persoon: string }

export function filterAuditlog(regels: Auditregel[], filter: Auditfilter): Auditregel[] {
  const persoon = filter.persoon.trim().toLowerCase()
  return regels.filter(
    (r) =>
      (!filter.actie || r.actie === filter.actie) &&
      (!persoon || r.doorNaam.toLowerCase().includes(persoon)),
  )
}

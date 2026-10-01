// M14 — de tellingen achter de tegels van D1 (meldkamer) en D2 (screening),
// plus het VOG-signaal. Pure functies: de schermen geven de lijsten en "nu"
// mee, zodat de tests de klok vast kunnen zetten.

import { dagenTussen, nlDag, nlMaand } from './tijd'
import type { Incident, Klus, Klusstatus, Profiel } from './types'

/** Na deze tijd zonder jongere telt een open hulpvraag als "zonder match". */
export const ZONDER_MATCH_NA_MS = 2 * 60 * 60 * 1000

/** Een VOG die binnen zoveel dagen verloopt, krijgt een signaal. */
export const VOG_SIGNAAL_DAGEN = 60

/** Statussen die op de dag zelf nog moeten gebeuren of bezig zijn. */
const GEPLAND: Klusstatus[] = ['open', 'geaccepteerd', 'onderweg', 'bezig']

export type MeldkamerTegels = {
  open: number
  zonderMatch: number
  vandaagGepland: number
  nuBezig: number
  incidentenOpen: number
}

export type ScreeningTegels = {
  wachtend: number
  vogLoopt: number
  afgewezenDezeMaand: number
}

export function isIncidentOpen(incident: Incident): boolean {
  return incident.afhandeling.trim() === ''
}

export function isZonderMatch(klus: Klus, nu: Date): boolean {
  if (klus.status !== 'open' || klus.jongereId) return false
  const geplaatst = new Date(klus.aangemaaktOp).getTime()
  if (Number.isNaN(geplaatst)) return false
  return nu.getTime() - geplaatst > ZONDER_MATCH_NA_MS
}

export function meldkamerTegels(klussen: Klus[], incidenten: Incident[], nu: Date): MeldkamerTegels {
  const vandaag = nlDag(nu)
  return {
    open: klussen.filter((k) => k.status === 'open').length,
    zonderMatch: klussen.filter((k) => isZonderMatch(k, nu)).length,
    vandaagGepland: klussen.filter(
      (k) => GEPLAND.includes(k.status) && k.wanneerVan !== '' && nlDag(k.wanneerVan) === vandaag,
    ).length,
    nuBezig: klussen.filter((k) => k.status === 'bezig').length,
    incidentenOpen: incidenten.filter(isIncidentOpen).length,
  }
}

export function screeningTegels(profielen: Profiel[], nu: Date): ScreeningTegels {
  const dezeMaand = nlMaand(nu)
  return {
    wachtend: profielen.filter((p) => p.verificatiestatus === 'in_behandeling').length,
    vogLoopt: profielen.filter((p) => p.vogStatus === 'in_behandeling').length,
    afgewezenDezeMaand: profielen.filter(
      (p) => p.verificatiestatus === 'afgewezen' && nlMaand(p.bijgewerktOp) === dezeMaand,
    ).length,
  }
}

export type VogSignaal = '' | 'binnenkort' | 'verlopen'

/**
 * "verlopen" als de geldig-tot-datum vóór vandaag ligt, "binnenkort" als hij
 * binnen 60 dagen valt, anders niets. De datum zelf telt nog als geldig.
 */
export function vogSignaal(geldigTot: string, nu: Date): VogSignaal {
  const tot = nlDag(geldigTot.length === 10 ? `${geldigTot}T12:00:00.000Z` : geldigTot)
  if (!tot) return ''
  const over = dagenTussen(nlDag(nu), tot)
  if (over < 0) return 'verlopen'
  if (over <= VOG_SIGNAAL_DAGEN) return 'binnenkort'
  return ''
}

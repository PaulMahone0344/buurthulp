// M14 — vaste woorden van het beheerpaneel. De statusnamen zijn dezelfde als
// in de app (app/lib/l10n/teksten_klussen_nl.dart), zodat een coordinator op
// web en telefoon hetzelfde woord ziet.

import type { Hulpvraagfilter, Incidentfilter } from './data/filters'
import type { Klusstatus, Rol, Screeningstatus } from './data/types'

export const STATUS_LABEL: Record<Klusstatus, string> = {
  concept: 'Concept',
  open: 'Open',
  geaccepteerd: 'Aangenomen',
  onderweg: 'Onderweg',
  bezig: 'Bezig',
  afgerond: 'Afgerond',
  geannuleerd: 'Geannuleerd',
  probleem: 'Probleem',
}

export const HULPVRAAGFILTER_LABEL: Record<Hulpvraagfilter, string> = {
  alle: 'Alle',
  nieuw: 'Nieuw',
  gematcht: 'Gematcht',
  in_uitvoering: 'In uitvoering',
  afgerond: 'Afgerond',
}

export const INCIDENTFILTER_LABEL: Record<Incidentfilter, string> = {
  open: 'Open',
  afgehandeld: 'Afgehandeld',
  alle: 'Alle',
}

export const SOORT_LABEL: Record<string, string> = {
  nood: 'Noodmelding',
  probleem: 'Probleem',
  overig: 'Overig',
}

export const ROL_LABEL: Record<Rol, string> = {
  hulpvrager: 'Oudere',
  jongere: 'Jongere',
  familie: 'Familie',
  coordinator: 'Coordinator',
}

export const SCREENING_LABEL: Record<Screeningstatus | '', string> = {
  '': 'Nieuw',
  nieuw: 'Nieuw',
  in_behandeling: 'In behandeling',
  goedgekeurd: 'Goedgekeurd',
  afgewezen: 'Afgewezen',
}

export const ONDERDEEL_LABEL = {
  meldkamer: 'Meldkamer',
  screening: 'Screening',
  systeem: 'Systeembeheer',
} as const

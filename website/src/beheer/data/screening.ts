// M14 — het besluit over een jongere (D2). Goedkeuren en afkeuren gaan
// altijd met een notitie: wie later kijkt, moet kunnen zien waarom.

import type { Screeningbesluit } from './types'

export function controleerBesluit(besluit: Screeningbesluit): string {
  if (!besluit.notitie.trim()) return 'Schrijf eerst een notitie bij je besluit.'
  if (besluit.notitie.trim().length > 1000) return 'De notitie mag hoogstens 1000 tekens zijn.'
  if (
    besluit.verificatiestatus === 'goedgekeurd' &&
    besluit.vogStatus === 'goedgekeurd' &&
    !besluit.vogGeldigTot
  ) {
    return 'Vul in tot wanneer de VOG geldig is.'
  }
  return ''
}

/** De body voor hh_profielen (alleen de coordinator mag deze velden zetten). */
export function besluitBody(besluit: Screeningbesluit) {
  return {
    verificatiestatus: besluit.verificatiestatus,
    screening_notitie: besluit.notitie.trim(),
    vog_status: besluit.vogStatus,
    vog_geldig_tot: besluit.vogGeldigTot ? `${besluit.vogGeldigTot.slice(0, 10)} 12:00:00.000Z` : '',
    iban_geverifieerd: besluit.ibanGeverifieerd,
    intake_op: besluit.intakeOp ? `${besluit.intakeOp.slice(0, 10)} 12:00:00.000Z` : '',
  }
}

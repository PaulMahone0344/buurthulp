// B11 — partnercodes (jongerenwerk-organisaties). Zelfde regel als de server
// (backend/pb_hooks/hh_meldkamer_hulp.js normaliseerCode).

export const MELDING_PARTNERCODE = 'Een code heeft 3 tot 20 tekens: letters, cijfers en een streepje.'

/** "tiel jw" -> "TIELJW"; ongeldig -> "". */
export function partnerCode(invoer: string): string {
  const c = invoer.trim().toUpperCase().replace(/\s+/g, '')
  return /^[A-Z0-9-]{3,20}$/.test(c) ? c : ''
}

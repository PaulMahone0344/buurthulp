// B3 — IBAN-controle voor de ouder-pagina. Precies zoals de server
// (backend/pb_hooks/hh_ouder_hulp.js) en de app (M3): NL, 18 tekens,
// NL + 2 cijfers + 4 letters + 10 cijfers, mod-97 = 1.

export function normaliseerIban(invoer: string): string {
  return invoer.replace(/\s+/g, '').toUpperCase()
}

export function isGeldigNlIban(invoer: string): boolean {
  const iban = normaliseerIban(invoer)
  if (!/^NL\d{2}[A-Z]{4}\d{10}$/.test(iban)) return false
  const herschikt = iban.slice(4) + iban.slice(0, 4)
  let rest = 0
  for (const teken of herschikt) {
    const stuk = /[A-Z]/.test(teken) ? String(teken.charCodeAt(0) - 55) : teken
    for (const cijfer of stuk) rest = (rest * 10 + Number(cijfer)) % 97
  }
  return rest === 1
}

/** Groepjes van vier: NL91 ABNA 0417 1643 00. */
export function toonIban(iban: string): string {
  return normaliseerIban(iban).replace(/(.{4})(?=.)/g, '$1 ')
}

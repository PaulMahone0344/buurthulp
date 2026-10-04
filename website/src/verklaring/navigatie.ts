// B9 — de pagina van een "Verklaring van inzet": #/verklaring/<code> (de app
// opent hem om te printen of te delen) en #/verklaring om een code in te
// vullen. De code staat achter de # en gaat dus nooit mee naar een server.

const BASIS = '#/verklaring'

export function isVerklaringHash(hash: string): boolean {
  return hash === BASIS || hash.startsWith(`${BASIS}/`) || hash.startsWith(`${BASIS}?`)
}

/** "abcde fgh23" -> "ABCDE-FGH23"; alles wat geen geldige code is: leeg. */
export function maakCode(ruw: string): string {
  const t = ruw.toUpperCase().replace(/[^A-Z0-9]/g, '')
  if (!/^[A-HJ-NP-Z2-9]{10}$/.test(t)) return ''
  return `${t.slice(0, 5)}-${t.slice(5)}`
}

/** De code uit de hash, of leeg. */
export function leesCode(hash: string): string {
  if (!isVerklaringHash(hash)) return ''
  const rest = decodeURIComponent(hash.slice(BASIS.length).replace(/^\//, '').split('?')[0] ?? '')
  return maakCode(rest)
}

export function verklaringHash(code: string): string {
  return `${BASIS}/${code}`
}

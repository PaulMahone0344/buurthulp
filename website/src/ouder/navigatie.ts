// B3 — de ouder-pagina staat op #/ouder. De link in de mail is
// https://heitjehulp.nl/#/ouder?t=<token>: de token staat achter de # en gaat
// dus nooit mee naar een server (geen logregel, geen Referer).

const BASIS = '#/ouder'

export function isOuderHash(hash: string): boolean {
  return hash === BASIS || hash.startsWith(`${BASIS}?`) || hash.startsWith(`${BASIS}/`)
}

/** De token uit de link; alleen letters en cijfers, anders leeg. */
export function leesToken(hash: string): string {
  if (!isOuderHash(hash)) return ''
  const zoek = hash.split('?')[1] ?? ''
  const token = new URLSearchParams(zoek).get('t') ?? ''
  return /^[A-Za-z0-9]{1,100}$/.test(token) ? token : ''
}

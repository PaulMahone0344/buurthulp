// B5 — de ouder keurt per klus (besluit punt 1). De link in de mail is
// https://heitjehulp.nl/#/ouder/klus?token=<token>: de token staat achter de #
// en gaat dus nooit mee naar een server (geen logregel, geen Referer).

const BASIS = '#/ouder/klus'

export function isOuderKlusHash(hash: string): boolean {
  return hash === BASIS || hash.startsWith(`${BASIS}?`)
}

/** De token uit de link; alleen letters en cijfers, anders leeg. */
export function leesKlusToken(hash: string): string {
  if (!isOuderKlusHash(hash)) return ''
  const zoek = hash.split('?')[1] ?? ''
  const token = new URLSearchParams(zoek).get('token') ?? ''
  return /^[A-Za-z0-9]{20,100}$/.test(token) ? token : ''
}

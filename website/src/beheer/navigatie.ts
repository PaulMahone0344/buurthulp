// M14 — waar ben je in het beheerpaneel. Alles staat in de hash van de URL,
// zodat verversen, terug-knop en een gedeelde link op dezelfde plek uitkomen:
//   #/beheer/<onderdeel>?filter=nieuw&zoek=jan
// Geen router-pakket: de site heeft er geen en het paneel heeft er geen nodig.

export type Onderdeel = 'meldkamer' | 'screening' | 'systeem'
export const ONDERDELEN: Onderdeel[] = ['meldkamer', 'screening', 'systeem']

export type Locatie = {
  onderdeel: Onderdeel
  filters: Record<string, string>
}

const BASIS = '#/beheer'

export function isBeheerHash(hash: string): boolean {
  return hash === BASIS || hash.startsWith(`${BASIS}/`) || hash.startsWith(`${BASIS}?`)
}

export function leesLocatie(hash: string): Locatie {
  const rest = isBeheerHash(hash) ? hash.slice(BASIS.length) : ''
  const [pad, zoek = ''] = rest.split('?')
  const naam = pad.replace(/^\//, '').split('/')[0]
  const onderdeel = ONDERDELEN.includes(naam as Onderdeel) ? (naam as Onderdeel) : 'meldkamer'
  const filters: Record<string, string> = {}
  new URLSearchParams(zoek).forEach((waarde, sleutel) => {
    if (waarde) filters[sleutel] = waarde
  })
  return { onderdeel, filters }
}

export function schrijfLocatie(locatie: Locatie): string {
  const zoek = new URLSearchParams()
  for (const [sleutel, waarde] of Object.entries(locatie.filters)) {
    if (waarde) zoek.set(sleutel, waarde)
  }
  const tekst = zoek.toString()
  return `${BASIS}/${locatie.onderdeel}${tekst ? `?${tekst}` : ''}`
}

// B3 — praat met de hook-routes van PocketBase (backend/pb_hooks/hh_ouder.pb.js).
// Geen PocketBase-client nodig: drie publieke POST-routes met JSON.

export type OuderStatus = 'verstuurd' | 'gegeven' | 'ingetrokken' | 'verlopen'

export type OuderStand = {
  status: OuderStatus
  voornaam: string
  /** Alleen bij status verstuurd: de ouder-sessie (30 minuten). */
  sessie?: string
  gegeven_op?: string
  avp?: boolean
}

export type CodeInvoer = { email: string; code: string } | { token: string }
export type ToestemmingInvoer = { sessie: string; naam: string; iban: string; akkoord: true; avp: boolean }
export type IntrekInvoer = { token: string } | { sessie: string }

export interface OuderApi {
  code(invoer: CodeInvoer): Promise<OuderStand>
  toestemming(invoer: ToestemmingInvoer): Promise<OuderStand>
  intrekken(invoer: IntrekInvoer): Promise<OuderStand>
}

/** Een weigering van de server, met zijn melding (je-vorm) en reden. */
export class OuderFout extends Error {
  readonly status: number
  readonly reden: string

  constructor(status: number, reden: string, melding: string) {
    super(melding)
    this.name = 'OuderFout'
    this.status = status
    this.reden = reden
  }
}

const MELDING_VERBINDING = 'De server is niet bereikbaar. Probeer het zo opnieuw.'
const MELDING_ONBEKEND = 'Er ging iets mis. Probeer het zo opnieuw.'

type FetchFn = (url: string, init: RequestInit) => Promise<Response>

export function maakOuderApi(basisUrl: string, fetchFn: FetchFn = (u, i) => fetch(u, i)): OuderApi {
  const basis = basisUrl.replace(/\/+$/, '')

  async function post(route: string, body: object): Promise<OuderStand> {
    let res: Response
    try {
      res = await fetchFn(`${basis}/api/hh/ouder/${route}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
    } catch {
      throw new OuderFout(0, 'verbinding', MELDING_VERBINDING)
    }
    const data: unknown = await res.json().catch(() => ({}))
    const veld = (k: string) => (data && typeof data === 'object' ? (data as Record<string, unknown>)[k] : undefined)
    if (!res.ok) {
      const melding = typeof veld('melding') === 'string' && veld('melding') ? String(veld('melding')) : MELDING_ONBEKEND
      throw new OuderFout(res.status, String(veld('reden') ?? ''), melding)
    }
    return data as OuderStand
  }

  return {
    code: (invoer) => post('code', invoer),
    toestemming: (invoer) => post('toestemming', invoer),
    intrekken: (invoer) => post('intrekken', invoer),
  }
}

// B5 — praat met de publieke hook-routes POST /api/hh/ouder/klus en
// /api/hh/ouder/klus/besluit (backend/pb_hooks/hh_reacties.pb.js).

import { OuderFout } from '../ouderApi'

export type KlusStatus = 'wacht' | 'goed' | 'lieverniet' | 'verlopen' | 'ingetrokken'
export type Besluit = 'goed' | 'lieverniet'

export type OuderKlusStand = {
  status: KlusStatus
  helper_voornaam: string
  ouder_gaat_mee: boolean
  klus: { wat: string; omschrijving: string; waar: string; wanneer: string; bewoner_voornaam: string }
}

export interface OuderKlusApi {
  stand(token: string): Promise<OuderKlusStand>
  besluit(token: string, besluit: Besluit): Promise<OuderKlusStand>
}

const MELDING_VERBINDING = 'De server is niet bereikbaar. Probeer het zo opnieuw.'
const MELDING_ONBEKEND = 'Er ging iets mis. Probeer het zo opnieuw.'

type FetchFn = (url: string, init: RequestInit) => Promise<Response>

export function maakOuderKlusApi(basisUrl: string, fetchFn: FetchFn = (u, i) => fetch(u, i)): OuderKlusApi {
  const basis = basisUrl.replace(/\/+$/, '')

  async function post(route: string, body: object): Promise<OuderKlusStand> {
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
    return data as OuderKlusStand
  }

  return {
    stand: (token) => post('klus', { token }),
    besluit: (token, besluit) => post('klus/besluit', { token, besluit }),
  }
}

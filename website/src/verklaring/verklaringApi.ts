// B9 — praat met de publieke hook-route GET /api/hh/verklaring/{code}
// (backend/pb_hooks/hh_xp.pb.js, 30 per IP per uur).

export type Verklaring = {
  code: string
  uitgegeven_op: string
  gegevens: {
    voornaam: string
    klussen: number
    uren: number
    periode_van: string
    periode_tot: string
    niveau: string
    badges: { naam: string; datum: string }[]
    vertrouwen: { naam: string; datum: string }[]
  }
}

export class VerklaringFout extends Error {
  readonly status: number
  readonly reden: string

  constructor(status: number, reden: string, melding: string) {
    super(melding)
    this.status = status
    this.reden = reden
  }
}

export interface VerklaringApi {
  opzoeken(code: string): Promise<Verklaring>
}

const MELDING_VERBINDING = 'De server is niet bereikbaar. Probeer het zo opnieuw.'
const MELDING_ONBEKEND = 'Er ging iets mis. Probeer het zo opnieuw.'

type FetchFn = (url: string, init: RequestInit) => Promise<Response>

export function maakVerklaringApi(basisUrl: string, fetchFn: FetchFn = (u, i) => fetch(u, i)): VerklaringApi {
  const basis = basisUrl.replace(/\/+$/, '')
  return {
    async opzoeken(code) {
      let res: Response
      try {
        res = await fetchFn(`${basis}/api/hh/verklaring/${encodeURIComponent(code)}`, { method: 'GET' })
      } catch {
        throw new VerklaringFout(0, 'verbinding', MELDING_VERBINDING)
      }
      const data: unknown = await res.json().catch(() => ({}))
      const veld = (k: string) => (data && typeof data === 'object' ? (data as Record<string, unknown>)[k] : undefined)
      if (!res.ok) {
        const melding = typeof veld('melding') === 'string' && veld('melding') ? String(veld('melding')) : MELDING_ONBEKEND
        throw new VerklaringFout(res.status, String(veld('reden') ?? ''), melding)
      }
      const v = data as Verklaring
      return {
        code: String(v.code ?? code),
        uitgegeven_op: String(v.uitgegeven_op ?? ''),
        gegevens: {
          voornaam: String(v.gegevens?.voornaam ?? ''),
          klussen: Number(v.gegevens?.klussen ?? 0),
          uren: Number(v.gegevens?.uren ?? 0),
          periode_van: String(v.gegevens?.periode_van ?? ''),
          periode_tot: String(v.gegevens?.periode_tot ?? ''),
          niveau: String(v.gegevens?.niveau ?? ''),
          badges: Array.isArray(v.gegevens?.badges) ? v.gegevens.badges : [],
          vertrouwen: Array.isArray(v.gegevens?.vertrouwen) ? v.gegevens.vertrouwen : [],
        },
      }
    },
  }
}

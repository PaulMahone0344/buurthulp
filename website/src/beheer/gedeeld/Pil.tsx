// M14 — de statuspil van het bestaande AdminDashboard (.status-pill), nu met
// de acht klusstatussen van de app.

import type { ReactNode } from 'react'
import type { AdresBron, Klusstatus } from '../data/types'
import { STATUS_LABEL } from '../teksten'

export type PilToon = 'nieuw' | 'gematcht' | 'actief' | 'klaar' | 'stop' | 'fout'

const KLASSE: Record<PilToon, string> = {
  nieuw: 'status-new',
  gematcht: 'status-matched',
  actief: 'status-active',
  klaar: 'status-done',
  stop: 'status-stopped',
  fout: 'status-problem',
}

const KLUS_TOON: Record<Klusstatus, PilToon> = {
  concept: 'nieuw',
  open: 'nieuw',
  geaccepteerd: 'gematcht',
  onderweg: 'actief',
  bezig: 'actief',
  afgerond: 'klaar',
  geannuleerd: 'stop',
  probleem: 'fout',
}

export function Pil({ toon, children }: { toon: PilToon; children: ReactNode }) {
  return <span className={`status-pill ${KLASSE[toon]}`}>{children}</span>
}

export function KlusPil({ status }: { status: Klusstatus }) {
  return <Pil toon={KLUS_TOON[status] ?? 'nieuw'}>{STATUS_LABEL[status] ?? status}</Pil>
}

/** ADRES: markering bij een adres dat niet door PDOK bevestigd is. Niets bij pdok of leeg. */
export function AdresBronPil({ bron }: { bron?: AdresBron }) {
  if (bron === 'handmatig') return <Pil toon="stop">Adres handmatig</Pil>
  if (bron === 'ongecontroleerd') return <Pil toon="fout">Adres niet gecontroleerd</Pil>
  return null
}

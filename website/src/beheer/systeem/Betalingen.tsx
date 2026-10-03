// M14 — betaalstatus per klus (D4), alleen lezen uit hh_betalingen.
// "Opnieuw aanbieden" is M16 (Mollie); de knop staat uit.

import { useCallback } from 'react'
import type { BeheerData } from '../data/beheerData'
import { toonBedrag, toonMoment } from '../data/tijd'
import type { Betaling } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil, type PilToon } from '../gedeeld/Pil'
import { useLaden } from '../gedeeld/useLaden'

const GEEN: Betaling[] = []
const TOON: Record<string, PilToon> = { open: 'nieuw', betaald: 'klaar', mislukt: 'fout', terugbetaald: 'stop' }
const LABEL: Record<string, string> = { open: 'Open', betaald: 'Betaald', mislukt: 'Mislukt', terugbetaald: 'Terugbetaald' }

export function Betalingen({ data }: { data: BeheerData }) {
  const laad = useCallback(() => data.betalingen(), [data])
  const betalingen = useLaden(laad, GEEN)
  return (
    <>
      <h2>Betalingen</h2>
      <Foutmelding melding={betalingen.fout} />
      <div className="request-table" aria-label="Betalingen">
        {betalingen.waarde.map((b) => (
          <div className="request-row request-row--beheer" key={b.id}>
            <div>
              <strong>{b.klusOmschrijving || `Klus ${b.klusId}`}</strong>
              <span>
                {toonBedrag(b.bedrag)}
                {b.betaaldOp ? ` · betaald ${toonMoment(b.betaaldOp)}` : ''}
              </span>
            </div>
            <Pil toon={TOON[b.status] ?? 'nieuw'}>{LABEL[b.status] ?? 'Onbekend'}</Pil>
            {b.status === 'mislukt' ? (
              <button className="mini-btn" type="button" disabled title="Komt met betalen (M16)">
                Opnieuw aanbieden
              </button>
            ) : (
              <span />
            )}
          </div>
        ))}
        {betalingen.geladen && betalingen.waarde.length === 0 ? <p className="empty-note">Nog geen betalingen.</p> : null}
      </div>
    </>
  )
}

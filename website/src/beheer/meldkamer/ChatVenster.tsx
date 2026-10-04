// B11 — de chat van een klus lezen (besluit Ibrahim 4 okt: de meldkamer mag
// elke chat lezen; staat in de privacyverklaring). Alleen lezen: de meldkamer
// schrijft nooit in een chat. Markeringen van het filter worden getoond.

import { useCallback, useEffect, useId } from 'react'
import type { BeheerData } from '../data/beheerData'
import { toonMoment } from '../data/tijd'
import type { Chatbericht, Klus } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil } from '../gedeeld/Pil'
import { useLaden } from '../gedeeld/useLaden'

type Props = { data: BeheerData; klus: Klus; opSluit: () => void }

const GEEN: Chatbericht[] = []

export function ChatVenster({ data, klus, opSluit }: Props) {
  const titelId = useId()
  const laad = useCallback(() => data.chat(klus.id), [data, klus.id])
  const berichten = useLaden(laad, GEEN)

  useEffect(() => {
    function opToets(e: KeyboardEvent) {
      if (e.key === 'Escape') opSluit()
    }
    window.addEventListener('keydown', opToets)
    return () => window.removeEventListener('keydown', opToets)
  }, [opSluit])

  return (
    <div className="beheer-venster-achtergrond">
      <div className="beheer-venster beheer-venster--breed" role="dialog" aria-modal="true" aria-labelledby={titelId}>
        <h2 id={titelId}>Chat bij de klus van {klus.hulpvragerNaam}</h2>
        <p className="admin-muted">
          {klus.hulpvragerNaam} en {klus.jongereNaam || 'de strijder'}. Alleen lezen.
        </p>
        <Foutmelding melding={berichten.fout} />
        <ol className="beheer-chat" aria-label="Berichten">
          {berichten.waarde.map((b) => (
            <li key={b.id} className={`beheer-chat__bericht${b.vanBewoner ? ' is-bewoner' : ''}`}>
              <p className="beheer-chat__kop">
                <strong>{b.afzenderNaam || (b.vanBewoner ? 'Bewoner' : 'Strijder')}</strong>
                <span>{toonMoment(b.verstuurdOp)}</span>
              </p>
              <p>{b.gewist ? <em>Bericht verwijderd</em> : b.tekst}</p>
              {b.gefilterd || b.contactverzoek ? (
                <p className="beheer-chat__pillen">
                  {b.gefilterd ? <Pil toon="nieuw">Nummer of link weggehaald</Pil> : null}
                  {b.contactverzoek ? <Pil toon="fout">Vraagt contact buiten de app</Pil> : null}
                </p>
              ) : null}
            </li>
          ))}
        </ol>
        {berichten.geladen && berichten.waarde.length === 0 ? <p className="empty-note">Nog geen berichten.</p> : null}
        <div className="beheer-venster__knoppen">
          <button className="mini-btn" type="button" onClick={opSluit}>
            Sluiten
          </button>
        </div>
      </div>
    </div>
  )
}

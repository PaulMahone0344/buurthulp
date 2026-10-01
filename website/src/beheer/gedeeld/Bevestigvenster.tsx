// M14 — een venster dat een handeling laat bevestigen. Blijft open zolang de
// handeling loopt; een fout van de server komt in het venster zelf.

import { useEffect, useId, useState, type ReactNode } from 'react'
import { Foutmelding } from './Meldbalk'

type Props = {
  titel: string
  children?: ReactNode
  bevestigTekst: string
  /** Gooit bij een fout; de melding komt in het venster. */
  opBevestig: () => Promise<void>
  opSluit: () => void
  /** Uitgeschakeld zolang de invoer nog niet klopt. */
  magBevestigen?: boolean
}

export function Bevestigvenster({ titel, children, bevestigTekst, opBevestig, opSluit, magBevestigen = true }: Props) {
  const titelId = useId()
  const [bezig, setBezig] = useState(false)
  const [fout, setFout] = useState('')

  useEffect(() => {
    function opToets(e: KeyboardEvent) {
      if (e.key === 'Escape') opSluit()
    }
    window.addEventListener('keydown', opToets)
    return () => window.removeEventListener('keydown', opToets)
  }, [opSluit])

  async function bevestig() {
    setBezig(true)
    setFout('')
    try {
      await opBevestig()
    } catch (e) {
      setFout(e instanceof Error ? e.message : String(e))
      setBezig(false)
    }
  }

  return (
    <div className="beheer-venster-achtergrond">
      <div className="beheer-venster" role="dialog" aria-modal="true" aria-labelledby={titelId}>
        <h2 id={titelId}>{titel}</h2>
        {children}
        <Foutmelding melding={fout} />
        <div className="beheer-venster__knoppen">
          <button className="mini-btn mini-btn--ghost" type="button" onClick={opSluit}>
            Annuleren
          </button>
          <button className="mini-btn" type="button" disabled={bezig || !magBevestigen} onClick={() => void bevestig()}>
            {bezig ? 'Bezig…' : bevestigTekst}
          </button>
        </div>
      </div>
    </div>
  )
}

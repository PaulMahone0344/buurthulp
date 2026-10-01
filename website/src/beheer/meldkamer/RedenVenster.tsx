// M14 — een handeling die een reden vraagt (vrijgeven, annuleren).

import { useState } from 'react'
import { Bevestigvenster } from '../gedeeld/Bevestigvenster'

type Props = {
  titel: string
  uitleg: string
  bevestigTekst: string
  min: number
  max: number
  opBevestig: (reden: string) => Promise<void>
  opSluit: () => void
  opKlaar: () => void
}

export function RedenVenster({ titel, uitleg, bevestigTekst, min, max, opBevestig, opSluit, opKlaar }: Props) {
  const [reden, setReden] = useState('')
  const lengte = reden.trim().length
  return (
    <Bevestigvenster
      titel={titel}
      bevestigTekst={bevestigTekst}
      magBevestigen={lengte >= min && lengte <= max}
      opSluit={opSluit}
      opBevestig={async () => {
        await opBevestig(reden.trim())
        opKlaar()
      }}
    >
      <p className="admin-muted">{uitleg}</p>
      <label className="field">
        <span>Reden</span>
        <textarea rows={3} maxLength={max} value={reden} onChange={(e) => setReden(e.target.value)} />
      </label>
      <p className="beheer-hulp">
        {min > 1 ? `Minstens ${min} en hoogstens ${max} tekens.` : `Hoogstens ${max} tekens.`}
      </p>
    </Bevestigvenster>
  )
}

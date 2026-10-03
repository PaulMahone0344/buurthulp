// M14 — handmatig koppelen (D1): de coordinator kiest een goedgekeurde
// jongere. Jongeren uit de wijk van de oudere staan bovenaan; een jongere uit
// een andere wijk mag (dat is juist het nut), maar krijgt een waarschuwing.

import { useCallback, useState } from 'react'
import type { BeheerData } from '../data/beheerData'
import { sorteerKoppelkandidaten } from '../data/filters'
import type { Klus, Koppelkandidaat } from '../data/types'
import { Bevestigvenster } from '../gedeeld/Bevestigvenster'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { useLaden } from '../gedeeld/useLaden'

type Props = {
  data: BeheerData
  klus: Klus
  opSluit: () => void
  opGekoppeld: () => void
}

const GEEN: Koppelkandidaat[] = []

export function KoppelVenster({ data, klus, opSluit, opGekoppeld }: Props) {
  const laad = useCallback(() => data.koppelkandidaten(), [data])
  const kandidaten = useLaden(laad, GEEN)
  const [gekozen, setGekozen] = useState('')
  const wijk = klus.hulpvragerWijkNaam ?? ''
  const lijst = sorteerKoppelkandidaten(kandidaten.waarde, wijk)
  const keuze = lijst.find((k) => k.id === gekozen)
  const andereWijk = !!keuze && !!wijk && keuze.wijkNaam !== wijk

  return (
    <Bevestigvenster
      titel={`Jongere koppelen aan de klus van ${klus.hulpvragerNaam}`}
      bevestigTekst="Koppelen"
      magBevestigen={!!keuze}
      opSluit={opSluit}
      opBevestig={async () => {
        await data.koppelen(klus.id, gekozen)
        opGekoppeld()
      }}
    >
      <p className="admin-muted">
        {klus.klustypeNaam || 'Klus'}
        {wijk ? ` in ${wijk}` : ''}. Alleen goedgekeurde jongeren staan in de lijst.
      </p>
      <Foutmelding melding={kandidaten.fout} />
      <fieldset className="beheer-keuzelijst">
        <legend>Kies een jongere</legend>
        {lijst.map((k) => (
          <label key={k.id} className="beheer-keuze">
            <input type="radio" name="jongere" value={k.id} checked={gekozen === k.id} onChange={() => setGekozen(k.id)} />
            <span>
              {k.naam} · {k.wijkNaam || 'geen wijk'} · {k.klussenAantal} klussen
            </span>
          </label>
        ))}
        {kandidaten.geladen && lijst.length === 0 ? <p className="empty-note">Geen goedgekeurde jongeren.</p> : null}
      </fieldset>
      {andereWijk ? (
        <p className="beheer-signaal" role="note">
          Let op: {keuze?.naam} woont in een andere wijk dan de oudere.
        </p>
      ) : null}
    </Bevestigvenster>
  )
}

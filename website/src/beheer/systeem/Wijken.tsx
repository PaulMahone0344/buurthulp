// M14 — wijken aan/uit en hun postcodes (D4).

import { useCallback, useState, type FormEvent } from 'react'
import type { BeheerData } from '../data/beheerData'
import type { Wijk } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil } from '../gedeeld/Pil'
import { useLaden } from '../gedeeld/useLaden'

const GEEN: Wijk[] = []

function naarPostcodes(tekst: string): string[] {
  return tekst
    .split(/[,\s]+/)
    .map((p) => p.trim())
    .filter(Boolean)
}

function WijkRij({ wijk, data, opGewijzigd }: { wijk: Wijk; data: BeheerData; opGewijzigd: (fout: string) => void }) {
  const [postcodes, setPostcodes] = useState(wijk.postcodes.join(', '))
  async function doe(werk: () => Promise<void>) {
    try {
      await werk()
      opGewijzigd('')
    } catch (e) {
      opGewijzigd(e instanceof Error ? e.message : String(e))
    }
  }
  return (
    <div className="request-row request-row--beheer" aria-label={`Wijk ${wijk.wijk}`}>
      <div>
        <strong>
          {wijk.wijk} <em className="beheer-label">{wijk.gemeente}</em>
        </strong>
        <label className="field">
          <span>Postcodes van {wijk.wijk}</span>
          <input value={postcodes} onChange={(e) => setPostcodes(e.target.value)} />
        </label>
      </div>
      <Pil toon={wijk.actief ? 'klaar' : 'stop'}>{wijk.actief ? 'Aan' : 'Uit'}</Pil>
      <div className="beheer-acties">
        <button className="mini-btn" type="button" onClick={() => void doe(() => data.wijzigWijk(wijk.id, { postcodes: naarPostcodes(postcodes) }))}>
          Postcodes opslaan
        </button>
        <button className="mini-btn mini-btn--ghost" type="button" onClick={() => void doe(() => data.wijzigWijk(wijk.id, { actief: !wijk.actief }))}>
          {wijk.actief ? `Zet ${wijk.wijk} uit` : `Zet ${wijk.wijk} aan`}
        </button>
      </div>
    </div>
  )
}

export function Wijken({ data }: { data: BeheerData }) {
  const laad = useCallback(() => data.wijken(), [data])
  const wijken = useLaden(laad, GEEN)
  const [fout, setFout] = useState('')
  const [nieuw, setNieuw] = useState({ gemeente: '', wijk: '', postcodes: '' })

  const opGewijzigd = (melding: string) => {
    setFout(melding)
    if (!melding) void wijken.herlaad()
  }

  async function voegToe(e: FormEvent) {
    e.preventDefault()
    if (!nieuw.gemeente.trim() || !nieuw.wijk.trim()) return setFout('Vul gemeente en wijk in.')
    try {
      await data.maakWijk({ gemeente: nieuw.gemeente.trim(), wijk: nieuw.wijk.trim(), postcodes: naarPostcodes(nieuw.postcodes), actief: false })
      setNieuw({ gemeente: '', wijk: '', postcodes: '' })
      opGewijzigd('')
    } catch (err) {
      setFout(err instanceof Error ? err.message : String(err))
    }
  }

  return (
    <>
      <h2>Wijken</h2>
      <Foutmelding melding={fout || wijken.fout} />
      <div className="request-table">
        {wijken.waarde.map((w) => (
          <WijkRij key={`${w.id}-${w.postcodes.join()}-${w.actief}`} wijk={w} data={data} opGewijzigd={opGewijzigd} />
        ))}
      </div>
      <form className="beheer-formulier beheer-formulier--raster" onSubmit={(e) => void voegToe(e)} aria-label="Nieuwe wijk">
        <label className="field">
          <span>Gemeente</span>
          <input value={nieuw.gemeente} onChange={(e) => setNieuw({ ...nieuw, gemeente: e.target.value })} />
        </label>
        <label className="field">
          <span>Wijk</span>
          <input value={nieuw.wijk} onChange={(e) => setNieuw({ ...nieuw, wijk: e.target.value })} />
        </label>
        <label className="field">
          <span>Postcodes</span>
          <input value={nieuw.postcodes} onChange={(e) => setNieuw({ ...nieuw, postcodes: e.target.value })} />
        </label>
        <button className="mini-btn" type="submit">
          Wijk toevoegen (staat uit)
        </button>
      </form>
    </>
  )
}

// M14 — instellingen in hh_instellingen (D4). Alleen opslaan: er hangt nog
// geen gedrag aan (OPEN-PUNTEN-M14).

import { useCallback, useState } from 'react'
import type { BeheerData } from '../data/beheerData'
import type { Instelling } from '../data/types'
import { Foutmelding, Gelukt } from '../gedeeld/Meldbalk'
import { useLaden } from '../gedeeld/useLaden'

const INSTELLINGEN = [
  { sleutel: 'commissiepercentage', label: 'Commissiepercentage (%)' },
  { sleutel: 'straal_km', label: 'Standaardstraal (km)' },
  { sleutel: 'annuleertermijn_uren', label: 'Annuleertermijn (uren)' },
] as const

const GEEN: Instelling[] = []

function InstellingRij({ data, sleutel, label, waarde, opKlaar }: { data: BeheerData; sleutel: string; label: string; waarde: string; opKlaar: (fout: string, ok: string) => void }) {
  const [invoer, setInvoer] = useState(waarde)
  async function sla() {
    const n = Number(invoer.replace(',', '.'))
    if (invoer.trim() === '' || !Number.isFinite(n) || n < 0) return opKlaar(`Vul bij ${label.toLowerCase()} een getal in.`, '')
    try {
      await data.slaInstellingOp(sleutel, String(n))
      opKlaar('', `${label} opgeslagen.`)
    } catch (e) {
      opKlaar(e instanceof Error ? e.message : String(e), '')
    }
  }
  return (
    <div className="request-row request-row--beheer">
      <label className="field">
        <span>{label}</span>
        <input inputMode="decimal" value={invoer} onChange={(e) => setInvoer(e.target.value)} />
      </label>
      <span />
      <button className="mini-btn" type="button" onClick={() => void sla()}>
        {label} opslaan
      </button>
    </div>
  )
}

export function Instellingen({ data }: { data: BeheerData }) {
  const laad = useCallback(() => data.instellingen(), [data])
  const instellingen = useLaden(laad, GEEN)
  const [fout, setFout] = useState('')
  const [ok, setOk] = useState('')
  return (
    <>
      <h2>Instellingen</h2>
      <p className="admin-muted">Deze waarden worden bewaard, maar de app gebruikt ze nog niet.</p>
      <Foutmelding melding={fout || instellingen.fout} />
      <Gelukt melding={ok} />
      {instellingen.geladen ? (
        <div className="request-table">
          {INSTELLINGEN.map((i) => (
            <InstellingRij
              key={i.sleutel}
              data={data}
              sleutel={i.sleutel}
              label={i.label}
              waarde={instellingen.waarde.find((w) => w.sleutel === i.sleutel)?.waarde ?? ''}
              opKlaar={(f, o) => {
                setFout(f)
                setOk(o)
              }}
            />
          ))}
        </div>
      ) : null}
    </>
  )
}

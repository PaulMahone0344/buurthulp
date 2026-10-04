// M14 — instellingen in hh_instellingen (D4). Alleen opslaan: er hangt nog
// geen gedrag aan (OPEN-PUNTEN-M14).
// B11: twee schakelaars die WEL gedrag hebben (de server leest ze meteen) en
// de twee getallen van het signaal "zelfde paar".

import { useCallback, useState } from 'react'
import type { BeheerData } from '../data/beheerData'
import type { Instelling } from '../data/types'
import { Foutmelding, Gelukt } from '../gedeeld/Meldbalk'
import { useLaden } from '../gedeeld/useLaden'

const INSTELLINGEN = [
  { sleutel: 'commissiepercentage', label: 'Commissiepercentage (%)' },
  { sleutel: 'straal_km', label: 'Standaardstraal (km)' },
  { sleutel: 'annuleertermijn_uren', label: 'Annuleertermijn (uren)' },
  { sleutel: 'b11_zelfde_paar_aantal', label: 'Zelfde paar: signaal bij klus nummer' },
  { sleutel: 'b11_zelfde_paar_dagen', label: 'Zelfde paar: binnen dagen' },
] as const

const SCHAKELAARS = [
  {
    sleutel: 'b11_kennismaking_verplicht',
    label: 'Keuren wacht op de kennismaking',
    uitleg: 'Aan: een klus van een nieuwe bewoner kun je pas goedkeuren als je de bewoner hebt gebeld.',
  },
  {
    sleutel: 'b11_zelfde_paar_aan',
    label: 'Signaal zelfde paar',
    uitleg: 'Aan: een signaal als een strijder onder 18 vaak met dezelfde bewoner werkt (getallen hierboven).',
  },
] as const

function SchakelaarRij({ data, sleutel, label, uitleg, aan, opKlaar }: { data: BeheerData; sleutel: string; label: string; uitleg: string; aan: boolean; opKlaar: (fout: string, ok: string) => void }) {
  async function zet(nieuw: boolean) {
    try {
      await data.slaInstellingOp(sleutel, nieuw ? 'true' : 'false')
      opKlaar('', `${label}: ${nieuw ? 'aan' : 'uit'}.`)
    } catch (e) {
      opKlaar(e instanceof Error ? e.message : String(e), '')
    }
  }
  return (
    <div className="request-row request-row--beheer">
      <div>
        <strong>{label}</strong>
        <span>{uitleg}</span>
      </div>
      <span>{aan ? 'Aan' : 'Uit'}</span>
      <button className="mini-btn" type="button" onClick={() => void zet(!aan)}>
        {aan ? `${label} uitzetten` : `${label} aanzetten`}
      </button>
    </div>
  )
}

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
      <p className="admin-muted">Commissie, straal en annuleertermijn worden bewaard, maar de app gebruikt ze nog niet.</p>
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
      {instellingen.geladen ? (
        <>
          <h3>Schakelaars</h3>
          <div className="request-table" aria-label="Schakelaars">
            {SCHAKELAARS.map((i) => (
              <SchakelaarRij
                key={i.sleutel}
                data={data}
                sleutel={i.sleutel}
                label={i.label}
                uitleg={i.uitleg}
                aan={instellingen.waarde.find((w) => w.sleutel === i.sleutel)?.waarde === 'true'}
                opKlaar={(f, o) => {
                  setFout(f)
                  setOk(o)
                  if (!f) void instellingen.herlaad()
                }}
              />
            ))}
          </div>
        </>
      ) : null}
    </>
  )
}

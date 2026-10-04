// M14 — klustypes met richtduur (minuten) en richtvergoeding (D4). De
// vergoeding staat in centen op de server en in euro's op het scherm.
// B11: ook de minimale leeftijd van een helper (10, 13, 16 of 18; B4).

import { useCallback, useState, type FormEvent } from 'react'
import type { BeheerData } from '../data/beheerData'
import { MIN_LEEFTIJDEN, type Klustype } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { useLaden } from '../gedeeld/useLaden'

const GEEN: Klustype[] = []

function euroNaarCenten(tekst: string): number {
  const n = Number(tekst.replace(',', '.'))
  return Number.isFinite(n) && n >= 0 ? Math.round(n * 100) : -1
}

const centenNaarEuro = (centen: number) => (centen / 100).toFixed(2).replace('.', ',')

/** Nieuw klustype zonder keuze: het strengst (B4: 18+ mag alles). */
const STANDAARD_MIN_LEEFTIJD = 18

function LeeftijdKeuze({ label, waarde, zet }: { label: string; waarde: number; zet: (n: number) => void }) {
  return (
    <label className="field">
      <span>{label}</span>
      <select value={waarde} onChange={(e) => zet(Number(e.target.value))}>
        {MIN_LEEFTIJDEN.map((n) => (
          <option key={n} value={n}>
            vanaf {n} jaar
          </option>
        ))}
      </select>
    </label>
  )
}

function KlustypeRij({ type, data, opGewijzigd }: { type: Klustype; data: BeheerData; opGewijzigd: (fout: string) => void }) {
  const [duur, setDuur] = useState(String(type.richtduur))
  const [vergoeding, setVergoeding] = useState(centenNaarEuro(type.richtvergoeding))
  const [minLeeftijd, setMinLeeftijd] = useState(type.minLeeftijd || STANDAARD_MIN_LEEFTIJD)
  async function sla() {
    const centen = euroNaarCenten(vergoeding)
    const minuten = Number(duur)
    if (centen < 0 || !Number.isInteger(minuten) || minuten < 0) return opGewijzigd('Vul een geldige duur en vergoeding in.')
    try {
      await data.wijzigKlustype(type.id, { richtduur: minuten, richtvergoeding: centen, minLeeftijd })
      opGewijzigd('')
    } catch (e) {
      opGewijzigd(e instanceof Error ? e.message : String(e))
    }
  }
  return (
    <div className="request-row request-row--beheer" aria-label={`Klustype ${type.naam}`}>
      <strong>{type.naam}</strong>
      <div className="beheer-formulier beheer-formulier--rij">
        <label className="field">
          <span>Richtduur {type.naam} (minuten)</span>
          <input inputMode="numeric" value={duur} onChange={(e) => setDuur(e.target.value)} />
        </label>
        <label className="field">
          <span>Richtvergoeding {type.naam} (euro)</span>
          <input inputMode="decimal" value={vergoeding} onChange={(e) => setVergoeding(e.target.value)} />
        </label>
        <LeeftijdKeuze label={`Minimale leeftijd ${type.naam}`} waarde={minLeeftijd} zet={setMinLeeftijd} />
      </div>
      <button className="mini-btn" type="button" onClick={() => void sla()}>
        Opslaan
      </button>
    </div>
  )
}

export function Klustypes({ data }: { data: BeheerData }) {
  const laad = useCallback(() => data.klustypes(), [data])
  const types = useLaden(laad, GEEN)
  const [fout, setFout] = useState('')
  const leeg = { naam: '', icoon: '', duur: '60', vergoeding: '', minLeeftijd: STANDAARD_MIN_LEEFTIJD }
  const [nieuw, setNieuw] = useState(leeg)
  const opGewijzigd = (melding: string) => {
    setFout(melding)
    if (!melding) void types.herlaad()
  }

  async function voegToe(e: FormEvent) {
    e.preventDefault()
    const centen = euroNaarCenten(nieuw.vergoeding)
    if (!nieuw.naam.trim() || centen < 0) return setFout('Vul een naam en een vergoeding in.')
    try {
      await data.maakKlustype({
        naam: nieuw.naam.trim(),
        icoon: nieuw.icoon.trim(),
        richtduur: Number(nieuw.duur) || 0,
        richtvergoeding: centen,
        minLeeftijd: nieuw.minLeeftijd,
      })
      setNieuw(leeg)
      opGewijzigd('')
    } catch (err) {
      setFout(err instanceof Error ? err.message : String(err))
    }
  }

  return (
    <>
      <h2>Klustypes</h2>
      <Foutmelding melding={fout || types.fout} />
      <div className="request-table">
        {types.waarde.map((t) => (
          <KlustypeRij key={`${t.id}-${t.richtduur}-${t.richtvergoeding}-${t.minLeeftijd}`} type={t} data={data} opGewijzigd={opGewijzigd} />
        ))}
      </div>
      <form className="beheer-formulier beheer-formulier--raster" onSubmit={(e) => void voegToe(e)} aria-label="Nieuw klustype">
        <label className="field">
          <span>Naam</span>
          <input value={nieuw.naam} onChange={(e) => setNieuw({ ...nieuw, naam: e.target.value })} />
        </label>
        <label className="field">
          <span>Icoon (naam in de app)</span>
          <input value={nieuw.icoon} onChange={(e) => setNieuw({ ...nieuw, icoon: e.target.value })} />
        </label>
        <label className="field">
          <span>Richtduur (minuten)</span>
          <input inputMode="numeric" value={nieuw.duur} onChange={(e) => setNieuw({ ...nieuw, duur: e.target.value })} />
        </label>
        <label className="field">
          <span>Richtvergoeding (euro)</span>
          <input inputMode="decimal" value={nieuw.vergoeding} onChange={(e) => setNieuw({ ...nieuw, vergoeding: e.target.value })} />
        </label>
        <LeeftijdKeuze label="Minimale leeftijd" waarde={nieuw.minLeeftijd} zet={(n) => setNieuw({ ...nieuw, minLeeftijd: n })} />
        <button className="mini-btn" type="submit">
          Klustype toevoegen
        </button>
      </form>
    </>
  )
}

// M14 — klustypes met richtduur (minuten) en richtvergoeding (D4). De
// vergoeding staat in centen op de server en in euro's op het scherm.
// B11: ook de minimale leeftijd van een helper (10, 13, 16 of 18; B4).
// Tabel: één regel per klustype, de kolomkoppen staan er één keer boven.

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

function LeeftijdOpties() {
  return (
    <>
      {MIN_LEEFTIJDEN.map((n) => (
        <option key={n} value={n}>
          vanaf {n} jaar
        </option>
      ))}
    </>
  )
}

function KlustypeRij({ type, data, opGewijzigd }: { type: Klustype; data: BeheerData; opGewijzigd: (fout: string) => void }) {
  const beginDuur = String(type.richtduur)
  const beginVergoeding = centenNaarEuro(type.richtvergoeding)
  const beginLeeftijd = type.minLeeftijd || STANDAARD_MIN_LEEFTIJD
  const [duur, setDuur] = useState(beginDuur)
  const [vergoeding, setVergoeding] = useState(beginVergoeding)
  const [minLeeftijd, setMinLeeftijd] = useState(beginLeeftijd)
  const isGewijzigd = duur !== beginDuur || vergoeding !== beginVergoeding || minLeeftijd !== beginLeeftijd

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
    <tr>
      <th scope="row">{type.naam}</th>
      <td>
        <input
          aria-label={`Richtduur ${type.naam} (minuten)`}
          inputMode="numeric"
          value={duur}
          onChange={(e) => setDuur(e.target.value)}
        />
      </td>
      <td>
        <input
          aria-label={`Richtvergoeding ${type.naam} (euro)`}
          inputMode="decimal"
          value={vergoeding}
          onChange={(e) => setVergoeding(e.target.value)}
        />
      </td>
      <td>
        <select
          aria-label={`Minimale leeftijd ${type.naam}`}
          value={minLeeftijd}
          onChange={(e) => setMinLeeftijd(Number(e.target.value))}
        >
          <LeeftijdOpties />
        </select>
      </td>
      <td className="beheer-tabel__actie">
        {/* pas aan als er in deze regel iets is veranderd */}
        <button
          className="mini-btn"
          type="button"
          aria-label={`Opslaan ${type.naam}`}
          disabled={!isGewijzigd}
          onClick={() => void sla()}
        >
          Opslaan
        </button>
      </td>
    </tr>
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
      <div className="beheer-tabel-wrap">
        <table className="beheer-tabel" aria-label="Klustypes">
          <thead>
            <tr>
              <th scope="col">Naam</th>
              <th scope="col">Minuten</th>
              <th scope="col">Euro</th>
              <th scope="col">Vanaf</th>
              <th scope="col" className="beheer-tabel__actie">
                <span className="beheer-alleen-lezer">Opslaan</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {types.waarde.map((t) => (
              <KlustypeRij key={`${t.id}-${t.richtduur}-${t.richtvergoeding}-${t.minLeeftijd}`} type={t} data={data} opGewijzigd={opGewijzigd} />
            ))}
          </tbody>
        </table>
      </div>
      <h3 className="beheer-tussenkop">Nieuw klustype</h3>
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
        <label className="field">
          <span>Minimale leeftijd</span>
          <select value={nieuw.minLeeftijd} onChange={(e) => setNieuw({ ...nieuw, minLeeftijd: Number(e.target.value) })}>
            <LeeftijdOpties />
          </select>
        </label>
        <button className="mini-btn" type="submit">
          Klustype toevoegen
        </button>
      </form>
    </>
  )
}

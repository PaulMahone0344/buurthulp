// B9 — recensies (D4): de meldkamer verbergt een recensie (of zet hem terug).
// Een verborgen recensie telt niet mee voor sterren en XP en staat niet meer
// op het profiel of bij KiesHelper; dat rekent de hook (hh_xp.pb.js) meteen
// opnieuw uit. Daaronder: een "Verklaring van inzet" nakijken met de code.

import { useCallback, useState, type FormEvent } from 'react'
import type { BeheerData } from '../data/beheerData'
import { toonMoment } from '../data/tijd'
import type { Recensie, Verklaring } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil } from '../gedeeld/Pil'
import { useLaden } from '../gedeeld/useLaden'

const GEEN: Recensie[] = []
const melding = (e: unknown) => (e instanceof Error ? e.message : String(e))

export function Recensies({ data }: { data: BeheerData }) {
  const laad = useCallback(() => data.recensies(), [data])
  const lijst = useLaden(laad, GEEN)
  const [bezig, setBezig] = useState('')
  const [fout, setFout] = useState('')
  const [reden, setReden] = useState<Record<string, string>>({})

  async function zet(r: Recensie, verbergen: boolean) {
    setBezig(r.id)
    setFout('')
    try {
      await data.verbergRecensie(r.id, verbergen, verbergen ? (reden[r.id] ?? '').trim() : '')
      lijst.herlaad()
    } catch (e) {
      setFout(melding(e))
    } finally {
      setBezig('')
    }
  }

  return (
    <>
      <h2>Recensies</h2>
      <p className="beheer-hulp">
        Een verborgen recensie telt niet mee voor de sterren en de XP van de helper, en niemand ziet hem nog behalve de meldkamer.
      </p>
      <Foutmelding melding={lijst.fout || fout} />
      <div className="activity-list" aria-label="Recensies">
        {lijst.waarde.map((r) => (
          <article key={r.id}>
            <strong>
              {'★'.repeat(Math.max(0, Math.min(5, r.sterren)))} {r.vanNaam || 'Onbekend'} over {r.naarNaam || 'onbekend'}
              {r.verborgen ? (
                <>
                  {' '}
                  <Pil toon="stop">Verborgen</Pil>
                </>
              ) : null}
            </strong>
            <span>
              {toonMoment(r.gemaaktOp)} · “{r.tekst}”{r.verborgen && r.verborgenReden ? ` · reden: ${r.verborgenReden}` : ''}
            </span>
            {r.verborgen ? (
              <button className="btn btn-secondary" type="button" disabled={bezig === r.id} onClick={() => zet(r, false)}>
                Terugzetten
              </button>
            ) : (
              <div className="beheer-formulier beheer-formulier--rij">
                <label className="field">
                  <span>Reden (voor de meldkamer)</span>
                  <input
                    value={reden[r.id] ?? ''}
                    maxLength={300}
                    onChange={(e) => setReden({ ...reden, [r.id]: e.target.value })}
                    aria-label={`Reden om de recensie van ${r.vanNaam || 'onbekend'} te verbergen`}
                  />
                </label>
                <button className="btn btn-secondary" type="button" disabled={bezig === r.id} onClick={() => zet(r, true)}>
                  Verbergen
                </button>
              </div>
            )}
          </article>
        ))}
        {lijst.geladen && lijst.waarde.length === 0 ? <p className="empty-note">Nog geen recensies met tekst.</p> : null}
      </div>
      <VerklaringControle data={data} />
    </>
  )
}

function VerklaringControle({ data }: { data: BeheerData }) {
  const [code, setCode] = useState('')
  const [uitkomst, setUitkomst] = useState<Verklaring | null | undefined>(undefined)
  const [fout, setFout] = useState('')

  async function zoek(e: FormEvent) {
    e.preventDefault()
    setFout('')
    try {
      setUitkomst(await data.zoekVerklaring(code.trim()))
    } catch (err) {
      setFout(melding(err))
    }
  }

  return (
    <section aria-labelledby="verklaring-kop">
      <h2 id="verklaring-kop">Verklaring van inzet nakijken</h2>
      <form className="beheer-formulier beheer-formulier--rij" onSubmit={zoek}>
        <label className="field">
          <span>Controlecode</span>
          <input value={code} onChange={(e) => setCode(e.target.value)} placeholder="ABCDE-FGH23" autoComplete="off" />
        </label>
        <button className="btn btn-primary" type="submit" disabled={!code.trim()}>
          Nakijken
        </button>
      </form>
      <Foutmelding melding={fout} />
      {uitkomst === null ? <p className="empty-note">Deze code kennen we niet.</p> : null}
      {uitkomst ? (
        <div className="activity-list" aria-label="Gevonden verklaring">
          <article>
            <strong>
              {uitkomst.code} · {uitkomst.voornaam} · {uitkomst.klussen} klussen
              {uitkomst.uren ? ` · ±${uitkomst.uren} uur` : ''}
            </strong>
            <span>
              Uitgegeven {toonMoment(uitkomst.uitgegevenOp)}
              {uitkomst.periodeVan ? ` · ${uitkomst.periodeVan} t/m ${uitkomst.periodeTot}` : ''}
              {uitkomst.niveau ? ` · niveau ${uitkomst.niveau}` : ''}
            </span>
            {[...uitkomst.badges, ...uitkomst.vertrouwen].map((b) => (
              <span key={`${b.naam}-${b.datum}`}>
                · {b.naam} ({b.datum})
              </span>
            ))}
          </article>
        </div>
      ) : null}
    </section>
  )
}

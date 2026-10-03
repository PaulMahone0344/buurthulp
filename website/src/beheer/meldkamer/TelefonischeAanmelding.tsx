// M14 — telefonische aanmelding (D1). Stap 1: wie belt er (bestaande oudere
// zoeken op naam/telefoon, of een nieuwe aanmaken). Stap 2: de klus. Daarna
// loopt hij precies zoals een klus uit de app (status open, bron telefoon).

import { useCallback, useState, type FormEvent } from 'react'
import type { BeheerData } from '../data/beheerData'
import { controleerKlus, controleerOudere } from '../data/telefonisch'
import { nlTijdNaarIso, toonBedrag } from '../data/tijd'
import type { Klustype, NieuweOudere, Oudere, Wijk } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { useLaden } from '../gedeeld/useLaden'

type Props = {
  data: BeheerData
  opSluit: () => void
  opGeplaatst: (naam: string) => void
}

const GEEN_WIJKEN: Wijk[] = []
const GEEN_TYPES: Klustype[] = []
const LEGE_OUDERE: NieuweOudere = { naam: '', telefoon: '', email: '', adres: '', postcode: '', plaats: '', wijkId: '' }

export function TelefonischeAanmelding({ data, opSluit, opGeplaatst }: Props) {
  const laadWijken = useCallback(() => data.wijken(), [data])
  const laadTypes = useCallback(() => data.klustypes(), [data])
  const wijken = useLaden(laadWijken, GEEN_WIJKEN)
  const klustypes = useLaden(laadTypes, GEEN_TYPES)

  const [oudere, setOudere] = useState<Oudere | null>(null)
  const [zoek, setZoek] = useState('')
  const [gevonden, setGevonden] = useState<Oudere[] | null>(null)
  const [nieuw, setNieuw] = useState<NieuweOudere | null>(null)
  const [klustypeId, setKlustypeId] = useState('')
  const [omschrijving, setOmschrijving] = useState('')
  const [adres, setAdres] = useState('')
  const [datum, setDatum] = useState('')
  const [van, setVan] = useState('')
  const [tot, setTot] = useState('')
  const [fout, setFout] = useState('')
  const [bezig, setBezig] = useState(false)

  function kies(o: Oudere) {
    setOudere(o)
    setAdres([o.adres, o.plaats].filter(Boolean).join(', '))
    setFout('')
  }

  async function zoekOuderen(e: FormEvent) {
    e.preventDefault()
    setFout('')
    try {
      setGevonden(await data.zoekOuderen(zoek))
    } catch (err) {
      setFout(err instanceof Error ? err.message : String(err))
    }
  }

  async function maakNieuw(e: FormEvent) {
    e.preventDefault()
    if (!nieuw) return
    const probleem = controleerOudere(nieuw)
    if (probleem) return setFout(probleem)
    setBezig(true)
    try {
      kies(await data.maakOudere(nieuw))
      setNieuw(null)
    } catch (err) {
      setFout(err instanceof Error ? err.message : String(err))
    } finally {
      setBezig(false)
    }
  }

  async function plaats(e: FormEvent) {
    e.preventDefault()
    if (!oudere) return
    const klus = {
      hulpvragerId: oudere.id,
      klustypeId,
      omschrijving,
      adres,
      wanneerVan: nlTijdNaarIso(datum, van),
      wanneerTot: nlTijdNaarIso(datum, tot),
    }
    const probleem = controleerKlus(klus)
    if (probleem) return setFout(probleem)
    setBezig(true)
    setFout('')
    try {
      await data.maakTelefonischeKlus(klus)
      opGeplaatst(oudere.naam)
    } catch (err) {
      setFout(err instanceof Error ? err.message : String(err))
      setBezig(false)
    }
  }

  const type = klustypes.waarde.find((t) => t.id === klustypeId)
  const zetNieuw = (veld: keyof NieuweOudere, waarde: string) => setNieuw((n) => (n ? { ...n, [veld]: waarde } : n))

  return (
    <div className="beheer-venster-achtergrond">
      <div className="beheer-venster beheer-venster--breed" role="dialog" aria-modal="true" aria-labelledby="tel-titel">
        <h2 id="tel-titel">Telefonische aanmelding</h2>

        {!oudere && !nieuw ? (
          <>
            <form className="beheer-formulier" onSubmit={(e) => void zoekOuderen(e)}>
              <label className="field">
                <span>Zoek de oudere op naam of telefoon</span>
                <input value={zoek} onChange={(e) => setZoek(e.target.value)} />
              </label>
              <button className="mini-btn" type="submit">
                Zoeken
              </button>
            </form>
            {gevonden ? (
              <div className="request-table" aria-label="Gevonden ouderen">
                {gevonden.map((o) => (
                  <div className="request-row request-row--beheer" key={o.id}>
                    <div>
                      <strong>{o.naam}</strong>
                      <span>
                        {o.telefoon} · {[o.adres, o.plaats].filter(Boolean).join(', ')}
                      </span>
                    </div>
                    <span />
                    <button className="mini-btn" type="button" onClick={() => kies(o)}>
                      Kies {o.naam}
                    </button>
                  </div>
                ))}
                {gevonden.length === 0 ? <p className="empty-note">Niemand gevonden.</p> : null}
              </div>
            ) : null}
            <button className="mini-btn mini-btn--ghost" type="button" onClick={() => setNieuw({ ...LEGE_OUDERE, telefoon: /\d/.test(zoek) ? zoek : '' })}>
              Nieuwe oudere aanmaken
            </button>
          </>
        ) : null}

        {nieuw ? (
          <form className="beheer-formulier beheer-formulier--raster" onSubmit={(e) => void maakNieuw(e)} aria-label="Nieuwe oudere">
            <label className="field">
              <span>Naam</span>
              <input value={nieuw.naam} onChange={(e) => zetNieuw('naam', e.target.value)} />
            </label>
            <label className="field">
              <span>Telefoon</span>
              <input value={nieuw.telefoon} onChange={(e) => zetNieuw('telefoon', e.target.value)} />
            </label>
            <label className="field">
              <span>E-mail (mag leeg)</span>
              <input type="email" value={nieuw.email} onChange={(e) => zetNieuw('email', e.target.value)} />
            </label>
            <label className="field">
              <span>Adres</span>
              <input value={nieuw.adres} onChange={(e) => zetNieuw('adres', e.target.value)} />
            </label>
            <label className="field">
              <span>Postcode</span>
              <input value={nieuw.postcode} onChange={(e) => zetNieuw('postcode', e.target.value)} />
            </label>
            <label className="field">
              <span>Plaats</span>
              <input value={nieuw.plaats} onChange={(e) => zetNieuw('plaats', e.target.value)} />
            </label>
            <label className="field">
              <span>Wijk</span>
              <select value={nieuw.wijkId} onChange={(e) => zetNieuw('wijkId', e.target.value)}>
                <option value="">Kies een wijk</option>
                {wijken.waarde.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.wijk} ({w.gemeente})
                  </option>
                ))}
              </select>
            </label>
            <button className="mini-btn" type="submit" disabled={bezig}>
              Oudere aanmaken
            </button>
          </form>
        ) : null}

        {oudere ? (
          <form className="beheer-formulier beheer-formulier--raster" onSubmit={(e) => void plaats(e)} aria-label="Hulpvraag">
            <p className="admin-muted">
              Hulpvraag voor <strong>{oudere.naam}</strong> ({oudere.telefoon})
            </p>
            <label className="field">
              <span>Soort klus</span>
              <select value={klustypeId} onChange={(e) => setKlustypeId(e.target.value)}>
                <option value="">Kies een soort klus</option>
                {klustypes.waarde.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.naam}
                  </option>
                ))}
              </select>
            </label>
            {type ? <p className="beheer-hulp">Vergoeding {toonBedrag(type.richtvergoeding)}, ongeveer {type.richtduur} minuten.</p> : null}
            <label className="field">
              <span>Omschrijving</span>
              <textarea rows={2} value={omschrijving} onChange={(e) => setOmschrijving(e.target.value)} />
            </label>
            <label className="field">
              <span>Adres van de klus</span>
              <input value={adres} onChange={(e) => setAdres(e.target.value)} />
            </label>
            <label className="field">
              <span>Datum</span>
              <input type="date" value={datum} onChange={(e) => setDatum(e.target.value)} />
            </label>
            <label className="field">
              <span>Van</span>
              <input type="time" value={van} onChange={(e) => setVan(e.target.value)} />
            </label>
            <label className="field">
              <span>Tot</span>
              <input type="time" value={tot} onChange={(e) => setTot(e.target.value)} />
            </label>
            <button className="mini-btn" type="submit" disabled={bezig}>
              Hulpvraag plaatsen
            </button>
          </form>
        ) : null}

        <Foutmelding melding={fout || wijken.fout || klustypes.fout} />
        <div className="beheer-venster__knoppen">
          <button className="mini-btn mini-btn--ghost" type="button" onClick={opSluit}>
            Sluiten
          </button>
        </div>
      </div>
    </div>
  )
}

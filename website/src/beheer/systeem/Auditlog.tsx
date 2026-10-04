// M14 — het auditlog (D4): wie deed welke beheerhandeling. De regels schrijft
// alleen de hook hh_beheer.pb.js; lezen kan alleen de coordinator.

import { useCallback, useState } from 'react'
import type { BeheerData } from '../data/beheerData'
import { filterAuditlog, type Auditfilter } from '../data/filters'
import { toonMoment } from '../data/tijd'
import type { Auditregel } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { useLaden } from '../gedeeld/useLaden'

const GEEN: Auditregel[] = []
const ACTIES = [
  { id: '', label: 'Alle acties' },
  { id: 'aanmaken', label: 'Aanmaken' },
  { id: 'wijzigen', label: 'Wijzigen' },
  { id: 'verwijderen', label: 'Verwijderen' },
]

type Props = { data: BeheerData; actie: string; persoon: string; zetFilter: (filter: Auditfilter) => void }

/**
 * De server bewaart het detail als JSON ({"velden":[...],"waarden":{...}}).
 * In de tabel staat alleen welke velden geraakt zijn; de hele regel zit
 * achter een uitklapper. Geen JSON = de tekst zelf.
 */
function veldenUitDetail(detail: string): string {
  try {
    const gelezen: unknown = JSON.parse(detail)
    const velden = typeof gelezen === 'object' && gelezen !== null ? (gelezen as { velden?: unknown }).velden : undefined
    if (Array.isArray(velden) && velden.length) return velden.map(String).join(', ')
  } catch {
    // geen JSON: hieronder de tekst zelf
  }
  return detail
}

export function Auditlog({ data, actie, persoon, zetFilter }: Props) {
  const laad = useCallback(() => data.auditlog(), [data])
  const regels = useLaden(laad, GEEN)
  const [persoonInvoer, setPersoonInvoer] = useState(persoon)
  const zichtbaar = filterAuditlog(regels.waarde, { actie, persoon })

  return (
    <>
      <h2>Auditlog</h2>
      <div className="beheer-formulier beheer-formulier--rij">
        <label className="field">
          <span>Actie</span>
          <select value={actie} onChange={(e) => zetFilter({ actie: e.target.value, persoon })}>
            {ACTIES.map((a) => (
              <option key={a.id} value={a.id}>
                {a.label}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>Persoon</span>
          <input
            value={persoonInvoer}
            onChange={(e) => setPersoonInvoer(e.target.value)}
            onBlur={() => zetFilter({ actie, persoon: persoonInvoer.trim() })}
            onKeyDown={(e) => {
              if (e.key === 'Enter') zetFilter({ actie, persoon: persoonInvoer.trim() })
            }}
          />
        </label>
      </div>
      <Foutmelding melding={regels.fout} />
      <div className="beheer-tabel-wrap">
        <table className="beheer-tabel" aria-label="Auditregels">
          <thead>
            <tr>
              <th scope="col">Wanneer</th>
              <th scope="col">Wie</th>
              <th scope="col">Actie</th>
              <th scope="col">Onderdeel</th>
              <th scope="col">Detail</th>
            </tr>
          </thead>
          <tbody>
            {zichtbaar.map((r) => (
              <tr key={r.id}>
                <td className="beheer-tabel__kort">{toonMoment(r.gebeurdOp)}</td>
                <td>{r.doorNaam || 'Onbekend'}</td>
                <td>{r.actie}</td>
                <td>{r.doelCollectie}</td>
                <td className="beheer-tabel__detail">
                  {r.detail ? (
                    <details>
                      <summary>{`${r.doelId} · ${veldenUitDetail(r.detail)}`}</summary>
                      <pre>{r.detail}</pre>
                    </details>
                  ) : (
                    r.doelId
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {regels.geladen && zichtbaar.length === 0 ? <p className="empty-note">Geen regels.</p> : null}
      </div>
    </>
  )
}

// M14 — D2 SCREENING JONGEREN. Tegels (wachtend | VOG loopt | afgewezen deze
// maand), de wachtrij (verificatiestatus in_behandeling, oudste eerst), het
// signaal "VOG verloopt binnen 60 dagen", en per jongere de documenten naast
// elkaar met goedkeuren of afkeuren (altijd met notitie).

import { useCallback } from 'react'
import { Users } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { screeningTegels, vogSignaal } from '../data/tegels'
import { toonDatum } from '../data/tijd'
import type { Profiel } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil } from '../gedeeld/Pil'
import { Tegel } from '../gedeeld/Tegel'
import { useLaden } from '../gedeeld/useLaden'
import { SCREENING_LABEL } from '../teksten'
import { ScreeningDetail } from './ScreeningDetail'

type Props = {
  data: BeheerData
  filters: Record<string, string>
  zetFilters: (filters: Record<string, string>) => void
  nu: () => Date
}

const GEEN: Profiel[] = []
type Lijst = 'wachtrij' | 'signalen' | 'alle'
const LIJSTEN: Array<{ id: Lijst; label: string }> = [
  { id: 'wachtrij', label: 'Wachtrij' },
  { id: 'signalen', label: 'VOG verloopt' },
  { id: 'alle', label: 'Alle jongeren' },
]

export function Screening({ data, filters, zetFilters, nu }: Props) {
  const laad = useCallback(() => data.profielen(), [data])
  const profielen = useLaden(laad, GEEN)
  const vandaag = nu()
  const tegels = screeningTegels(profielen.waarde, vandaag)
  const lijst: Lijst = LIJSTEN.some((l) => l.id === filters.lijst) ? (filters.lijst as Lijst) : 'wachtrij'

  const perLijst = (id: Lijst) => {
    if (id === 'wachtrij') {
      return profielen.waarde
        .filter((p) => p.verificatiestatus === 'in_behandeling')
        .sort((a, b) => a.bijgewerktOp.localeCompare(b.bijgewerktOp))
    }
    if (id === 'signalen') return profielen.waarde.filter((p) => vogSignaal(p.vogGeldigTot, vandaag) !== '')
    return profielen.waarde
  }
  const zichtbaar = perLijst(lijst)
  const gekozen = profielen.waarde.find((p) => p.id === filters.jongere)

  return (
    <>
      <header className="dashboard-topbar">
        <div>
          <h1>Screening</h1>
          <p>Helpers die gecontroleerd moeten worden: ID en (vanaf 18) VOG.</p>
        </div>
      </header>
      <div className="admin-stat-grid admin-stat-grid--drie">
        <Tegel label="Wachtend op beoordeling" waarde={tegels.wachtend} />
        <Tegel label="VOG loopt" waarde={tegels.vogLoopt} />
        <Tegel label="Afgewezen deze maand" waarde={tegels.afgewezenDezeMaand} />
      </div>
      <Foutmelding melding={profielen.fout} />
      <div className="beheer-kolommen">
        <section className="admin-card">
          <div className="admin-card__header">
            <div>
              <Users size={22} />
              <h2>Jongeren</h2>
            </div>
          </div>
          <div className="seg" role="tablist" aria-label="Welke jongeren">
            {LIJSTEN.map((l) => (
              <button
                key={l.id}
                type="button"
                role="tab"
                aria-selected={lijst === l.id}
                className={`seg-btn${lijst === l.id ? ' is-active' : ''}`}
                onClick={() => zetFilters({ lijst: l.id })}
              >
                {l.label} <span className="seg-count">{perLijst(l.id).length}</span>
              </button>
            ))}
          </div>
          <div className="helper-list" aria-label="Jongeren">
            {zichtbaar.map((p) => {
              const signaal = vogSignaal(p.vogGeldigTot, vandaag)
              return (
                <article className="helper-row helper-row--beheer" key={p.id}>
                  <div>
                    <strong>{p.naam || p.email}</strong>
                    <span>
                      {p.wijkNaam || 'geen wijk'} · VOG {SCREENING_LABEL[p.vogStatus].toLowerCase()}
                    </span>
                    {signaal ? (
                      <span className="beheer-signaal">
                        {signaal === 'verlopen' ? 'VOG verlopen' : 'VOG verloopt binnen 60 dagen'} ({toonDatum(p.vogGeldigTot)})
                      </span>
                    ) : null}
                  </div>
                  <Pil toon={p.verificatiestatus === 'goedgekeurd' ? 'klaar' : p.verificatiestatus === 'afgewezen' ? 'fout' : 'nieuw'}>
                    {SCREENING_LABEL[p.verificatiestatus]}
                  </Pil>
                  <button className="mini-btn" type="button" onClick={() => zetFilters({ lijst, jongere: p.id })}>
                    Bekijk {p.naam}
                  </button>
                </article>
              )
            })}
            {profielen.geladen && zichtbaar.length === 0 ? <p className="empty-note">Niemand in deze lijst.</p> : null}
          </div>
        </section>
        {gekozen ? (
          <ScreeningDetail
            key={gekozen.id}
            data={data}
            profiel={gekozen}
            nu={nu}
            opSluit={() => zetFilters({ lijst })}
            opBeoordeeld={() => void profielen.herlaad()}
          />
        ) : null}
      </div>
    </>
  )
}

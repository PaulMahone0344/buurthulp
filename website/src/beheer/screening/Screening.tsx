// M14 — D2 SCREENING HELPERS (koers B: helpers, niet jongeren). Tegels (wachtend | VOG loopt | afgewezen deze
// maand), de wachtrij (verificatiestatus in_behandeling, oudste eerst), het
// signaal "VOG verloopt binnen 60 dagen", en per jongere de documenten naast
// elkaar met goedkeuren of afkeuren (altijd met notitie).
// B11: lijst "VOG nodig" = helpers 18+ zonder VOG of met een verlopen VOG
// (GET /api/hh/meldkamer/vog), met de knop "VOG gezien".

import { useCallback, useState } from 'react'
import { Users } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { screeningTegels, vogSignaal } from '../data/tegels'
import { toonDatum } from '../data/tijd'
import type { Profiel, VogRij } from '../data/types'
import { Bevestigvenster } from '../gedeeld/Bevestigvenster'
import { Foutmelding, Gelukt } from '../gedeeld/Meldbalk'
import { AdresBronPil, Pil } from '../gedeeld/Pil'
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
const GEEN_VOG: VogRij[] = []
type Lijst = 'wachtrij' | 'vog' | 'signalen' | 'alle'
const LIJSTEN: Array<{ id: Lijst; label: string }> = [
  { id: 'wachtrij', label: 'Wachtrij' },
  { id: 'vog', label: 'VOG nodig' },
  { id: 'signalen', label: 'VOG verloopt' },
  { id: 'alle', label: 'Alle helpers' },
]

const VOG_REDEN = (r: VogRij) => (r.reden === 'geen' ? 'nog geen VOG gezien' : `VOG verlopen op ${toonDatum(r.verlooptOp)}`)

export function Screening({ data, filters, zetFilters, nu }: Props) {
  const laad = useCallback(() => data.profielen(), [data])
  const profielen = useLaden(laad, GEEN)
  const laadVog = useCallback(() => data.vogWachtrij(), [data])
  const vog = useLaden(laadVog, GEEN_VOG)
  const [vogGezien, setVogGezien] = useState<VogRij | null>(null)
  const [gelukt, setGelukt] = useState('')
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
  const aantal = (id: Lijst) => (id === 'vog' ? vog.waarde.length : perLijst(id).length)
  const zichtbaar = lijst === 'vog' ? [] : perLijst(lijst)
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
      <Gelukt melding={gelukt} />
      <Foutmelding melding={profielen.fout || vog.fout} />
      <div className="beheer-kolommen">
        <section className="admin-card">
          <div className="admin-card__header">
            <div>
              <Users size={22} />
              <h2>Helpers</h2>
            </div>
          </div>
          <div className="seg" role="tablist" aria-label="Welke helpers">
            {LIJSTEN.map((l) => (
              <button
                key={l.id}
                type="button"
                role="tab"
                aria-selected={lijst === l.id}
                className={`seg-btn${lijst === l.id ? ' is-active' : ''}`}
                onClick={() => zetFilters({ lijst: l.id })}
              >
                {l.label} <span className="seg-count">{aantal(l.id)}</span>
              </button>
            ))}
          </div>
          {lijst === 'vog' ? (
            <div className="helper-list" aria-label="Helpers die een VOG nodig hebben">
              {vog.waarde.map((r) => (
                <article className="helper-row helper-row--beheer" key={r.profielId}>
                  <div>
                    <strong>{r.naam}</strong>
                    <span>
                      {r.leeftijd} jaar · {VOG_REDEN(r)}
                    </span>
                  </div>
                  <Pil toon={r.reden === 'geen' ? 'nieuw' : 'fout'}>{r.reden === 'geen' ? 'Geen VOG' : 'Verlopen'}</Pil>
                  <div className="beheer-acties">
                    <button className="mini-btn" type="button" aria-label={`VOG gezien: ${r.naam}`} onClick={() => setVogGezien(r)}>
                      VOG gezien
                    </button>
                    <button className="mini-btn mini-btn--ghost" type="button" onClick={() => zetFilters({ lijst, jongere: r.profielId })}>
                      Bekijk {r.naam}
                    </button>
                  </div>
                </article>
              ))}
              {vog.geladen && vog.waarde.length === 0 ? <p className="empty-note">Iedereen van 18+ heeft een geldige VOG.</p> : null}
            </div>
          ) : null}
          <div className="helper-list" aria-label="Helpers" hidden={lijst === 'vog'}>
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
                    <AdresBronPil bron={p.adresBron} />
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
            {profielen.geladen && lijst !== 'vog' && zichtbaar.length === 0 ? <p className="empty-note">Niemand in deze lijst.</p> : null}
          </div>
        </section>
        {gekozen ? (
          <ScreeningDetail
            key={gekozen.id}
            data={data}
            profiel={gekozen}
            nu={nu}
            opSluit={() => zetFilters({ lijst })}
            opBeoordeeld={() => {
              void profielen.herlaad()
              void vog.herlaad()
            }}
          />
        ) : null}
      </div>
      {vogGezien ? (
        <Bevestigvenster
          titel={`VOG van ${vogGezien.naam} gezien`}
          bevestigTekst="VOG gezien"
          opSluit={() => setVogGezien(null)}
          opBevestig={async () => {
            await data.vogGezien(vogGezien.profielId)
            setGelukt(`VOG van ${vogGezien.naam} staat erin (vandaag gezien, 3 jaar geldig).`)
            setVogGezien(null)
            void vog.herlaad()
            void profielen.herlaad()
          }}
        >
          <p className="admin-muted">Heb je de originele VOG van {vogGezien.naam} gezien? Dan zetten we vandaag als datum.</p>
        </Bevestigvenster>
      ) : null}
    </>
  )
}

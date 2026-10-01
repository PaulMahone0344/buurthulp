// M14 — het beheerpaneel: D1 meldkamer, D2 screening, D4 systeembeheer.
// Zelfde schil als het bestaande AdminDashboard (zijbalk + hoofdvlak); waar
// je bent en welke filters aan staan, staat in de hash van de URL.

import { useCallback, useEffect, useState } from 'react'
import { LogOut, ShieldCheck } from 'lucide-react'
import type { BeheerData } from './data/beheerData'
import type { Coordinator } from './data/types'
import { BeheerLogin } from './BeheerLogin'
import { Meldkamer } from './meldkamer/Meldkamer'
import { leesLocatie, ONDERDELEN, schrijfLocatie, type Locatie } from './navigatie'
import { Screening } from './screening/Screening'
import { Systeem } from './systeem/Systeem'
import { ONDERDEEL_LABEL } from './teksten'
import './beheer.css'

type Props = {
  data: BeheerData
  /** De klok; vast te zetten in tests. */
  nu?: () => Date
}

const echteKlok = () => new Date()

export function BeheerApp({ data, nu = echteKlok }: Props) {
  const [coordinator, setCoordinator] = useState<Coordinator | null>(() => data.huidige())
  const [hash, setHash] = useState(() => window.location.hash)

  useEffect(() => {
    const opWissel = () => setHash(window.location.hash)
    window.addEventListener('hashchange', opWissel)
    return () => window.removeEventListener('hashchange', opWissel)
  }, [])

  const locatie = leesLocatie(hash)

  const ga = useCallback((naar: Locatie) => {
    const nieuw = schrijfLocatie(naar)
    if (window.location.hash !== nieuw) window.location.hash = nieuw
    setHash(nieuw)
  }, [])

  const zetFilters = useCallback(
    (filters: Record<string, string>) => ga({ onderdeel: locatie.onderdeel, filters }),
    [ga, locatie.onderdeel],
  )

  function uitloggen() {
    data.uitloggen()
    setCoordinator(null)
  }

  if (!coordinator) return <BeheerLogin data={data} opIngelogd={setCoordinator} />

  return (
    <main className="dashboard-shell">
      <aside className="dashboard-sidebar">
        <div className="dashboard-brand">
          <ShieldCheck size={25} />
          <span>HeitjeHulp beheer</span>
        </div>
        <nav className="dashboard-nav" aria-label="Beheer navigatie">
          {ONDERDELEN.map((onderdeel) => (
            <a
              key={onderdeel}
              className={locatie.onderdeel === onderdeel ? 'is-active' : undefined}
              aria-current={locatie.onderdeel === onderdeel ? 'page' : undefined}
              href={schrijfLocatie({ onderdeel, filters: {} })}
              onClick={(e) => {
                e.preventDefault()
                ga({ onderdeel, filters: {} })
              }}
            >
              {ONDERDEEL_LABEL[onderdeel]}
            </a>
          ))}
        </nav>
        <button className="logout-button" type="button" onClick={uitloggen}>
          <LogOut size={18} />
          Uitloggen
        </button>
      </aside>

      <section className="dashboard-main">
        <p className="section-label">Ingelogd als {coordinator.naam || coordinator.email}</p>
        {locatie.onderdeel === 'meldkamer' ? (
          <Meldkamer data={data} filters={locatie.filters} zetFilters={zetFilters} nu={nu} />
        ) : null}
        {locatie.onderdeel === 'screening' ? (
          <Screening data={data} filters={locatie.filters} zetFilters={zetFilters} nu={nu} />
        ) : null}
        {locatie.onderdeel === 'systeem' ? (
          <Systeem data={data} filters={locatie.filters} zetFilters={zetFilters} />
        ) : null}
      </section>
    </main>
  )
}

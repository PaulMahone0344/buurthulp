// M14 — D4 SYSTEEMBEHEER. Acht tabbladen (B9: Recensies, B11: Partners); het gekozen tabblad staat in de URL
// (?tab=...). D3 (gemeentecijfers) is M15 en hoort hier niet.

import type { BeheerData } from '../data/beheerData'
import { Auditlog } from './Auditlog'
import { Betalingen } from './Betalingen'
import { Gebruikers } from './Gebruikers'
import { Instellingen } from './Instellingen'
import { Klustypes } from './Klustypes'
import { Partners } from './Partners'
import { Recensies } from './Recensies'
import { Wijken } from './Wijken'

type Props = {
  data: BeheerData
  filters: Record<string, string>
  zetFilters: (filters: Record<string, string>) => void
}

const TABS = [
  { id: 'wijken', label: 'Wijken' },
  { id: 'klustypes', label: 'Klustypes' },
  { id: 'gebruikers', label: 'Gebruikers' },
  { id: 'instellingen', label: 'Instellingen' },
  { id: 'betalingen', label: 'Betalingen' },
  { id: 'auditlog', label: 'Auditlog' },
  // B9: recensies verbergen en een verklaring van inzet nakijken.
  { id: 'recensies', label: 'Recensies' },
  // B11: jongerenwerk-organisaties met een code (alleen tellen).
  { id: 'partners', label: 'Partners' },
] as const
type Tab = (typeof TABS)[number]['id']

export function Systeem({ data, filters, zetFilters }: Props) {
  const tab: Tab = TABS.some((t) => t.id === filters.tab) ? (filters.tab as Tab) : 'wijken'
  const zetTabFilters = (extra: Record<string, string>) => zetFilters({ tab, ...extra })

  return (
    <>
      <header className="dashboard-topbar">
        <div>
          <h1>Systeembeheer</h1>
          <p>Wijken, klustypes, gebruikers, instellingen, betalingen, het auditlog, recensies en partners.</p>
        </div>
      </header>
      <div className="seg" role="tablist" aria-label="Onderdelen systeembeheer">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            role="tab"
            aria-selected={tab === t.id}
            className={`seg-btn${tab === t.id ? ' is-active' : ''}`}
            onClick={() => zetFilters({ tab: t.id })}
          >
            {t.label}
          </button>
        ))}
      </div>
      <section className="admin-card">
        {tab === 'wijken' ? <Wijken data={data} /> : null}
        {tab === 'klustypes' ? <Klustypes data={data} /> : null}
        {tab === 'gebruikers' ? <Gebruikers data={data} zoek={filters.zoek ?? ''} zetZoek={(zoek) => zetTabFilters({ zoek })} /> : null}
        {tab === 'instellingen' ? <Instellingen data={data} /> : null}
        {tab === 'betalingen' ? <Betalingen data={data} /> : null}
        {tab === 'recensies' ? <Recensies data={data} /> : null}
        {tab === 'partners' ? <Partners data={data} /> : null}
        {tab === 'auditlog' ? (
          <Auditlog
            data={data}
            actie={filters.actie ?? ''}
            persoon={filters.persoon ?? ''}
            zetFilter={(f) => zetTabFilters({ actie: f.actie, persoon: f.persoon })}
          />
        ) : null}
      </section>
    </>
  )
}

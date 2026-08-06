import { useMemo, useState } from 'react'
import {
  AlertTriangle,
  ArrowRight,
  Bell,
  ClipboardList,
  FileText,
  LogOut,
  ShieldCheck,
  Users,
} from 'lucide-react'
import {
  activityItems,
  adminStats,
  helpers as seedHelpers,
  helpRequests as seedRequests,
  incidents as seedIncidents,
  reportMetrics,
  type HelpRequest,
  type HelpRequestStatus,
  type Incident,
  type IncidentStatus,
  type ScreeningStatus,
} from '../domain/demoData'
import type { UserSession } from '../domain/auth'

type AdminDashboardProps = {
  user: UserSession
  onLogout: () => void
}

const statusClass: Record<HelpRequestStatus | ScreeningStatus, string> = {
  Nieuw: 'status-new',
  Gematcht: 'status-matched',
  'In uitvoering': 'status-active',
  Afgerond: 'status-done',
  Compleet: 'status-done',
  'VOG nodig': 'status-new',
  'Intake gepland': 'status-matched',
}

const requestFlow: HelpRequestStatus[] = ['Nieuw', 'Gematcht', 'In uitvoering', 'Afgerond']
const screeningFlow: ScreeningStatus[] = ['VOG nodig', 'Intake gepland', 'Compleet']
const incidentFlow: IncidentStatus[] = ['Open', 'In behandeling', 'Afgehandeld']
const requestFilters: (HelpRequestStatus | 'Alle')[] = ['Alle', 'Nieuw', 'Gematcht', 'In uitvoering', 'Afgerond']

const incidentStatusClass: Record<IncidentStatus, string> = {
  Open: 'status-new',
  'In behandeling': 'status-active',
  Afgehandeld: 'status-done',
}

const requestActionLabel: Record<HelpRequestStatus, string | null> = {
  Nieuw: 'Match jongere',
  Gematcht: 'Start klus',
  'In uitvoering': 'Markeer afgerond',
  Afgerond: null,
}

function next<T>(flow: T[], current: T): T {
  const index = flow.indexOf(current)
  return index >= 0 && index < flow.length - 1 ? flow[index + 1] : current
}

export function AdminDashboard({ user, onLogout }: AdminDashboardProps) {
  const [requests, setRequests] = useState<HelpRequest[]>(seedRequests)
  const [helperList, setHelperList] = useState(seedHelpers)
  const [incidentList, setIncidentList] = useState<Incident[]>(seedIncidents)
  const [filter, setFilter] = useState<HelpRequestStatus | 'Alle'>('Alle')

  const visibleRequests = useMemo(
    () => (filter === 'Alle' ? requests : requests.filter((r) => r.status === filter)),
    [requests, filter],
  )

  const openIncidents = incidentList.filter((i) => i.status !== 'Afgehandeld').length

  function advanceRequest(id: string) {
    setRequests((prev) =>
      prev.map((r) => (r.id === id ? { ...r, status: next(requestFlow, r.status) } : r)),
    )
  }

  function advanceScreening(id: string) {
    setHelperList((prev) =>
      prev.map((h) => (h.id === id ? { ...h, screening: next(screeningFlow, h.screening) } : h)),
    )
  }

  function advanceIncident(id: string) {
    setIncidentList((prev) =>
      prev.map((i) => (i.id === id ? { ...i, status: next(incidentFlow, i.status) } : i)),
    )
  }

  return (
    <main className="dashboard-shell">
      <aside className="dashboard-sidebar">
        <div className="dashboard-brand">
          <ShieldCheck size={25} />
          <span>BuurtHulp Admin</span>
        </div>
        <nav className="dashboard-nav" aria-label="Admin navigatie">
          <a className="is-active" href="#admin-overzicht">Overzicht</a>
          <a href="#admin-hulpvragen">Hulpvragen</a>
          <a href="#admin-jongeren">Jongeren</a>
          <a href="#admin-meldingen">Meldingen</a>
          <a href="#admin-rapportage">Rapportage</a>
        </nav>
        <button className="logout-button" type="button" onClick={onLogout}>
          <LogOut size={18} />
          Uitloggen
        </button>
      </aside>

      <section className="dashboard-main" id="admin-overzicht">
        <header className="dashboard-topbar">
          <div>
            <p className="section-label">Pilotwijk {user.neighborhood}</p>
            <h1>Admin panel</h1>
            <p>Welkom terug, {user.name}. Hier beheer je de BuurtHulp-pilot.</p>
          </div>
          <button className="button button--primary" type="button">
            Nieuwe hulpvraag
            <ArrowRight size={18} />
          </button>
        </header>

        <div className="admin-stat-grid">
          {adminStats.map((stat) => (
            <article className="admin-stat-card" key={stat.label}>
              <span>{stat.label}</span>
              <strong>{stat.value}</strong>
              <p>{stat.change}</p>
            </article>
          ))}
        </div>

        <div className="dashboard-grid">
          {/* HULPVRAGEN */}
          <section className="admin-card admin-card--wide" id="admin-hulpvragen">
            <div className="admin-card__header">
              <div>
                <ClipboardList size={22} />
                <h2>Hulpvragen</h2>
              </div>
            </div>
            <div className="seg" role="tablist" aria-label="Filter hulpvragen">
              {requestFilters.map((f) => {
                const count = f === 'Alle' ? requests.length : requests.filter((r) => r.status === f).length
                return (
                  <button
                    key={f}
                    type="button"
                    role="tab"
                    aria-selected={filter === f}
                    className={`seg-btn${filter === f ? ' is-active' : ''}`}
                    onClick={() => setFilter(f)}
                  >
                    {f} <span className="seg-count">{count}</span>
                  </button>
                )
              })}
            </div>
            <div className="request-table" role="table" aria-label="Hulpvragen">
              {visibleRequests.map((request) => (
                <div className="request-row request-row--admin" role="row" key={request.id}>
                  <div>
                    <strong>{request.resident}</strong>
                    <span>
                      {request.type} · {request.neighborhood}
                      {request.helper ? ` · ${request.helper}` : ''}
                    </span>
                  </div>
                  <span className={`status-pill ${statusClass[request.status]}`}>{request.status}</span>
                  {requestActionLabel[request.status] ? (
                    <button className="mini-btn" type="button" onClick={() => advanceRequest(request.id)}>
                      {requestActionLabel[request.status]}
                    </button>
                  ) : (
                    <span className="row-muted">Klaar</span>
                  )}
                </div>
              ))}
              {visibleRequests.length === 0 && <p className="empty-note">Geen hulpvragen in dit filter.</p>}
            </div>
          </section>

          {/* VEILIGHEID / METER */}
          <section className="admin-card">
            <div className="admin-card__header">
              <div>
                <ShieldCheck size={22} />
                <h2>Veiligheid</h2>
              </div>
            </div>
            <div className="safety-meter">
              <strong>96%</strong>
              <span>klussen zonder melding</span>
            </div>
            <p className="admin-muted">
              {openIncidents === 0
                ? 'Geen open meldingen — alles is opgevolgd.'
                : `${openIncidents} ${openIncidents === 1 ? 'melding staat' : 'meldingen staan'} open voor opvolging.`}
            </p>
          </section>

          {/* JONGEREN */}
          <section className="admin-card admin-card--wide" id="admin-jongeren">
            <div className="admin-card__header">
              <div>
                <Users size={22} />
                <h2>Jongeren screening</h2>
              </div>
            </div>
            <div className="helper-list">
              {helperList.map((helper) => (
                <article className="helper-row helper-row--admin" key={helper.id}>
                  <div>
                    <strong>{helper.name}</strong>
                    <span>
                      {helper.age} jaar · {helper.neighborhood} · {helper.completedJobs} klussen · ★ {helper.rating}
                    </span>
                  </div>
                  <span className={`status-pill ${statusClass[helper.screening]}`}>{helper.screening}</span>
                  {helper.screening === 'Compleet' ? (
                    <span className="row-muted">Actief</span>
                  ) : (
                    <button className="mini-btn" type="button" onClick={() => advanceScreening(helper.id)}>
                      {helper.screening === 'VOG nodig' ? 'Plan intake' : 'Rond screening af'}
                    </button>
                  )}
                </article>
              ))}
            </div>
          </section>

          {/* MELDINGEN */}
          <section className="admin-card admin-card--wide" id="admin-meldingen">
            <div className="admin-card__header">
              <div>
                <Bell size={22} />
                <h2>Meldingen & incidenten</h2>
              </div>
            </div>
            <div className="incident-list">
              {incidentList.map((incident) => (
                <article className="incident-row" key={incident.id}>
                  <span className={`sev sev--${incident.severity.toLowerCase()}`}>{incident.severity}</span>
                  <div>
                    <strong>{incident.summary}</strong>
                    <span>{incident.neighborhood} · {incident.reportedAt}</span>
                  </div>
                  <span className={`status-pill ${incidentStatusClass[incident.status]}`}>{incident.status}</span>
                  {incident.status === 'Afgehandeld' ? (
                    <span className="row-muted">Gesloten</span>
                  ) : (
                    <button className="mini-btn" type="button" onClick={() => advanceIncident(incident.id)}>
                      {incident.status === 'Open' ? 'In behandeling' : 'Afhandelen'}
                    </button>
                  )}
                </article>
              ))}
            </div>
          </section>

          {/* RAPPORTAGE */}
          <section className="admin-card admin-card--wide" id="admin-rapportage">
            <div className="admin-card__header">
              <div>
                <FileText size={22} />
                <h2>Rapportage richting gemeente</h2>
              </div>
              <button className="ghost-button" type="button">Exporteer</button>
            </div>
            <div className="report-list">
              {reportMetrics.map((metric) => {
                const pct = Math.min(100, Math.round((metric.value / metric.target) * 100))
                return (
                  <div className="report-row" key={metric.label}>
                    <div className="report-row__head">
                      <span>{metric.label}</span>
                      <strong>
                        {metric.value}
                        {metric.unit ?? ''} <em>/ {metric.target}{metric.unit ?? ''}</em>
                      </strong>
                    </div>
                    <div className="report-bar">
                      <span style={{ width: `${pct}%` }} />
                    </div>
                  </div>
                )
              })}
            </div>
          </section>

          {/* ACTIVITEIT */}
          <section className="admin-card">
            <div className="admin-card__header">
              <div>
                <AlertTriangle size={22} />
                <h2>Recente activiteit</h2>
              </div>
            </div>
            <div className="activity-list">
              {activityItems.map((item) => (
                <article key={item.id}>
                  <strong>{item.label}</strong>
                  <span>{item.meta}</span>
                </article>
              ))}
            </div>
          </section>
        </div>
      </section>
    </main>
  )
}

import { useState, type ComponentType, type FormEvent } from 'react'
import {
  Award,
  ArrowRight,
  CalendarCheck,
  Check,
  HandHeart,
  Heart,
  LogOut,
  MapPin,
  Phone,
  Plus,
  Smartphone,
  Sparkles,
  Star,
  Trophy,
  Type,
  Wallet,
} from 'lucide-react'
import type { UserSession } from '../domain/auth'
import {
  helperBadges,
  helperJobs as seedJobs,
  helperOpportunities as seedOpps,
  helperProfile,
  requestTypeOptions,
  residentFavorite,
  residentRequests as seedResidentRequests,
  type HelperJob,
  type HelperJobStatus,
  type HelpRequestStatus,
  type Opportunity,
  type ResidentRequest,
} from '../domain/demoData'

type UserPortalProps = {
  user: UserSession
  onLogout: () => void
}

const badgeIcons: Record<string, ComponentType<{ size?: number }>> = {
  Sparkles,
  Heart,
  Smartphone,
  Star,
  Trophy,
  Award,
}

const statusClass: Record<HelpRequestStatus, string> = {
  Nieuw: 'status-new',
  Gematcht: 'status-matched',
  'In uitvoering': 'status-active',
  Afgerond: 'status-done',
}

const jobStatusClass: Record<HelperJobStatus, string> = {
  Geaccepteerd: 'status-matched',
  Onderweg: 'status-active',
  Afgerond: 'status-done',
}

const jobFlow: HelperJobStatus[] = ['Geaccepteerd', 'Onderweg', 'Afgerond']

function euros(value: string): number {
  const n = Number.parseFloat(value.replace(/[^\d,.-]/g, '').replace(',', '.'))
  return Number.isFinite(n) ? n : 0
}

/* ============================ HELPER PORTAL ============================ */

type HelperTab = 'beschikbaar' | 'klussen' | 'profiel'

export function HelperPortal({ user, onLogout }: UserPortalProps) {
  const [tab, setTab] = useState<HelperTab>('beschikbaar')
  const [opps, setOpps] = useState<Opportunity[]>(seedOpps)
  const [jobs, setJobs] = useState<HelperJob[]>(seedJobs)
  const [points, setPoints] = useState(helperProfile.points)
  const [earned, setEarned] = useState(euros(helperProfile.earnings))
  const [available, setAvailable] = useState(true)

  const pct = Math.min(100, Math.round((points / helperProfile.nextLevelPoints) * 100))
  const activeJobs = jobs.filter((j) => j.status !== 'Afgerond').length

  function accept(opp: Opportunity) {
    setOpps((prev) => prev.filter((o) => o.id !== opp.id))
    setJobs((prev) => [
      { id: opp.id, title: opp.title, resident: 'Nieuwe koppeling', time: opp.time, fee: opp.fee, points: opp.points, status: 'Geaccepteerd' },
      ...prev,
    ])
  }

  function advanceJob(job: HelperJob) {
    const nextStatus = jobFlow[Math.min(jobFlow.indexOf(job.status) + 1, jobFlow.length - 1)]
    setJobs((prev) => prev.map((j) => (j.id === job.id ? { ...j, status: nextStatus } : j)))
    if (nextStatus === 'Afgerond' && job.status !== 'Afgerond') {
      setPoints((p) => p + job.points)
      setEarned((e) => e + euros(job.fee))
    }
  }

  return (
    <main className={`portal-shell${available ? '' : ' is-paused'}`}>
      <PortalHeader title="Jongeren omgeving" user={user} onLogout={onLogout} />

      {/* PROFIEL STRIP */}
      <section className="profile-strip">
        <div className="profile-strip__level">
          <span className="level-badge"><Trophy size={18} /> {helperProfile.level}</span>
          <div className="level-progress">
            <div className="level-progress__head">
              <span>{points} punten</span>
              <span>{helperProfile.nextLevel} bij {helperProfile.nextLevelPoints}</span>
            </div>
            <div className="level-bar"><span style={{ width: `${pct}%` }} /></div>
          </div>
        </div>
        <div className="profile-stats">
          <div className="profile-stat"><Wallet size={18} /><strong>EUR {earned.toFixed(0)}</strong><span>verdiend</span></div>
          <div className="profile-stat"><Star size={18} /><strong>{helperProfile.rating}</strong><span>beoordeling</span></div>
          <div className="profile-stat"><Check size={18} /><strong>{helperProfile.completed}</strong><span>klussen</span></div>
          <button
            type="button"
            className={`avail-toggle${available ? ' is-on' : ''}`}
            onClick={() => setAvailable((a) => !a)}
            aria-pressed={available}
          >
            <span className="avail-dot" />
            {available ? 'Beschikbaar' : 'Gepauzeerd'}
          </button>
        </div>
      </section>

      {/* TABS */}
      <div className="portal-tabs seg" role="tablist" aria-label="Onderdelen">
        <button type="button" role="tab" aria-selected={tab === 'beschikbaar'} className={`seg-btn${tab === 'beschikbaar' ? ' is-active' : ''}`} onClick={() => setTab('beschikbaar')}>
          Beschikbaar <span className="seg-count">{opps.length}</span>
        </button>
        <button type="button" role="tab" aria-selected={tab === 'klussen'} className={`seg-btn${tab === 'klussen' ? ' is-active' : ''}`} onClick={() => setTab('klussen')}>
          Mijn klussen <span className="seg-count">{activeJobs}</span>
        </button>
        <button type="button" role="tab" aria-selected={tab === 'profiel'} className={`seg-btn${tab === 'profiel' ? ' is-active' : ''}`} onClick={() => setTab('profiel')}>
          Profiel
        </button>
      </div>

      {tab === 'beschikbaar' && (
        <section className="portal-list">
          {opps.map((opp) => (
            <article className="opportunity-row" key={opp.id}>
              <div>
                <strong>
                  {opp.title}
                  {opp.bonus && <span className="bonus-tag"><Sparkles size={13} /> bonus</span>}
                </strong>
                <span>{opp.type} · {opp.time} · {opp.distance}</span>
              </div>
              <b>{opp.fee} · {opp.points} pt</b>
              <button type="button" onClick={() => accept(opp)} disabled={!available}>
                Accepteren
                <ArrowRight size={17} />
              </button>
            </article>
          ))}
          {opps.length === 0 && <p className="empty-note">Geen open hulpvragen — kom later terug.</p>}
          {!available && <p className="empty-note">Je staat op gepauzeerd. Zet jezelf op beschikbaar om klussen aan te nemen.</p>}
        </section>
      )}

      {tab === 'klussen' && (
        <section className="portal-list">
          {jobs.map((job) => (
            <article className="opportunity-row" key={job.id}>
              <div>
                <strong>{job.title}</strong>
                <span>{job.resident} · {job.time} · {job.fee}</span>
              </div>
              <span className={`status-pill ${jobStatusClass[job.status]}`}>{job.status}</span>
              {job.status === 'Afgerond' ? (
                <span className="row-muted">+{job.points} pt</span>
              ) : (
                <button type="button" onClick={() => advanceJob(job)}>
                  {job.status === 'Geaccepteerd' ? 'Ik ga onderweg' : 'Klus afronden'}
                  <ArrowRight size={17} />
                </button>
              )}
            </article>
          ))}
          {jobs.length === 0 && <p className="empty-note">Je hebt nog geen klussen aangenomen.</p>}
        </section>
      )}

      {tab === 'profiel' && (
        <section className="portal-grid portal-grid--profile">
          <article className="portal-hero-card">
            <p className="section-label">Screeningstatus</p>
            <h1>Volledig gescreend & actief</h1>
            <ul className="check-list">
              {['Identiteit & selfie geverifieerd', 'Telefoon & bankrekening geverifieerd', 'Geldige VOG overlegd', 'Intakegesprek afgerond'].map((c) => (
                <li key={c}><Check size={17} /> {c}</li>
              ))}
            </ul>
          </article>
          <article className="portal-side-card portal-side-card--light">
            <p className="section-label">Reeks</p>
            <strong>{helperProfile.streak} weken</strong>
            <span>actief op rij — blijf het volhouden</span>
          </article>
          <article className="badges-card">
            <p className="section-label">Badges</p>
            <div className="badge-grid">
              {helperBadges.map((badge) => {
                const Ico = badgeIcons[badge.icon] ?? Sparkles
                return (
                  <div className={`badge-chip${badge.earned ? '' : ' is-locked'}`} key={badge.id}>
                    <span className="badge-chip__icon"><Ico size={20} /></span>
                    <span>{badge.label}</span>
                  </div>
                )
              })}
            </div>
          </article>
        </section>
      )}
    </main>
  )
}

/* ============================ RESIDENT PORTAL ============================ */

export function ResidentPortal({ user, onLogout }: UserPortalProps) {
  const [requests, setRequests] = useState<ResidentRequest[]>(seedResidentRequests)
  const [type, setType] = useState(requestTypeOptions[0])
  const [details, setDetails] = useState('')
  const [date, setDate] = useState('')
  const [urgent, setUrgent] = useState('Normaal')
  const [bigMode, setBigMode] = useState(false)
  const [counter, setCounter] = useState(20)
  const [submitted, setSubmitted] = useState(false)

  const openCount = requests.filter((r) => r.status !== 'Afgerond').length

  function submit(event: FormEvent) {
    event.preventDefault()
    const id = `R-${counter}`
    const fresh: ResidentRequest = {
      id,
      title: type.split(' (')[0],
      type,
      date: date.trim() || 'Zo snel mogelijk',
      status: 'Nieuw',
    }
    setRequests((prev) => [fresh, ...prev])
    setCounter((c) => c + 1)
    setDetails('')
    setDate('')
    setUrgent('Normaal')
    setSubmitted(true)
  }

  function cancel(id: string) {
    setRequests((prev) => prev.filter((r) => r.id !== id))
  }

  function rate(id: string) {
    setRequests((prev) => prev.map((r) => (r.id === id ? { ...r, rated: true } : r)))
  }

  return (
    <main className={`portal-shell${bigMode ? ' big-mode' : ''}`}>
      <PortalHeader title="Hulpvrager omgeving" user={user} onLogout={onLogout} />

      <section className="portal-grid">
        <article className="portal-hero-card">
          <p className="section-label">Hulp aanvragen</p>
          <h1>Vraag veilig hulp aan in je eigen buurt.</h1>
          <p>
            Plaats een kleine hulpvraag of laat familie, mantelzorger of het telefonisch aanmeldpunt
            meekijken. U houdt altijd zelf de regie.
          </p>
          <button type="button" className={`big-toggle${bigMode ? ' is-on' : ''}`} onClick={() => setBigMode((b) => !b)} aria-pressed={bigMode}>
            <Type size={18} />
            {bigMode ? 'Grote weergave staat aan' : 'Grote knoppen & tekst'}
          </button>
        </article>
        <article className="portal-side-card">
          <CalendarCheck size={28} />
          <strong>{openCount}</strong>
          <span>lopende {openCount === 1 ? 'hulpvraag' : 'hulpvragen'}</span>
        </article>
      </section>

      {/* FORMULIER */}
      <section className="resident-form-card">
        <h2>Nieuwe hulpvraag</h2>
        <form className="req-form" onSubmit={submit}>
          <label className="field">
            <span>Waarbij heeft u hulp nodig?</span>
            <select value={type} onChange={(e) => { setType(e.target.value); setSubmitted(false) }}>
              {requestTypeOptions.map((opt) => (
                <option key={opt} value={opt}>{opt}</option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>Korte toelichting (optioneel)</span>
            <textarea
              rows={3}
              value={details}
              placeholder="Bijvoorbeeld: een volle tas boodschappen vanaf de supermarkt om de hoek."
              onChange={(e) => { setDetails(e.target.value); setSubmitted(false) }}
            />
          </label>
          <div className="req-form__row">
            <label className="field">
              <span>Wanneer schikt het?</span>
              <input
                type="text"
                value={date}
                placeholder="Bijv. morgenochtend"
                onChange={(e) => { setDate(e.target.value); setSubmitted(false) }}
              />
            </label>
            <label className="field">
              <span>Urgentie</span>
              <select value={urgent} onChange={(e) => { setUrgent(e.target.value); setSubmitted(false) }}>
                <option>Normaal</option>
                <option>Met spoed</option>
              </select>
            </label>
          </div>
          <button className="button button--primary submit-btn" type="submit">
            <Plus size={18} />
            Hulpvraag plaatsen
          </button>
          {submitted && (
            <p className="form-ok"><Check size={16} /> Uw hulpvraag staat klaar. Een gescreende jongere uit uw wijk pakt hem op.</p>
          )}
        </form>
      </section>

      <div className="resident-cols">
        {/* MIJN HULPVRAGEN */}
        <section className="resident-col">
          <h2 className="resident-col__title">Mijn hulpvragen</h2>
          <div className="portal-list">
            {requests.map((request) => (
              <article className="opportunity-row" key={request.id}>
                <div>
                  <strong>{request.title}</strong>
                  <span>
                    {request.date}
                    {request.helper ? ` · ${request.helper}` : ''}
                  </span>
                </div>
                <span className={`status-pill ${statusClass[request.status]}`}>{request.status}</span>
                {request.status === 'Nieuw' && (
                  <button type="button" className="mini-btn mini-btn--ghost" onClick={() => cancel(request.id)}>Annuleer</button>
                )}
                {request.status === 'Afgerond' && !request.rated && (
                  <button type="button" className="mini-btn" onClick={() => rate(request.id)}>
                    <Star size={15} /> Beoordeel
                  </button>
                )}
                {request.status === 'Afgerond' && request.rated && <span className="row-muted">Bedankt!</span>}
              </article>
            ))}
          </div>
        </section>

        {/* FAVORIETE HELPER + TELEFOON */}
        <aside className="resident-aside">
          <section className="favorite-card">
            <p className="section-label">Vaste helper</p>
            <div className="favorite-card__person">
              <span className="favorite-avatar"><HandHeart size={22} /></span>
              <div>
                <strong>{residentFavorite.name}</strong>
                <span>★ {residentFavorite.rating} · {residentFavorite.jobsTogether} klussen samen</span>
              </div>
            </div>
            <button type="button" className="button button--primary favorite-btn">
              Vraag {residentFavorite.name.split(' ')[0]} opnieuw
              <ArrowRight size={17} />
            </button>
          </section>
          <section className="phone-card">
            <span className="phone-card__icon"><Phone size={22} /></span>
            <div>
              <strong>Liever bellen?</strong>
              <p>Bel het telefonisch aanmeldpunt en een medewerker plaatst de hulpvraag voor u.</p>
              <a href="tel:08001234567">0800 - 123 45 67</a>
            </div>
          </section>
        </aside>
      </div>
    </main>
  )
}

/* ============================ SHARED ============================ */

function PortalHeader({ title, user, onLogout }: { title: string; user: UserSession; onLogout: () => void }) {
  return (
    <header className="portal-header">
      <div className="dashboard-brand">
        <HandHeart size={25} />
        <span>{title}</span>
      </div>
      <div className="portal-user">
        <MapPin size={17} />
        <span>{user.name} · {user.neighborhood}</span>
      </div>
      <button className="logout-button" type="button" onClick={onLogout}>
        <LogOut size={18} />
        Uitloggen
      </button>
    </header>
  )
}

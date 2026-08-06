import { useState, type ComponentType } from 'react'
import {
  ArrowRight,
  ArrowUpRight,
  AlertTriangle,
  Banknote,
  BadgeCheck,
  Building2,
  CalendarClock,
  Camera,
  CheckCircle2,
  ClipboardCheck,
  FileCheck2,
  GraduationCap,
  HandHeart,
  Heart,
  IdCard,
  LineChart,
  Lock,
  MapPin,
  Phone,
  PhoneCall,
  Quote,
  Scale,
  ShieldCheck,
  Sparkles,
  Star,
  Trophy,
  Users,
  Wallet,
} from 'lucide-react'
import heroImage from '../../assets/buurthulp-hero.png'
import {
  budgetHonesty,
  budgetPerMonth,
  budgetPosts,
  budgetToFinance,
  budgetTotal,
  buurthulpDelivers,
  competitors,
  differentiators,
  featureGroups,
  featureGuardrail,
  helpTypes,
  heroPoints,
  kaders,
  municipalityDelivers,
  navLinks,
  nextSteps,
  pilotStats,
  problemText,
  processSteps,
  results,
  safetyItems,
  visionText,
  type KaderKey,
} from './landingData'
import './landing.css'

type IconName = string

const iconMap: Record<IconName, ComponentType<{ size?: number; strokeWidth?: number }>> = {
  ArrowRight,
  AlertTriangle,
  Banknote,
  BadgeCheck,
  Building2,
  CalendarClock,
  Camera,
  CheckCircle2,
  ClipboardCheck,
  FileCheck2,
  GraduationCap,
  HandHeart,
  Heart,
  IdCard,
  LineChart,
  Lock,
  MapPin,
  Phone,
  PhoneCall,
  Scale,
  ShieldCheck,
  Sparkles,
  Star,
  Trophy,
  Users,
  Wallet,
}

function Icon({ name, size = 22, strokeWidth = 2 }: { name: IconName; size?: number; strokeWidth?: number }) {
  const Cmp = iconMap[name] ?? CheckCircle2
  return <Cmp size={size} strokeWidth={strokeWidth} />
}

interface LandingPageProps {
  onOpenLogin: () => void
}

export function LandingPage({ onOpenLogin }: LandingPageProps) {
  const [activeKader, setActiveKader] = useState<KaderKey>('juridisch')
  const current = kaders.find((k) => k.key === activeKader) ?? kaders[0]
  const maxBudget = budgetPosts[0]

  return (
    <div className="lp">
      {/* ---------- HERO ---------- */}
      <header className="lp-topbar">
        <div className="lp-shell lp-topbar__inner">
          <a className="lp-brand" href="#top" aria-label="BuurtHulp home">
            <span className="lp-brand__mark">
              <HandHeart size={20} strokeWidth={2.3} />
            </span>
            <span>BuurtHulp</span>
          </a>
          <nav className="lp-nav" aria-label="Hoofdnavigatie">
            {navLinks.map((link) => (
              <a key={link.href} href={link.href}>
                {link.label}
              </a>
            ))}
          </nav>
          <div className="lp-topbar__actions">
            <button className="lp-pill" type="button" onClick={onOpenLogin}>
              <Users size={16} />
              <span>Inloggen</span>
            </button>
            <a className="lp-pill lp-pill--solid" href="#contact">
              <span>Gesprek</span>
              <ArrowRight size={16} />
            </a>
          </div>
        </div>
      </header>

      <section className="lp-hero" id="top" aria-label="Introductie">
        <img className="lp-hero__img" src={heroImage} alt="Een jongere helpt een oudere buurtbewoner bij de voordeur" />
        <div className="lp-hero__veil" />
        <div className="lp-shell lp-hero__content">
          <span className="lp-eyebrow lp-eyebrow--light">
            <Sparkles size={15} /> Voorstel voor een gemeentelijke pilot
          </span>
          <h1 className="lp-hero__title">
            Gescreende jongeren helpen ouderen in de <em>eigen wijk</em>.
          </h1>
          <p className="lp-hero__lead">
            Een veilige wijkdienst waarmee gemeenten ouderen praktisch ondersteunen en jongeren
            maatschappelijke werkervaring geven — laagdrempelig, verzekerd en meetbaar.
          </p>
          <div className="lp-hero__actions">
            <a className="lp-btn lp-btn--primary" href="#pilot">
              Bekijk de pilot
              <ArrowRight size={18} />
            </a>
            <button className="lp-btn lp-btn--ghost" type="button" onClick={onOpenLogin}>
              Open portaal
            </button>
          </div>
          <ul className="lp-hero__points">
            {heroPoints.map((point) => (
              <li key={point}>
                <CheckCircle2 size={17} /> {point}
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* ---------- PROBLEEM / OPLOSSING ---------- */}
      <section className="lp-section" id="oplossing">
        <div className="lp-shell lp-split">
          <div className="lp-split__copy">
            <span className="lp-eyebrow">Het probleem & de oplossing</span>
            <h2 className="lp-h2">Kleine hulpvragen vallen tussen wal en schip.</h2>
            {problemText.map((p) => (
              <p className="lp-body" key={p.slice(0, 24)}>
                {p}
              </p>
            ))}
          </div>
          <div className="lp-help-card" aria-label="Soorten hulpvragen">
            <p className="lp-help-card__label">Waarbij BuurtHulp helpt</p>
            {helpTypes.map((type) => (
              <div className="lp-help-row" key={type}>
                <span className="lp-dot" />
                {type}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ---------- CIJFERS ---------- */}
      <section className="lp-stats-band" aria-label="De pilot in cijfers">
        <div className="lp-shell lp-stats-grid">
          <div className="lp-stats-grid__intro">
            <span className="lp-eyebrow lp-eyebrow--light">De pilot in cijfers</span>
            <p>Start klein, bewijs lokaal, schaal daarna verantwoord op.</p>
          </div>
          {pilotStats.map((stat) => (
            <div className="lp-stat" key={stat.label}>
              <strong>{stat.value}</strong>
              <span>{stat.label}</span>
            </div>
          ))}
        </div>
      </section>

      {/* ---------- WERKWIJZE ---------- */}
      <section className="lp-section" id="werkwijze">
        <div className="lp-shell">
          <div className="lp-section-head">
            <span className="lp-eyebrow">Werkwijze</span>
            <h2 className="lp-h2">Van hulpvraag tot vertrouwd gezicht — in vier stappen.</h2>
          </div>
          <ol className="lp-steps">
            {processSteps.map((step, i) => (
              <li className="lp-step" key={step.title}>
                <span className="lp-step__num">{i + 1}</span>
                <span className="lp-step__icon">
                  <Icon name={step.icon} size={22} />
                </span>
                <h3>{step.title}</h3>
                <p>{step.text}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* ---------- TELEFONISCH AANMELDPUNT ---------- */}
      <section className="lp-section lp-section--tint">
        <div className="lp-shell lp-callout">
          <div className="lp-callout__icon">
            <PhoneCall size={30} strokeWidth={2} />
          </div>
          <div>
            <span className="lp-eyebrow">Telefonisch aanmeldpunt</span>
            <h2 className="lp-h2">Ook de oudere zonder smartphone bereiken.</h2>
            <p className="lp-body">
              Een groot deel van de kwetsbare ouderen is niet digitaal vaardig. Daarom heeft BuurtHulp
              naast de app en website één vast telefoonnummer. Een medewerker noteert de hulpvraag,
              plaatst die in het systeem en bevestigt telefonisch of per sms. Aanmelden kan ook door
              familie, mantelzorger of wijkteam — de oudere houdt altijd zelf de regie.
            </p>
          </div>
        </div>
      </section>

      {/* ---------- VEILIGHEID ---------- */}
      <section className="lp-section" id="veiligheid">
        <div className="lp-shell">
          <div className="lp-section-head">
            <span className="lp-eyebrow">Veiligheid & screening</span>
            <h2 className="lp-h2">Vertrouwen is de hoofdvoorwaarde.</h2>
            <p className="lp-body lp-section-head__sub">
              Geen enkele jongere wordt actief gezet voordat de volledige screening is doorlopen.
            </p>
          </div>
          <div className="lp-safety-grid">
            {safetyItems.map((item) => (
              <article className="lp-safety-card" key={item.title}>
                <span className="lp-safety-card__icon">
                  <Icon name={item.icon} size={22} />
                </span>
                <h3>{item.title}</h3>
                <p>{item.text}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* ---------- KADERS (TABS) ---------- */}
      <section className="lp-section lp-section--dark" id="kaders">
        <div className="lp-shell">
          <div className="lp-section-head lp-section-head--center">
            <span className="lp-eyebrow lp-eyebrow--light">Vooraf dichtgetimmerd</span>
            <h2 className="lp-h2 lp-h2--light">De vier kaders die een gemeente als eerste controleert.</h2>
            <p className="lp-body lp-body--light lp-section-head__sub">
              Juridisch, screening, verzekering en privacy — allemaal vooraf geregeld, zodat u weet dat de
              pilot sluitend is.
            </p>
          </div>

          <div className="lp-tabs" role="tablist" aria-label="Kaders">
            {kaders.map((k) => (
              <button
                key={k.key}
                role="tab"
                type="button"
                aria-selected={activeKader === k.key}
                className={`lp-tab${activeKader === k.key ? ' is-active' : ''}`}
                onClick={() => setActiveKader(k.key)}
              >
                <Icon name={k.icon} size={18} />
                <span>{k.tab}</span>
              </button>
            ))}
          </div>

          <div className="lp-tabpanel" role="tabpanel">
            <div className="lp-tabpanel__head">
              <span className="lp-tabpanel__icon">
                <Icon name={current.icon} size={26} />
              </span>
              <h3>{current.title}</h3>
            </div>
            <p className="lp-tabpanel__intro">{current.intro}</p>
            <ul className="lp-tabpanel__list">
              {current.points.map((point) => (
                <li key={point.slice(0, 28)}>
                  <CheckCircle2 size={19} />
                  <span>{point}</span>
                </li>
              ))}
            </ul>
            {current.footnote && <p className="lp-tabpanel__note">{current.footnote}</p>}
          </div>
        </div>
      </section>

      {/* ---------- BEGROTING ---------- */}
      <section className="lp-section" id="begroting">
        <div className="lp-shell">
          <div className="lp-section-head">
            <span className="lp-eyebrow">Pilotbegroting</span>
            <h2 className="lp-h2">Een eerlijke som, geen rooskleurig plaatje.</h2>
          </div>

          <div className="lp-budget">
            <div className="lp-budget__bars">
              {budgetPosts.map((post) => (
                <div className="lp-budget-row" key={post.label}>
                  <div className="lp-budget-row__head">
                    <span className="lp-budget-row__label">{post.label}</span>
                    <span className="lp-budget-row__amount">{post.amount}</span>
                  </div>
                  <div className="lp-budget-row__track">
                    <span
                      className="lp-budget-row__fill"
                      style={{ width: `${(numeric(post.amount) / numeric(maxBudget.amount)) * 100}%` }}
                    />
                  </div>
                  <p className="lp-budget-row__detail">{post.detail}</p>
                </div>
              ))}
            </div>

            <aside className="lp-budget__aside">
              <div className="lp-budget-figure">
                <span>Totaal pilot (6 mnd)</span>
                <strong>{budgetTotal}</strong>
              </div>
              <div className="lp-budget-figure lp-budget-figure--row">
                <div>
                  <span>Per maand</span>
                  <strong>{budgetPerMonth}</strong>
                </div>
                <div>
                  <span>Te financieren</span>
                  <strong>{budgetToFinance}</strong>
                </div>
              </div>
              <div className="lp-honesty">
                <span className="lp-honesty__tag">
                  <AlertTriangle size={15} /> Eerlijk gerekend
                </span>
                {budgetHonesty.map((p) => (
                  <p key={p.slice(0, 24)}>{p}</p>
                ))}
              </div>
            </aside>
          </div>

          {/* wat levert wie */}
          <div className="lp-delivery">
            <div className="lp-delivery__col">
              <h3 className="lp-delivery__title">
                <HandHeart size={20} /> Wat BuurtHulp inbrengt
              </h3>
              {buurthulpDelivers.map((d) => (
                <div className="lp-delivery__item" key={d.title}>
                  <CheckCircle2 size={18} />
                  <div>
                    <strong>{d.title}</strong>
                    <p>{d.text}</p>
                  </div>
                </div>
              ))}
            </div>
            <div className="lp-delivery__col lp-delivery__col--alt">
              <h3 className="lp-delivery__title">
                <Building2 size={20} /> Wat we van de gemeente vragen
              </h3>
              {municipalityDelivers.map((d) => (
                <div className="lp-delivery__item" key={d.title}>
                  <CheckCircle2 size={18} />
                  <div>
                    <strong>{d.title}</strong>
                    <p>{d.text}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ---------- POSITIONERING ---------- */}
      <section className="lp-section lp-section--tint">
        <div className="lp-shell">
          <div className="lp-section-head">
            <span className="lp-eyebrow">Positionering</span>
            <h2 className="lp-h2">Aanvullend op wat er al is — niet vervangend.</h2>
          </div>
          <div className="lp-compare">
            <div className="lp-compare__existing">
              <p className="lp-compare__label">Het bestaande landschap</p>
              <div className="lp-compare__list">
                {competitors.map((c) => (
                  <div className="lp-compare__row" key={c.name}>
                    <strong>{c.name}</strong>
                    <p>{c.text}</p>
                  </div>
                ))}
              </div>
            </div>
            <div className="lp-compare__ours">
              <p className="lp-compare__label lp-compare__label--accent">Wat BuurtHulp uniek maakt</p>
              <div className="lp-diff-grid">
                {differentiators.map((d) => (
                  <article className="lp-diff" key={d.title}>
                    <span className="lp-diff__icon">
                      <Icon name={d.icon} size={20} />
                    </span>
                    <h3>{d.title}</h3>
                    <p>{d.text}</p>
                  </article>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ---------- FUNCTIES ---------- */}
      <section className="lp-section" id="functies">
        <div className="lp-shell">
          <div className="lp-section-head">
            <span className="lp-eyebrow">Extra functies — toekomstvisie</span>
            <h2 className="lp-h2">Motiverend voor jongeren, geruststellend voor ouderen.</h2>
            <p className="lp-body lp-section-head__sub">
              Geen pilot-vereiste, maar een doorontwikkelagenda voor ná een geslaagde pilot.
            </p>
          </div>

          <div className="lp-guardrail">
            <span className="lp-guardrail__icon">
              <AlertTriangle size={22} />
            </span>
            <div>
              <strong>Kwaliteit boven kwantiteit — als ontwerpprincipe</strong>
              <p>{featureGuardrail}</p>
            </div>
          </div>

          <div className="lp-features">
            {featureGroups.map((group) => (
              <div className="lp-feature-col" key={group.audience}>
                <h3 className="lp-feature-col__head">
                  <Icon name={group.icon} size={20} />
                  {group.audience}
                </h3>
                <div className="lp-feature-col__items">
                  {group.items.map((item) => (
                    <div className="lp-feature" key={item.title}>
                      <strong>{item.title}</strong>
                      <p>{item.text}</p>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ---------- RESULTATEN ---------- */}
      <section className="lp-section lp-section--dark">
        <div className="lp-shell lp-results">
          <div className="lp-results__head">
            <span className="lp-eyebrow lp-eyebrow--light">Meetbare resultaten</span>
            <h2 className="lp-h2 lp-h2--light">De gemeente stuurt op cijfers, niet op beloften.</h2>
            <p className="lp-body lp-body--light">
              We rapporteren periodiek en leveren een eindrapportage met opschalingsadvies — uitsluitend
              geaggregeerd en niet tot personen herleidbaar.
            </p>
          </div>
          <ul className="lp-results__list">
            {results.map((r) => (
              <li key={r}>
                <CheckCircle2 size={18} />
                <span>{r}</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* ---------- PILOT / VOLGENDE STAP / CTA ---------- */}
      <section className="lp-section" id="pilot">
        <div className="lp-shell lp-next">
          <div className="lp-next__copy">
            <span className="lp-eyebrow">Volgende stap</span>
            <h2 className="lp-h2">Klaar voor een eerste gemeentegesprek?</h2>
            <p className="lp-body">
              We lichten het voorstel graag toe en verkennen samen welke pilotwijk geschikt is. Het
              voorstel passen we aan op de wensen en context van uw gemeente.
            </p>
            <div className="lp-vision">
              <Quote size={20} />
              <p>{visionText}</p>
            </div>
          </div>
          <ol className="lp-next__steps">
            {nextSteps.map((step, i) => (
              <li key={step.slice(0, 20)}>
                <span>{i + 1}</span>
                <p>{step}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="lp-cta" id="contact">
        <div className="lp-shell lp-cta__inner">
          <div>
            <h2 className="lp-h2 lp-h2--light">Laten we een pilot starten in uw wijk.</h2>
            <p className="lp-body lp-body--light">
              Gebruik dit voorstel als startpunt voor een gesprek met beleidsmedewerkers, wijkteams en
              maatschappelijke partners.
            </p>
          </div>
          <div className="lp-cta__actions">
            <a className="lp-btn lp-btn--primary" href="mailto:info@buurthulp.nl">
              Kennismaking plannen
              <ArrowUpRight size={18} />
            </a>
            <button className="lp-btn lp-btn--outline" type="button" onClick={onOpenLogin}>
              Open portaal
            </button>
          </div>
        </div>
      </section>

      <footer className="lp-footer">
        <div className="lp-shell lp-footer__inner">
          <a className="lp-brand lp-brand--dark" href="#top">
            <span className="lp-brand__mark lp-brand__mark--dark">
              <HandHeart size={18} strokeWidth={2.3} />
            </span>
            <span>BuurtHulp</span>
          </a>
          <p>Veilige ouderenhulp · jongerenparticipatie · sterkere buurten</p>
        </div>
      </footer>
    </div>
  )
}

/** Parse a euro string like "€ 18.180" or "€ 1.692,50" into a number for bar widths. */
function numeric(amount: string): number {
  const cleaned = amount.replace(/[^\d,.-]/g, '').replace(/\./g, '').replace(',', '.')
  const value = Number.parseFloat(cleaned)
  return Number.isFinite(value) ? value : 0
}

import { useState, type ComponentType } from 'react'
import {
  ArrowRight,
  ArrowUpRight,
  CheckCircle2,
  ClipboardCheck,
  FileCheck2,
  GraduationCap,
  HandHeart,
  Heart,
  IdCard,
  Lock,
  MapPin,
  PhoneCall,
  Quote,
  Scale,
  ShieldCheck,
  Sparkles,
  Star,
  Users,
  XCircle,
} from 'lucide-react'
import heroImage from '../../assets/heitjehulp-hero.png'
import {
  aanvullend,
  fases,
  gedragsregels,
  helpTypes,
  heroPoints,
  kaders,
  navLinks,
  nietDoen,
  problemText,
  processSteps,
  proefStats,
  results,
  rollen,
  safetyItems,
  verhaal,
  vragen,
  welDoen,
  type KaderKey,
} from './landingData'
import './landing.css'

const CONTACT_MAIL = 'mailto:info@heitjehulp.nl'

const iconMap: Record<string, ComponentType<{ size?: number; strokeWidth?: number }>> = {
  CheckCircle2,
  ClipboardCheck,
  FileCheck2,
  GraduationCap,
  HandHeart,
  Heart,
  IdCard,
  Lock,
  MapPin,
  PhoneCall,
  Scale,
  ShieldCheck,
  Star,
  Users,
}

function Icon({ name, size = 22, strokeWidth = 2 }: { name: string; size?: number; strokeWidth?: number }) {
  const Cmp = iconMap[name] ?? CheckCircle2
  return <Cmp size={size} strokeWidth={strokeWidth} />
}

export function LandingPage() {
  const [activeKader, setActiveKader] = useState<KaderKey>('juridisch')
  const current = kaders.find((k) => k.key === activeKader) ?? kaders[0]

  return (
    <div className="lp">
      <header className="lp-topbar">
        <div className="lp-shell lp-topbar__inner">
          <a className="lp-brand" href="#top" aria-label="HeitjeHulp home">
            <span className="lp-brand__mark">
              <HandHeart size={20} strokeWidth={2.3} />
            </span>
            <span>HeitjeHulp</span>
          </a>
          <nav className="lp-nav" aria-label="Hoofdnavigatie">
            {navLinks.map((link) => (
              <a key={link.href} href={link.href}>
                {link.label}
              </a>
            ))}
          </nav>
          <div className="lp-topbar__actions">
            <a className="lp-pill lp-pill--solid" href="#contact">
              <span>Contact</span>
              <ArrowRight size={16} />
            </a>
          </div>
        </div>
      </header>

      <main>
        {/* ---------- HERO ---------- */}
        <section className="lp-hero" id="top" aria-label="Introductie">
          <img
            className="lp-hero__img"
            src={heroImage}
            alt="Een jongere helpt een oudere buurtbewoner bij de voordeur"
            fetchPriority="high"
          />
          <div className="lp-hero__veil" />
          <div className="lp-shell lp-hero__content">
            <span className="lp-eyebrow lp-eyebrow--light">
              <Sparkles size={15} /> Stichting HeitjeHulp
            </span>
            <h1 className="lp-hero__title">
              Gescreende jongeren helpen ouderen in de <em>eigen wijk</em>.
            </h1>
            <p className="lp-hero__lead">
              Een boodschap, een lamp, een formulier, een praatje. HeitjeHulp koppelt ouderen met kleine
              hulpvragen aan betrouwbare jongeren uit dezelfde buurt — veilig, begeleid en herleidbaar.
            </p>
            <div className="lp-hero__actions">
              <a className="lp-btn lp-btn--primary" href="#werkwijze">
                Zo werkt het
                <ArrowRight size={18} />
              </a>
              <a className="lp-btn lp-btn--ghost" href="#contact">
                Meedoen
              </a>
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

        {/* ---------- PROBLEEM ---------- */}
        <section className="lp-section" id="oplossing" aria-labelledby="kop-probleem">
          <div className="lp-shell lp-split">
            <div className="lp-split__copy">
              <span className="lp-eyebrow">Waarom HeitjeHulp</span>
              <h2 className="lp-h2" id="kop-probleem">
                Kleine hulpvragen vallen tussen wal en schip.
              </h2>
              {problemText.map((p) => (
                <p className="lp-body" key={p.slice(0, 24)}>
                  {p}
                </p>
              ))}
            </div>
            <div className="lp-help-card" aria-label="Soorten hulpvragen">
              <p className="lp-help-card__label">Waarbij HeitjeHulp helpt</p>
              {helpTypes.map((type) => (
                <div className="lp-help-row" key={type}>
                  <span className="lp-dot" />
                  {type}
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ---------- VERHAAL ---------- */}
        <section className="lp-section lp-section--tint" aria-label={verhaal.bijschrift}>
          <div className="lp-shell">
            <figure className="lp-verhaal">
              <Quote size={28} aria-hidden="true" />
              <blockquote>
                <p>{verhaal.tekst}</p>
              </blockquote>
              <figcaption>{verhaal.bijschrift}</figcaption>
            </figure>
          </div>
        </section>

        {/* ---------- WERKWIJZE ---------- */}
        <section className="lp-section" id="werkwijze" aria-labelledby="kop-werkwijze">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Werkwijze</span>
              <h2 className="lp-h2" id="kop-werkwijze">
                Van hulpvraag tot vertrouwd gezicht — in vier stappen.
              </h2>
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

            <h3 className="lp-subkop">Wat wij wel en niet doen</h3>
            <div className="lp-delivery lp-weldoen">
              <div className="lp-delivery__col">
                <h3 className="lp-delivery__title">
                  <CheckCircle2 size={20} /> Wat wij wel doen
                </h3>
                <ul className="lp-checklist">
                  {welDoen.map((item) => (
                    <li key={item}>
                      <CheckCircle2 size={18} aria-hidden="true" />
                      {item}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="lp-delivery__col lp-delivery__col--alt">
                <h3 className="lp-delivery__title">
                  <XCircle size={20} /> Wat wij niet doen
                </h3>
                <ul className="lp-checklist lp-checklist--niet">
                  {nietDoen.map((item) => (
                    <li key={item}>
                      <XCircle size={18} aria-hidden="true" />
                      {item}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </section>

        {/* ---------- VOOR WIE ---------- */}
        <section className="lp-section lp-section--tint" id="voor-wie" aria-labelledby="kop-rollen">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Voor wie</span>
              <h2 className="lp-h2" id="kop-rollen">
                Eén platform, vier rollen.
              </h2>
              <p className="lp-body lp-section-head__sub">
                Iedereen ziet alleen wat bij zijn rol hoort. Wat je mag zien, wordt op de server bewaakt —
                niet alleen in de app.
              </p>
            </div>
            <div className="lp-rollen">
              {rollen.map((rol) => (
                <article className="lp-rol" key={rol.rol}>
                  <header>
                    <span className="lp-rol__icon">
                      <Icon name={rol.icon} size={22} />
                    </span>
                    <div>
                      <p className="lp-rol__naam">{rol.rol}</p>
                      <h3>{rol.kop}</h3>
                    </div>
                  </header>
                  <ul>
                    {rol.items.map((item) => (
                      <li key={item.title}>
                        <strong>{item.title}</strong>
                        <span>{item.text}</span>
                      </li>
                    ))}
                  </ul>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* ---------- TELEFONISCH ---------- */}
        <section className="lp-section" aria-labelledby="kop-telefoon">
          <div className="lp-shell lp-callout">
            <div className="lp-callout__icon">
              <PhoneCall size={30} strokeWidth={2} />
            </div>
            <div>
              <span className="lp-eyebrow">Ook zonder smartphone</span>
              <h2 className="lp-h2" id="kop-telefoon">
                Bellen kan altijd.
              </h2>
              <p className="lp-body">
                Niet iedere oudere gebruikt een app. Daarom kan een hulpvraag ook telefonisch worden
                doorgegeven. De meldkamer zet hem in het systeem, en vanaf dan loopt hij precies zoals een
                klus uit de app. Aanmelden kan ook door familie, mantelzorger of wijkteam — de oudere houdt
                altijd zelf de regie.
              </p>
            </div>
          </div>
        </section>

        {/* ---------- VEILIGHEID ---------- */}
        <section className="lp-section lp-section--tint" id="veiligheid" aria-labelledby="kop-veiligheid">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Veiligheid</span>
              <h2 className="lp-h2" id="kop-veiligheid">
                Vertrouwen is de hoofdvoorwaarde.
              </h2>
              <p className="lp-body lp-section-head__sub">
                Geen enkele jongere wordt actief voordat de volledige screening is doorlopen.
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
            <div className="lp-regels">
              <div>
                <h3>Gedragsregels voor elke jongere</h3>
                <p>Bij twijfel wordt een match beëindigd, zonder discussie.</p>
              </div>
              <ul>
                {gedragsregels.map((regel) => (
                  <li key={regel}>
                    <CheckCircle2 size={18} aria-hidden="true" />
                    {regel}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>

        {/* ---------- KADERS ---------- */}
        <section className="lp-section lp-section--dark" id="kaders" aria-labelledby="kop-kaders">
          <div className="lp-shell">
            <div className="lp-section-head lp-section-head--center">
              <span className="lp-eyebrow lp-eyebrow--light">Vooraf geregeld</span>
              <h2 className="lp-h2 lp-h2--light" id="kop-kaders">
                Juridisch, screening, verzekering en privacy.
              </h2>
            </div>

            <div className="lp-tabs" role="tablist" aria-label="Kaders">
              {kaders.map((k) => (
                <button
                  key={k.key}
                  id={`tab-${k.key}`}
                  role="tab"
                  type="button"
                  aria-selected={activeKader === k.key}
                  aria-controls="kader-paneel"
                  className={`lp-tab${activeKader === k.key ? ' is-active' : ''}`}
                  onClick={() => setActiveKader(k.key)}
                >
                  <Icon name={k.icon} size={18} />
                  <span>{k.tab}</span>
                </button>
              ))}
            </div>

            <div className="lp-tabpanel" role="tabpanel" id="kader-paneel" aria-labelledby={`tab-${current.key}`}>
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
            </div>
          </div>
        </section>

        {/* ---------- PROEF ---------- */}
        <section className="lp-section" id="proef" aria-labelledby="kop-proef">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">De proef</span>
              <h2 className="lp-h2" id="kop-proef">
                Klein beginnen, in drie stappen.
              </h2>
              <p className="lp-body lp-section-head__sub">
                Eerst bewijzen dat het werkt, dan pas groeien. Na elke stap volgt een korte rapportage.
              </p>
            </div>
            <div className="lp-proef">
              <dl className="lp-proef__cijfers" aria-label="De eerste proef">
                {proefStats.map((stat) => (
                  <div key={stat.label}>
                    <dt>{stat.label}</dt>
                    <dd>{stat.value}</dd>
                  </div>
                ))}
              </dl>
              <ol className="lp-fases">
                {fases.map((fase) => (
                  <li key={fase.label}>
                    <span>{fase.label}</span>
                    <h3>{fase.title}</h3>
                    <p>{fase.text}</p>
                  </li>
                ))}
              </ol>
            </div>
          </div>
        </section>

        {/* ---------- AANVULLEND + METEN ---------- */}
        <section className="lp-section lp-section--dark" aria-labelledby="kop-aanvullend">
          <div className="lp-shell lp-results">
            <div className="lp-results__head">
              <span className="lp-eyebrow lp-eyebrow--light">Naast het bestaande aanbod</span>
              <h2 className="lp-h2 lp-h2--light" id="kop-aanvullend">
                We vergroten de vijver in plaats van eruit te vissen.
              </h2>
              <div className="lp-aanvullend">
                {aanvullend.map((item) => (
                  <article key={item.title}>
                    <Icon name={item.icon} size={20} />
                    <div>
                      <h3>{item.title}</h3>
                      <p>{item.text}</p>
                    </div>
                  </article>
                ))}
              </div>
            </div>
            <div>
              <p className="lp-results__label">Wat we bijhouden en delen</p>
              <ul className="lp-results__list">
                {results.map((r) => (
                  <li key={r}>
                    <CheckCircle2 size={18} />
                    <span>{r}</span>
                  </li>
                ))}
              </ul>
              <p className="lp-body lp-body--light lp-results__noot">
                Altijd in totalen, nooit tot een persoon te herleiden.
              </p>
            </div>
          </div>
        </section>

        {/* ---------- VRAGEN ---------- */}
        <section className="lp-section" id="vragen" aria-labelledby="kop-vragen">
          <div className="lp-shell lp-faq">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Vragen</span>
              <h2 className="lp-h2" id="kop-vragen">
                Veelgestelde vragen
              </h2>
            </div>
            <div className="lp-faq__lijst">
              {vragen.map((v) => (
                <details className="lp-faq__item" key={v.vraag}>
                  <summary>{v.vraag}</summary>
                  <p>{v.antwoord}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        {/* ---------- CONTACT ---------- */}
        <section className="lp-cta" id="contact" aria-labelledby="kop-contact">
          <div className="lp-shell lp-cta__inner">
            <div>
              <h2 className="lp-h2 lp-h2--light" id="kop-contact">
                Meedoen of meer weten?
              </h2>
              <p className="lp-body lp-body--light">
                Als oudere, familielid, jongere of organisatie in de wijk: we horen graag van u.
              </p>
            </div>
            <div className="lp-cta__actions">
              <a className="lp-btn lp-btn--primary" href={CONTACT_MAIL}>
                Neem contact op
                <ArrowUpRight size={18} />
              </a>
            </div>
          </div>
        </section>
      </main>

      <footer className="lp-footer">
        <div className="lp-shell lp-footer__inner">
          <a className="lp-brand lp-brand--dark" href="#top">
            <span className="lp-brand__mark lp-brand__mark--dark">
              <HandHeart size={18} strokeWidth={2.3} />
            </span>
            <span>HeitjeHulp</span>
          </a>
          <p>Stichting HeitjeHulp · veilige hulp van jongeren voor ouderen in de eigen wijk</p>
        </div>
      </footer>
    </div>
  )
}

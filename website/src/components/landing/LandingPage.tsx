import { useState, type ComponentType } from 'react'
import {
  ArrowRight,
  ArrowUpRight,
  Camera,
  CheckCircle2,
  ClipboardCheck,
  Coins,
  FileCheck2,
  HandHeart,
  Handshake,
  House,
  KeyRound,
  Lock,
  MapPin,
  Megaphone,
  MessageCircle,
  Quote,
  ShieldAlert,
  Sparkles,
  Star,
  TrendingUp,
  Trophy,
  UserPlus,
  Users,
  Wallet,
} from 'lucide-react'
import heroImage from '../../assets/heitjehulp-hero.png'
import {
  SLOGAN,
  gedragsregels,
  helperBeloning,
  helperInApp,
  helperSteps,
  heroPoints,
  introText,
  kaders,
  klusTypes,
  navLinks,
  partnerPunten,
  processSteps,
  rollen,
  safetyItems,
  verhaal,
  vragen,
  welDoen,
  type KaderKey,
} from './landingData'
import './landing.css'

const CONTACT_MAIL = 'mailto:info@heitjehulp.nl'
const PARTNER_MAIL = 'mailto:info@heitjehulp.nl?subject=Partner%20worden%20van%20HeitjeHulp'

const iconMap: Record<string, ComponentType<{ size?: number; strokeWidth?: number }>> = {
  Camera,
  CheckCircle2,
  ClipboardCheck,
  Coins,
  FileCheck2,
  Handshake,
  House,
  KeyRound,
  Lock,
  MapPin,
  Megaphone,
  MessageCircle,
  ShieldAlert,
  Sparkles,
  Star,
  TrendingUp,
  Trophy,
  UserPlus,
  Users,
  Wallet,
}

function Icon({ name, size = 22, strokeWidth = 2 }: { name: string; size?: number; strokeWidth?: number }) {
  const Cmp = iconMap[name] ?? CheckCircle2
  return <Cmp size={size} strokeWidth={strokeWidth} />
}

export function LandingPage() {
  const [activeKader, setActiveKader] = useState<KaderKey>('betalen')
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
            alt="Een jonge helper staat bij de voordeur van een buurtbewoner"
            fetchPriority="high"
          />
          <div className="lp-hero__veil" />
          <div className="lp-shell lp-hero__content">
            <p className="lp-hero__naam">HeitjeHulp</p>
            <h1 className="lp-hero__title">
              Heitje voor een karweitje, <em>in jouw buurt</em>.
            </h1>
            <p className="lp-hero__lead">
              Plaats een klus met een foto. Helpers uit je buurt reageren. Jij kiest wie het doet. HeitjeHulp
              brengt jullie bij elkaar en regelt het betalen.
            </p>
            <div className="lp-hero__actions">
              <a className="lp-btn lp-btn--primary" href="#werkwijze">
                Zo werkt het
                <ArrowRight size={18} />
              </a>
              <a className="lp-btn lp-btn--ghost" href="#helpers">
                Ik wil helpen
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

        {/* ---------- WAT IS HEITJEHULP ---------- */}
        <section className="lp-section" id="wat" aria-labelledby="kop-wat">
          <div className="lp-shell lp-split">
            <div className="lp-split__copy">
              <span className="lp-eyebrow">Wat is HeitjeHulp</span>
              <h2 className="lp-h2" id="kop-wat">
                Een klein klusje, iemand uit de buurt.
              </h2>
              {introText.map((p) => (
                <p className="lp-body" key={p.slice(0, 24)}>
                  {p}
                </p>
              ))}
            </div>
            <div className="lp-help-card" aria-label="Voorbeelden van klussen">
              <p className="lp-help-card__label">Klussen die je kunt plaatsen</p>
              {klusTypes.map((type) => (
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

        {/* ---------- ZO WERKT HET (BEWONERS) ---------- */}
        <section className="lp-section" id="werkwijze" aria-labelledby="kop-werkwijze">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Zo werkt het</span>
              <h2 className="lp-h2" id="kop-werkwijze">
                Van foto tot klaar, in vier stappen.
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

            <h3 className="lp-subkop">Wat kan er</h3>
            <div className="lp-delivery lp-weldoen">
              <div className="lp-delivery__col">
                <h3 className="lp-delivery__title">
                  <CheckCircle2 size={20} /> Dit kan
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
            </div>
          </div>
        </section>

        {/* ---------- VOOR WIE ---------- */}
        <section className="lp-section lp-section--tint" id="voor-wie" aria-labelledby="kop-rollen">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Voor wie</span>
              <h2 className="lp-h2" id="kop-rollen">
                Bewoners, helpers, ouders en de meldkamer.
              </h2>
              <p className="lp-body lp-section-head__sub">
                Iedereen ziet in de app alleen wat bij hem of haar hoort.
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

        {/* ---------- BEMIDDELAAR ---------- */}
        <section className="lp-section" aria-labelledby="kop-bemiddelaar">
          <div className="lp-shell lp-callout">
            <div className="lp-callout__icon">
              <Handshake size={30} strokeWidth={2} />
            </div>
            <div>
              <span className="lp-eyebrow">Wie is HeitjeHulp</span>
              <h2 className="lp-h2" id="kop-bemiddelaar">
                Wij bemiddelen. Wij zijn geen werkgever.
              </h2>
              <p className="lp-body">
                HeitjeHulp is een bedrijf dat bewoners en helpers bij elkaar brengt. De helper is niet bij ons in
                dienst. Jij en de helper spreken samen de klus af. Wij zorgen voor de app, de chat, het betalen en
                de meldkamer die meekijkt als er iets misgaat.
              </p>
            </div>
          </div>
        </section>

        {/* ---------- HELPERS ---------- */}
        <section className="lp-section lp-section--tint" id="helpers" aria-labelledby="kop-helpers">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Voor helpers</span>
              <h2 className="lp-h2" id="kop-helpers">
                Help je buurt en verdien je zakgeld.
              </h2>
              <p className="lp-body lp-section-head__sub">
                Je kunt helpen vanaf 10 jaar. Er is geen maximum leeftijd.
              </p>
            </div>
            <ol className="lp-steps lp-steps--drie">
              {helperSteps.map((step, i) => (
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

        {/* ---------- WAT JE KRIJGT ---------- */}
        <section className="lp-section lp-section--dark" aria-labelledby="kop-beloning">
          <div className="lp-shell lp-results">
            <div className="lp-results__head">
              <span className="lp-eyebrow lp-eyebrow--light">Wat je krijgt</span>
              <h2 className="lp-h2 lp-h2--light" id="kop-beloning">
                Zakgeld, XP, badges en niveaus.
              </h2>
              <div className="lp-aanvullend">
                {helperBeloning.map((item) => (
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
              <p className="lp-results__label">Dit zie je in de app</p>
              <ul className="lp-results__list">
                {helperInApp.map((r) => (
                  <li key={r}>
                    <CheckCircle2 size={18} />
                    <span>{r}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>

        {/* ---------- VEILIGHEID ---------- */}
        <section className="lp-section lp-section--tint" id="veiligheid" aria-labelledby="kop-veiligheid">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Veiligheid</span>
              <h2 className="lp-h2" id="kop-veiligheid">
                Veilig helpen en geholpen worden.
              </h2>
              <p className="lp-body lp-section-head__sub">
                De meldkamer van HeitjeHulp keurt elke helper goed en helpt als er iets misgaat.
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
                <h3>Afspraken voor iedereen</h3>
                <p>Houdt iemand zich er niet aan? Dan kan de meldkamer het account stoppen.</p>
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

        {/* ---------- GOED OM TE WETEN ---------- */}
        <section className="lp-section lp-section--dark" id="kaders" aria-labelledby="kop-kaders">
          <div className="lp-shell">
            <div className="lp-section-head lp-section-head--center">
              <span className="lp-eyebrow lp-eyebrow--light">Goed om te weten</span>
              <h2 className="lp-h2 lp-h2--light" id="kop-kaders">
                Betalen, ouders, VOG en privacy.
              </h2>
            </div>

            <div className="lp-tabs" role="tablist" aria-label="Goed om te weten">
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

        {/* ---------- PARTNERS ---------- */}
        <section className="lp-section" id="partners" aria-labelledby="kop-partners">
          <div className="lp-shell">
            <div className="lp-section-head">
              <span className="lp-eyebrow">Partners</span>
              <h2 className="lp-h2" id="kop-partners">
                Samen met het jongerenwerk.
              </h2>
              <p className="lp-body lp-section-head__sub">
                Organisaties voor jongerenwerk kennen de jongeren in de wijk. Als partner helpen ze HeitjeHulp
                bekend te maken. HeitjeHulp blijft zelf de bemiddelaar.
              </p>
            </div>
            <div className="lp-partners">
              <div className="lp-partner-card">
                <Handshake size={30} strokeWidth={2} aria-hidden="true" />
                <h3>Word partner</h3>
                <p>Werk je bij een organisatie voor jongerenwerk? Mail ons en we vertellen je graag meer.</p>
                <a className="lp-btn lp-btn--primary" href={PARTNER_MAIL}>
                  Mail info@heitjehulp.nl
                  <ArrowUpRight size={18} />
                </a>
              </div>
              <ul className="lp-fases">
                {partnerPunten.map((punt) => (
                  <li key={punt.title}>
                    <span>
                      <Icon name={punt.icon} size={18} />
                    </span>
                    <h3>{punt.title}</h3>
                    <p>{punt.text}</p>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>

        {/* ---------- VRAGEN ---------- */}
        <section className="lp-section lp-section--tint" id="vragen" aria-labelledby="kop-vragen">
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
                Als bewoner, helper, ouder of organisatie: we horen graag van je.
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
          <p>
            {SLOGAN} HeitjeHulp bemiddelt tussen bewoners en helpers en is geen werkgever.
          </p>
        </div>
      </footer>
    </div>
  )
}

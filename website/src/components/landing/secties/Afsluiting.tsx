import { ArrowUpRight } from 'lucide-react'
import { Icon } from '../gedeeld/Icon'
import { SLOGAN, navLinks, partnerPunten, vragen } from '../landingData'
import { PaginaLink } from '../router/PaginaLink'

const CONTACT_MAIL = 'mailto:info@heitjehulp.nl'
const PARTNER_MAIL = 'mailto:info@heitjehulp.nl?subject=Partner%20worden%20van%20HeitjeHulp'

export function Partners() {
  return (
    <section className="lp-sectie" aria-label="Partner worden">
      <div className="lp-wrap lp-partners">
        <div className="lp-partnerkaart">
          <h2 className="lp-partnerkaart__titel">Word partner</h2>
          <p>Werk je bij een organisatie voor jongerenwerk? Mail ons en we vertellen je graag meer.</p>
          <a className="lp-pil lp-pil--limoen" href={PARTNER_MAIL}>
            Mail info@heitjehulp.nl
            <ArrowUpRight size={18} />
          </a>
        </div>
        <ul className="lp-punten">
          {partnerPunten.map((punt) => (
            <li key={punt.title}>
              <span className="lp-chip lp-chip--zacht">
                <Icon name={punt.icon} size={20} />
              </span>
              <div>
                <h2 className="lp-punten__titel">{punt.title}</h2>
                <p>{punt.text}</p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

export function Vragen() {
  return (
    <section className="lp-sectie" aria-label="Vragen en antwoorden">
      <div className="lp-wrap lp-vragen">
        {vragen.map((vraag) => (
          <details className="lp-vraag" key={vraag.vraag}>
            <summary>{vraag.vraag}</summary>
            <p>{vraag.antwoord}</p>
          </details>
        ))}
      </div>
    </section>
  )
}

// Staat onderaan elke pagina.
export function Contact() {
  return (
    <section className="lp-sectie lp-sectie--diep" id="contact" aria-labelledby="kop-contact">
      <div className="lp-wrap">
        <div className="lp-cta">
          <span className="lp-cta__lijn" aria-hidden="true" />
          <div>
            <h2 className="lp-h2" id="kop-contact">
              Meedoen of meer weten?
            </h2>
            <p className="lp-lead">Als bewoner, helper, ouder of organisatie: we horen graag van je.</p>
          </div>
          <a className="lp-pil lp-pil--limoen" href={CONTACT_MAIL}>
            Neem contact op
            <ArrowUpRight size={18} />
          </a>
        </div>
      </div>
    </section>
  )
}

export function Voet() {
  return (
    <footer className="lp-voet">
      <div className="lp-wrap lp-voet__binnen">
        <PaginaLink className="lp-logo" naar="/" aria-label="HeitjeHulp home">
          heitjehulp.
        </PaginaLink>
        <nav className="lp-voet__nav" aria-label="Pagina's">
          {navLinks.map((link) => (
            <PaginaLink key={link.href} naar={link.href}>
              {link.label}
            </PaginaLink>
          ))}
        </nav>
        <p>{SLOGAN} HeitjeHulp bemiddelt tussen bewoners en helpers en is geen werkgever.</p>
      </div>
    </footer>
  )
}

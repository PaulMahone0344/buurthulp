import { ArrowRight } from 'lucide-react'
import { beelden } from '../beelden'
import { Beeld } from '../gedeeld/Beeld'
import { Icon } from '../gedeeld/Icon'
import { rollen, wegwijzers } from '../landingData'
import { PaginaLink } from '../router/PaginaLink'

// Voorpagina: groot "Voor de buurt" met per groep een link naar de eigen pagina.
export function Wegwijzer() {
  return (
    <section className="lp-sectie" aria-labelledby="kop-wegwijzer">
      <div className="lp-wrap lp-voorwie">
        <h2 className="lp-voorwie__groot" id="kop-wegwijzer">
          <span>Voor de</span> <span>buurt</span>
        </h2>
        <div className="lp-voorwie__beeld" aria-hidden="true">
          <Beeld bron={beelden.gereedschap} />
        </div>
        <ul className="lp-wegwijzer">
          {wegwijzers.map((wijzer) => (
            <li key={wijzer.titel}>
              <PaginaLink naar={wijzer.href}>
                <span className="lp-chip lp-chip--zacht">
                  <Icon name={wijzer.icon} size={20} />
                </span>
                <span>
                  <strong>{wijzer.titel}</strong>
                  <span className="lp-wegwijzer__tekst">{wijzer.tekst}</span>
                </span>
                <span className="lp-wegwijzer__pijl" aria-hidden="true">
                  <ArrowRight size={18} />
                </span>
              </PaginaLink>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

export function Rollen() {
  return (
    <section className="lp-sectie" aria-label="De vier rollen">
      <div className="lp-wrap">
        <ul className="lp-rollen">
          {rollen.map((rol) => (
            <li className="lp-rol" key={rol.rol}>
              <div className="lp-rol__kop">
                <span className="lp-chip lp-chip--zacht">
                  <Icon name={rol.icon} size={20} />
                </span>
                <div>
                  <p className="lp-rol__naam">{rol.rol}</p>
                  <h2 className="lp-rol__titel">{rol.kop}</h2>
                </div>
              </div>
              <ul>
                {rol.items.map((item) => (
                  <li key={item.title}>
                    <strong>{item.title}</strong>
                    <span>{item.text}</span>
                  </li>
                ))}
              </ul>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

export function Bemiddelaar() {
  return (
    <section className="lp-sectie lp-sectie--aansluitend" aria-labelledby="kop-bemiddelaar">
      <div className="lp-wrap lp-bemiddelaar">
        <div>
          <span className="lp-label">Wie is HeitjeHulp</span>
          <h2 className="lp-h2 lp-h2--zinnen" id="kop-bemiddelaar">
            <span>Wij bemiddelen.</span> <span>Wij zijn geen werkgever.</span>
          </h2>
        </div>
        <p className="lp-lead">
          HeitjeHulp is een bedrijf dat bewoners en strijders bij elkaar brengt. De strijder is niet bij ons in dienst.
          Jij en de strijder spreken samen de klus af. Wij zorgen voor de app, de chat, het betalen en de meldkamer die
          meekijkt als er iets misgaat.
        </p>
      </div>
    </section>
  )
}

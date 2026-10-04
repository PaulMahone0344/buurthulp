import { ArrowRight, Quote } from 'lucide-react'
import { beelden } from '../beelden'
import { Beeld } from '../gedeeld/Beeld'
import { Vinkjes } from '../gedeeld/Vinkjes'
import { heroPoints, introText, verhaal } from '../landingData'
import { PaginaLink } from '../router/PaginaLink'

export function WatIsHet() {
  return (
    <section className="lp-sectie" aria-labelledby="kop-wat">
      <div className="lp-wrap lp-wat">
        <div>
          <span className="lp-label">Wat is HeitjeHulp</span>
          <h2 className="lp-h2" id="kop-wat">
            Een klein klusje, iemand uit de buurt.
          </h2>
          {introText.map((alinea) => (
            <p className="lp-lead" key={alinea.slice(0, 24)}>
              {alinea}
            </p>
          ))}
          <Vinkjes punten={heroPoints} />
          <PaginaLink className="lp-pil lp-pil--donker" naar="/zo-werkt-het">
            Zo werkt het
            <ArrowRight size={18} />
          </PaginaLink>
        </div>
        <div className="lp-wat__beeld" aria-hidden="true">
          <span className="lp-wat__achter" />
          <Beeld bron={beelden.kruiwagen} className="lp-wat__foto" />
        </div>
      </div>
    </section>
  )
}

export function Verhaal() {
  return (
    <section className="lp-sectie lp-sectie--aansluitend" aria-label={verhaal.bijschrift}>
      <div className="lp-wrap">
        <figure className="lp-verhaal">
          <Quote size={28} aria-hidden="true" />
          <blockquote>
            <p>{verhaal.tekst}</p>
          </blockquote>
          <figcaption>{verhaal.bijschrift}</figcaption>
        </figure>
      </div>
    </section>
  )
}

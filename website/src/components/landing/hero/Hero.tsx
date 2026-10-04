import { ArrowRight, ArrowUpRight } from 'lucide-react'
import { appLinks } from '../appUrl'
import { beelden } from '../beelden'
import { Beeld } from '../gedeeld/Beeld'
import { PaginaLink } from '../router/PaginaLink'

export function Hero() {
  return (
    <section className="lp-hero" aria-label="Introductie">
      <span className="lp-hero__lijn lp-hero__lijn--1" aria-hidden="true" />
      <span className="lp-hero__lijn lp-hero__lijn--2" aria-hidden="true" />

      <h1 className="lp-hero__kop">
        <span className="lp-hero__woord lp-in">heitje</span>{' '}
        <span className="lp-hero__slogan lp-in lp-in--3">voor een karweitje, in jouw buurt.</span>
      </h1>

      <div className="lp-hero__foto lp-in lp-in--2" aria-hidden="true">
        <Beeld bron={beelden.heroBoodschappen} laden="voorrang" />
      </div>
      {/* een heitje is een kwartje: de munt met de h */}
      <span className="lp-hero__munt" aria-hidden="true" />

      <PaginaLink className="lp-glas lp-glas--helper lp-in lp-in--3" naar="/helpers">
        <span className="lp-koppen" aria-hidden="true">
          <span>S</span>
          <span>D</span>
          <span>A</span>
          <span className="lp-koppen__plus">+</span>
        </span>
        <span className="lp-glas__regel">
          <span>Vind een strijder in je buurt</span>
          <ArrowRight size={18} />
        </span>
      </PaginaLink>

      <a className="lp-glas lp-glas--klus lp-in lp-in--3" href="#wat-kan-er">
        <Beeld bron={beelden.heroStraat} className="lp-glas__duim" laden="meteen" />
        <span>
          <strong>Klussen in de buurt</strong>
          <small>
            <span className="lp-stip" aria-hidden="true" />
            Tuin, boodschappen, klusjes in huis
          </small>
        </span>
        <span className="lp-glas__pijl" aria-hidden="true">
          <ArrowRight size={14} />
        </span>
      </a>

      <a className="lp-rond lp-hero__rond" href={appLinks.aanmelden} aria-label="Aanmelden">
        <ArrowUpRight size={24} strokeWidth={2.4} />
      </a>

      <PaginaLink className="lp-hero__uitleg" naar="/zo-werkt-het">
        <Beeld bron={beelden.heroVoordeur} className="lp-hero__uitleg-duim" laden="meteen" />
        <span>Zo werkt het</span>
      </PaginaLink>
    </section>
  )
}

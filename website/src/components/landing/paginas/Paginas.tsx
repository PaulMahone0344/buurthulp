import { ArrowRight } from 'lucide-react'
import { PaginaKop } from '../gedeeld/PaginaKop'
import { Hero } from '../hero/Hero'
import { PaginaLink } from '../router/PaginaLink'
import { Partners, Vragen } from '../secties/Afsluiting'
import { Beloning, HelperStappen } from '../secties/Helpers'
import { Kaders } from '../secties/Kaders'
import { Veiligheid } from '../secties/Veiligheid'
import { Bemiddelaar, Rollen, Wegwijzer } from '../secties/VoorWie'
import { Verhaal, WatIsHet } from '../secties/WatIsHet'
import { WatKanEr, Werkwijze } from '../secties/Werkwijze'

// Elke pagina: één hoofdkop, een paar blokken. Het contactblok en de voet
// zet LandingPage eronder.

export function Home() {
  return (
    <>
      <Hero />
      <WatIsHet />
      <WatKanEr />
      <Wegwijzer />
    </>
  )
}

export function ZoWerktHetPagina() {
  return (
    <>
      <PaginaKop label="Zo werkt het" kop="Van foto tot klaar, in vier stappen." />
      <Werkwijze />
      <Verhaal />
    </>
  )
}

export function VoorWiePagina() {
  return (
    <>
      <PaginaKop
        label="Voor wie"
        kop="Bewoners, helpers, ouders en de meldkamer."
        sub="Iedereen ziet in de app alleen wat bij hem of haar hoort."
      />
      <Rollen />
      <Bemiddelaar />
    </>
  )
}

export function HelpersPagina() {
  return (
    <>
      <PaginaKop
        label="Voor helpers"
        kop="Help je buurt en verdien je zakgeld."
        sub="Je kunt helpen vanaf 10 jaar. Er is geen maximum leeftijd."
      />
      <HelperStappen />
      <Beloning />
    </>
  )
}

export function VeiligheidPagina() {
  return (
    <>
      <PaginaKop
        label="Veiligheid"
        kop="Veilig helpen en geholpen worden."
        sub="De meldkamer van HeitjeHulp keurt elke helper goed en helpt als er iets misgaat."
      />
      <Veiligheid />
      <Kaders />
    </>
  )
}

export function PartnersPagina() {
  return (
    <>
      <PaginaKop
        label="Partners"
        kop="Samen met het jongerenwerk."
        sub="Organisaties voor jongerenwerk kennen de jongeren in de wijk. Als partner helpen ze HeitjeHulp bekend te maken. HeitjeHulp blijft zelf de bemiddelaar."
      />
      <Partners />
    </>
  )
}

export function VragenPagina() {
  return (
    <>
      <PaginaKop label="Vragen" kop="Veelgestelde vragen" />
      <Vragen />
    </>
  )
}

export function NietGevondenPagina() {
  return (
    <>
      <PaginaKop
        label="Niet gevonden"
        kop="Deze pagina bestaat niet."
        sub="Het adres klopt niet, of de pagina is verhuisd."
      />
      <section className="lp-sectie" aria-label="Verder">
        <div className="lp-wrap">
          <PaginaLink className="lp-pil lp-pil--donker" naar="/">
            Naar de voorpagina
            <ArrowRight size={18} />
          </PaginaLink>
        </div>
      </section>
    </>
  )
}

import { useEffect, useRef, type ComponentType } from 'react'
import '@fontsource-variable/inter'
import { SiteKop } from './hero/SiteKop'
import {
  HelpersPagina,
  Home,
  NietGevondenPagina,
  PartnersPagina,
  VeiligheidPagina,
  VoorWiePagina,
  VragenPagina,
  ZoWerktHetPagina,
} from './paginas/Paginas'
import { usePad } from './router/pad'
import { Contact, Voet } from './secties/Afsluiting'
import { TijdelijkBeheerKnop } from './TijdelijkBeheerKnop'
import './landing.css'
import './hero/hero.css'
import './secties/secties.css'

interface Pagina {
  titel: string
  Inhoud: ComponentType
}

const NAAM = 'HeitjeHulp'

// De adressen hier horen bij navLinks in landingData.ts.
const PAGINAS: Record<string, Pagina> = {
  '/': { titel: `${NAAM} — heitje voor een karweitje, in jouw buurt`, Inhoud: Home },
  '/zo-werkt-het': { titel: `Zo werkt het — ${NAAM}`, Inhoud: ZoWerktHetPagina },
  '/voor-wie': { titel: `Voor wie — ${NAAM}`, Inhoud: VoorWiePagina },
  '/helpers': { titel: `Helpers — ${NAAM}`, Inhoud: HelpersPagina },
  '/veiligheid': { titel: `Veiligheid — ${NAAM}`, Inhoud: VeiligheidPagina },
  '/partners': { titel: `Partners — ${NAAM}`, Inhoud: PartnersPagina },
  '/vragen': { titel: `Vragen — ${NAAM}`, Inhoud: VragenPagina },
}

const NIET_GEVONDEN: Pagina = { titel: `Pagina niet gevonden — ${NAAM}`, Inhoud: NietGevondenPagina }

export function LandingPage() {
  const pad = usePad()
  const { titel, Inhoud } = PAGINAS[pad] ?? NIET_GEVONDEN
  const hoofdRef = useRef<HTMLElement>(null)
  const vorigPad = useRef(pad)

  useEffect(() => {
    document.title = titel
    if (vorigPad.current === pad) return
    vorigPad.current = pad
    // na een paginawissel begint een schermlezer weer bovenaan de inhoud
    hoofdRef.current?.focus({ preventScroll: true })
  }, [pad, titel])

  return (
    <div className="lp">
      <SiteKop />
      <main ref={hoofdRef} tabIndex={-1}>
        <Inhoud />
        <Contact />
      </main>
      <Voet />
      <TijdelijkBeheerKnop />
    </div>
  )
}

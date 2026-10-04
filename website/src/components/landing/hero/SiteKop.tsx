import { useEffect, useId, useRef, useState } from 'react'
import { ArrowRight, Menu, X } from 'lucide-react'
import { appLinks } from '../appUrl'
import { navLinks } from '../landingData'
import { PaginaLink } from '../router/PaginaLink'
import { usePad } from '../router/pad'

export function SiteKop() {
  const pad = usePad()
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const knopRef = useRef<HTMLButtonElement>(null)
  const paneelId = useId()

  useEffect(() => {
    if (!isMenuOpen) return

    const opToets = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return
      setIsMenuOpen(false)
      knopRef.current?.focus()
    }
    // pointerdown en niet click: de klik die het menu opent is dan al voorbij,
    // en het icoon in de knop wisselt pas ná deze gebeurtenis.
    const opDrukBuiten = (event: PointerEvent) => {
      const doel = event.target
      if (doel instanceof Element && doel.closest('[data-lp-menu]')) return
      setIsMenuOpen(false)
    }

    document.addEventListener('keydown', opToets)
    document.addEventListener('pointerdown', opDrukBuiten)
    return () => {
      document.removeEventListener('keydown', opToets)
      document.removeEventListener('pointerdown', opDrukBuiten)
    }
  }, [isMenuOpen])

  const sluitMenu = () => setIsMenuOpen(false)

  return (
    <header className="lp-kop">
      <PaginaLink className="lp-logo" naar="/" aria-label="HeitjeHulp home">
        heitjehulp.
      </PaginaLink>
      <nav className="lp-nav" aria-label="Hoofdnavigatie">
        {navLinks.map((link) => (
          <PaginaLink key={link.href} naar={link.href} aria-current={pad === link.href ? 'page' : undefined}>
            {link.label}
          </PaginaLink>
        ))}
      </nav>
      <div className="lp-kop__acties">
        <a className="lp-pil lp-pil--rand" href={appLinks.inloggen}>
          Inloggen
        </a>
        <a className="lp-pil lp-pil--limoen" href={appLinks.aanmelden}>
          Aanmelden
        </a>
        <button
          ref={knopRef}
          className="lp-menuknop"
          type="button"
          aria-label="Menu"
          aria-expanded={isMenuOpen}
          aria-controls={isMenuOpen ? paneelId : undefined}
          onClick={() => setIsMenuOpen((open) => !open)}
          data-lp-menu=""
        >
          {isMenuOpen ? <X size={20} /> : <Menu size={20} />}
        </button>
      </div>
      {isMenuOpen ? (
        <nav className="lp-menupaneel" id={paneelId} aria-label="Menu" data-lp-menu="">
          {navLinks.map((link) => (
            <PaginaLink
              className="lp-menupaneel__rij"
              key={link.href}
              naar={link.href}
              aria-current={pad === link.href ? 'page' : undefined}
              onClick={sluitMenu}
            >
              {link.label}
              <ArrowRight size={18} />
            </PaginaLink>
          ))}
          <div className="lp-menupaneel__acties">
            <a className="lp-pil lp-pil--zacht" href={appLinks.inloggen}>
              Inloggen
            </a>
            <a className="lp-pil lp-pil--donker" href={appLinks.aanmelden}>
              Aanmelden
            </a>
          </div>
        </nav>
      ) : null}
    </header>
  )
}

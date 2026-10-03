// B3 — gedeelde stukjes van de ouder-pagina's: de kop van de site, een
// stap-kop die focus krijgt bij elke nieuwe stap, en de foutmelding.

import { useEffect, useRef, type ReactNode } from 'react'
import { T } from './teksten'

export function Merk() {
  return (
    <header className="ouder-kopbalk">
      <div className="ouder-kolom ouder-kopbalk__binnen">
        <a className="ouder-merk" href="#/">
          {T.merk}
          <span aria-hidden="true">.</span>
        </a>
      </div>
    </header>
  )
}

/** h1 die focus pakt zodra de stap verschijnt (schermlezers horen de nieuwe stap). */
export function StapKop({ children, stap }: { children: ReactNode; stap?: number }) {
  const kop = useRef<HTMLHeadingElement>(null)
  useEffect(() => kop.current?.focus(), [])
  return (
    <div className="ouder-stapkop">
      {stap ? <span className="ouder-stapnummer">{T.stap(stap)}</span> : null}
      <h1 ref={kop} tabIndex={-1}>
        {children}
      </h1>
    </div>
  )
}

export function Fout({ melding, id }: { melding: string; id?: string }) {
  if (!melding) return null
  return (
    <p className="ouder-fout" role="alert" id={id}>
      {melding}
    </p>
  )
}

export function Vinkje() {
  return (
    <svg className="ouder-icoon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M5 12.5l4.5 4.5L19 7.5" />
    </svg>
  )
}

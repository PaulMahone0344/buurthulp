// B3 — de eindstanden (mockup OuderKlaar): toestemming binnen / al gegeven
// (met "Toestemming intrekken" en een bevestigvraag), ingetrokken, verlopen.

import { useEffect, useRef, useState } from 'react'
import { Fout, StapKop, Vinkje } from './Kop'
import { T, toonDatum } from './teksten'

type KlaarProps = {
  naam: string
  netGegeven: boolean
  gegevenOp?: string
  bezig: boolean
  melding: string
  opIntrekken: () => void
}

export function OuderKlaar({ naam, netGegeven, gegevenOp, bezig, melding, opIntrekken }: KlaarProps) {
  const [vraag, setVraag] = useState(false)
  const datum = toonDatum(gegevenOp)
  return (
    <div className="ouder-eind">
      <span className="ouder-eind__teken" aria-hidden="true">
        <Vinkje />
      </span>
      <StapKop>{netGegeven ? T.bedanktKop : T.gegevenKop(naam)}</StapKop>
      <p className="ouder-eind__tekst">{netGegeven ? T.bedanktTekst(naam) : datum ? T.gegevenOp(datum) : ''}</p>
      <section className="ouder-kaart ouder-kaart--links" aria-label={T.intrekken}>
        <p>{T.intrekkenVraag}</p>
        <button className="ouder-linkknop" type="button" onClick={() => setVraag(true)} disabled={bezig}>
          {T.intrekken}
        </button>
        <Fout melding={melding} />
      </section>
      {vraag ? (
        <Bevestig
          naam={naam}
          bezig={bezig}
          opJa={() => {
            setVraag(false)
            opIntrekken()
          }}
          opNee={() => setVraag(false)}
        />
      ) : null}
    </div>
  )
}

function Bevestig({ naam, bezig, opJa, opNee }: { naam: string; bezig: boolean; opJa: () => void; opNee: () => void }) {
  const nee = useRef<HTMLButtonElement>(null)
  useEffect(() => {
    nee.current?.focus()
    const opToets = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && opNee()
    window.addEventListener('keydown', opToets)
    return () => window.removeEventListener('keydown', opToets)
  }, [opNee])
  return (
    <div className="ouder-scherm">
      <div className="ouder-venster" role="dialog" aria-modal="true" aria-labelledby="ouder-intrek-titel" aria-describedby="ouder-intrek-uitleg">
        <h2 id="ouder-intrek-titel">{T.intrekkenTitel}</h2>
        <p id="ouder-intrek-uitleg">{T.intrekkenUitleg(naam)}</p>
        <div className="ouder-venster__knoppen">
          <button className="ouder-knop ouder-knop--rood" type="button" onClick={opJa} disabled={bezig}>
            {T.intrekkenJa}
          </button>
          <button ref={nee} className="ouder-knop ouder-knop--licht" type="button" onClick={opNee}>
            {T.intrekkenNee}
          </button>
        </div>
      </div>
    </div>
  )
}

export function OuderMelding({ soort, naam }: { soort: 'ingetrokken' | 'verlopen'; naam: string }) {
  return (
    <div className="ouder-eind">
      <StapKop>{soort === 'ingetrokken' ? T.ingetrokkenKop : T.verlopenKop}</StapKop>
      <p className="ouder-eind__tekst">{soort === 'ingetrokken' ? T.ingetrokkenTekst(naam) : T.verlopenTekst(naam)}</p>
    </div>
  )
}

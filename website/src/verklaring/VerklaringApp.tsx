// B9 — "Verklaring van inzet" (punt 19): wie de verklaring krijgt (school,
// werkgever) of de helper zelf ziet hier wat er op stond, met de controle-
// code. Printen kan via de browser (ook als pdf). Zelfde stijl en kolom als
// de ouder-pagina's, op mobiel en desktop. Er staat alleen een voornaam op.

import { useEffect, useState, type FormEvent } from 'react'
import { Fout, Merk, StapKop } from '../ouder/Kop'
import { maakCode, verklaringHash } from './navigatie'
import { V } from './teksten'
import type { Verklaring, VerklaringApi } from './verklaringApi'
import '../ouder/ouder.css'
import './verklaring.css'

type Props = { api: VerklaringApi; code: string; opNaarCode?: (code: string) => void }

const melding = (e: unknown) => (e instanceof Error ? e.message : String(e))

export function VerklaringApp({ api, code, opNaarCode }: Props) {
  const [verklaring, setVerklaring] = useState<Verklaring | null>(null)
  const [laden, setLaden] = useState(!!code)
  const [fout, setFout] = useState('')

  useEffect(() => {
    if (!code) return
    // Een andere code = een nieuwe VerklaringApp (key in de ingang), dus de
    // begintoestand klopt al; hier alleen ophalen.
    let actief = true
    api
      .opzoeken(code)
      .then((v) => actief && setVerklaring(v))
      .catch((e: unknown) => actief && setFout(melding(e)))
      .finally(() => actief && setLaden(false))
    return () => {
      actief = false
    }
  }, [api, code])

  const naar = opNaarCode ?? ((c: string) => (window.location.hash = verklaringHash(c)))

  return (
    <div className="ouder">
      <Merk />
      <main className="ouder-kolom ouder-main" aria-busy={laden}>
        {!code ? <Invullen opCode={naar} /> : null}
        {code && laden ? <p className="ouder-sub">{V.laden}</p> : null}
        {code && !laden && !verklaring ? (
          <>
            <StapKop>{V.titel}</StapKop>
            <Fout melding={fout} />
            <Invullen opCode={naar} zonderKop />
          </>
        ) : null}
        {verklaring ? <Toon v={verklaring} /> : null}
      </main>
    </div>
  )
}

function Invullen({ opCode, zonderKop = false }: { opCode: (code: string) => void; zonderKop?: boolean }) {
  const [invoer, setInvoer] = useState('')
  const [fout, setFout] = useState('')
  function verstuur(e: FormEvent) {
    e.preventDefault()
    const code = maakCode(invoer)
    if (!code) {
      setFout(V.ongeldig)
      return
    }
    setFout('')
    opCode(code)
  }
  return (
    <>
      {zonderKop ? null : <StapKop>{V.invulKop}</StapKop>}
      <p className="ouder-sub">{V.invulSub}</p>
      <form className="verklaring-invul" onSubmit={verstuur} noValidate>
        <label className="ouder-veld">
          <span>{V.codeLabel}</span>
          <input
            value={invoer}
            onChange={(e) => setInvoer(e.target.value)}
            autoComplete="off"
            autoCapitalize="characters"
            spellCheck={false}
            aria-invalid={!!fout}
            aria-describedby={fout ? 'verklaring-fout' : undefined}
          />
        </label>
        <Fout melding={fout} id="verklaring-fout" />
        <button className="ouder-knop" type="submit">
          {V.nakijken}
        </button>
      </form>
    </>
  )
}

function Toon({ v }: { v: Verklaring }) {
  const g = v.gegevens
  const lijst = [...g.badges, ...g.vertrouwen]
  return (
    <article className="verklaring">
      <StapKop>{V.titel}</StapKop>
      <section className="ouder-kaart">
        <p className="verklaring__zin">{V.zin(g.voornaam, g.klussen)}</p>
        <ul className="verklaring__feiten">
          {g.periode_van ? <li>{V.periode(g.periode_van, g.periode_tot)}</li> : null}
          {g.uren > 0 ? <li>{V.uren(g.uren)}</li> : null}
          {g.niveau ? <li>{V.niveau(g.niveau)}</li> : null}
        </ul>
        {lijst.length ? (
          <>
            <h2 className="ouder-kaart__kop">{V.badgesKop}</h2>
            <ul className="verklaring__badges">
              {lijst.map((b) => (
                <li key={`${b.naam}-${b.datum}`}>
                  <span>{b.naam}</span>
                  <span className="verklaring__datum">{b.datum}</span>
                </li>
              ))}
            </ul>
          </>
        ) : null}
      </section>
      <section className="ouder-kaart verklaring__echt" aria-labelledby="verklaring-echt">
        <h2 id="verklaring-echt" className="ouder-kaart__kop">
          {V.echtKop}
        </h2>
        <p className="verklaring__code">{v.code}</p>
        <p>{V.echt(v.code, v.uitgegeven_op)}</p>
      </section>
      <div className="verklaring__knoppen">
        <button className="ouder-knop" type="button" onClick={() => window.print()}>
          {V.print}
        </button>
        <a className="ouder-knop ouder-knop--licht" href="#/verklaring">
          {V.andere}
        </a>
      </div>
      <p className="ouder-hulptekst">{V.voet}</p>
    </article>
  )
}

// B3 — stap 1 (mockup OuderCode): e-mailadres + code van 6 cijfers. Alleen
// nodig als de ouder zonder de link uit de mail op de pagina komt; met een
// geldige link slaat de pagina deze stap over (zie OuderApp).

import { useState, type FormEvent } from 'react'
import { CodeVakjes, CODE_LENGTE } from './CodeVakjes'
import { Fout, StapKop } from './Kop'
import { T } from './teksten'

type Props = {
  bezig: boolean
  melding: string
  opVerder: (email: string, code: string) => void
}

/** Huis, gereedschap, vinkje-in-cirkel (geen mensen of dieren). */
const UITLEG_ICONEN = [
  ['M4 11l8-6 8 6v9H4z', 'M10 20v-5h4v5'],
  ['M13 7l-9 9 3 3 9-9', 'M11 5l4-2 6 6-2 4z'],
  ['M8.5 12l2.5 2.5 4.5-5'],
]

export function OuderCode({ bezig, melding, opVerder }: Props) {
  const [email, setEmail] = useState('')
  const [cijfers, setCijfers] = useState<string[]>(Array(CODE_LENGTE).fill(''))
  const [eigenFout, setEigenFout] = useState('')

  function verstuur(e: FormEvent) {
    e.preventDefault()
    const code = cijfers.join('')
    if (!email.trim()) return setEigenFout(T.foutEmail)
    if (!/^\d{6}$/.test(code)) return setEigenFout(T.foutCode)
    setEigenFout('')
    opVerder(email.trim(), code)
  }

  return (
    <>
      <StapKop stap={1}>{T.codeKop}</StapKop>
      <ul className="ouder-uitleg">
        {T.codeUitleg.map((regel, i) => (
          <li key={regel}>
            <span className="ouder-uitleg__rondje" aria-hidden="true">
              <svg className="ouder-icoon" viewBox="0 0 24 24">
                {UITLEG_ICONEN[i].map((d) => (
                  <path key={d} d={d} />
                ))}
                {i === 2 ? <circle cx="12" cy="12" r="9" /> : null}
              </svg>
            </span>
            <span>{regel}</span>
          </li>
        ))}
      </ul>
      <form className="ouder-kaart" onSubmit={verstuur} noValidate>
        <h2 className="ouder-kaart__kop">{T.codeSectie}</h2>
        <div className="ouder-veld">
          <label htmlFor="ouder-email">{T.emailLabel}</label>
          <p id="ouder-email-uitleg" className="ouder-hulptekst">
            {T.emailUitleg}
          </p>
          <input
            id="ouder-email"
            type="email"
            autoComplete="email"
            aria-describedby="ouder-email-uitleg"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <fieldset className="ouder-veld">
          <legend>{T.codeLegend}</legend>
          <CodeVakjes waarde={cijfers} opWijzig={setCijfers} />
        </fieldset>
        <Fout melding={eigenFout || melding} />
        <button className="ouder-knop" type="submit" disabled={bezig}>
          {bezig ? T.bezig : T.verder}
        </button>
        <p className="ouder-hulptekst">{T.codeVoet}</p>
      </form>
    </>
  )
}

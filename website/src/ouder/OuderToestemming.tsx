// B3 — stap 2 (mockup OuderToestemming): 4 punten "Wat je moet weten", IBAN,
// naam, vinkje akkoord (verplicht) en vinkje AVP (mag nee). Eerst zelf
// nakijken, dan pas naar de server (die kijkt hetzelfde na).

import { useState, type FormEvent } from 'react'
import { isGeldigNlIban, normaliseerIban } from './iban'
import { Fout, StapKop, Vinkje } from './Kop'
import { T } from './teksten'

export type Toestemming = { naam: string; iban: string; avp: boolean }

type Props = {
  naam: string
  bezig: boolean
  melding: string
  opGeef: (t: Toestemming) => void
}

export function OuderToestemming({ naam, bezig, melding, opGeef }: Props) {
  const [iban, setIban] = useState('')
  const [ouderNaam, setOuderNaam] = useState('')
  const [akkoord, setAkkoord] = useState(false)
  const [avp, setAvp] = useState(false)
  const [eigenFout, setEigenFout] = useState('')

  function verstuur(e: FormEvent) {
    e.preventDefault()
    let fout = ''
    if (!akkoord) fout = T.foutAkkoord
    else if (ouderNaam.trim().length < 2) fout = T.foutNaam
    else if (!isGeldigNlIban(iban)) fout = T.foutIban
    setEigenFout(fout)
    if (!fout) opGeef({ naam: ouderNaam.trim(), iban: normaliseerIban(iban), avp })
  }

  return (
    <>
      <StapKop stap={2}>{T.toestemmingKop(naam)}</StapKop>
      <p className="ouder-sub">{T.toestemmingSub}</p>
      <section className="ouder-kaart" aria-labelledby="ouder-weten">
        <h2 id="ouder-weten" className="ouder-kaart__kop">
          {T.wetenKop}
        </h2>
        <ul className="ouder-weten">
          {T.weten(naam).map((regel) => (
            <li key={regel}>
              <Vinkje />
              <span>{regel}</span>
            </li>
          ))}
        </ul>
      </section>
      <form className="ouder-formulier" onSubmit={verstuur} noValidate>
        <div className="ouder-veld">
          <label htmlFor="ouder-iban">{T.ibanLabel}</label>
          <p id="ouder-iban-uitleg" className="ouder-hulptekst">
            {T.ibanUitleg(naam)}
          </p>
          <input
            id="ouder-iban"
            type="text"
            inputMode="text"
            autoComplete="off"
            spellCheck={false}
            className="ouder-invoer--iban"
            aria-describedby="ouder-iban-uitleg"
            placeholder={T.ibanPlaceholder}
            value={iban}
            onChange={(e) => setIban(e.target.value.toUpperCase())}
          />
        </div>
        <div className="ouder-veld">
          <label htmlFor="ouder-naam">{T.naamLabel}</label>
          <input
            id="ouder-naam"
            type="text"
            autoComplete="name"
            placeholder={T.naamPlaceholder}
            maxLength={100}
            value={ouderNaam}
            onChange={(e) => setOuderNaam(e.target.value)}
          />
        </div>
        <label className="ouder-vink">
          <input type="checkbox" checked={akkoord} onChange={(e) => setAkkoord(e.target.checked)} />
          <span>{T.akkoord(naam)}</span>
        </label>
        <div className="ouder-vink-blok">
          <label className="ouder-vink ouder-vink--licht">
            <input type="checkbox" checked={avp} aria-describedby="ouder-avp-uitleg" onChange={(e) => setAvp(e.target.checked)} />
            <span>{T.avp}</span>
          </label>
          <p id="ouder-avp-uitleg" className="ouder-hulptekst">
            {T.avpUitleg(naam)}
          </p>
        </div>
        <Fout melding={eigenFout || melding} />
        <button className="ouder-knop" type="submit" disabled={bezig}>
          {bezig ? T.bezig : T.geven}
        </button>
      </form>
    </>
  )
}

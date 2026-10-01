// M14 — inloggen op het beheerpaneel met een echt hh_users-account. Alleen
// rol coordinator komt erin; elke andere rol krijgt een nette weigering en is
// meteen weer uitgelogd (de data-laag doet dat). De echte grens zit in de
// API-rules: ook wie hieromheen werkt, krijgt van de server niets.

import { useState, type FormEvent } from 'react'
import { ArrowRight, LockKeyhole } from 'lucide-react'
import type { BeheerData } from './data/beheerData'
import type { Coordinator } from './data/types'
import { Foutmelding } from './gedeeld/Meldbalk'

type Props = {
  data: BeheerData
  opIngelogd: (coordinator: Coordinator) => void
}

export function BeheerLogin({ data, opIngelogd }: Props) {
  const [email, setEmail] = useState('')
  const [wachtwoord, setWachtwoord] = useState('')
  const [fout, setFout] = useState('')
  const [bezig, setBezig] = useState(false)

  async function verstuur(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setBezig(true)
    setFout('')
    const uitkomst = await data.inloggen(email, wachtwoord)
    setBezig(false)
    if (uitkomst.ok) {
      opIngelogd(uitkomst.coordinator)
    } else {
      setWachtwoord('')
      setFout(uitkomst.melding)
    }
  }

  return (
    <section className="auth-shell" aria-label="Beheerpaneel inloggen">
      <div className="auth-panel">
        <a className="ghost-button auth-panel__back" href="#/">
          Terug naar homepage
        </a>
        <div className="auth-panel__intro">
          <span className="auth-icon">
            <LockKeyhole size={24} />
          </span>
          <p className="section-label">Beheerpaneel</p>
          <h1>Inloggen voor de meldkamer</h1>
          <p>Alleen voor coordinatoren van HeitjeHulp. Log in met je eigen account.</p>
        </div>

        <form className="login-card" onSubmit={(e) => void verstuur(e)}>
          <label className="field">
            <span>E-mail</span>
            <input autoComplete="username" onChange={(e) => setEmail(e.target.value)} type="email" value={email} required />
          </label>
          <label className="field">
            <span>Wachtwoord</span>
            <input
              autoComplete="current-password"
              onChange={(e) => setWachtwoord(e.target.value)}
              type="password"
              value={wachtwoord}
              required
            />
          </label>
          <Foutmelding melding={fout} />
          <button className="button button--primary login-submit" type="submit" disabled={bezig}>
            {bezig ? 'Bezig met inloggen…' : 'Inloggen'}
            <ArrowRight size={18} />
          </button>
        </form>
      </div>
    </section>
  )
}

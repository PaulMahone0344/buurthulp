// B3 — de ouder-pagina (#/ouder). Drie schermen volgens de mockups, in een
// smalle kolom (560) op mobiel en desktop:
//   1. code (e-mail + 6 cijfers)  2. toestemming  3. klaar (+ intrekken)
//
// DE LINK UIT DE MAIL (#/ouder?t=<token>): de pagina vraagt de server meteen
// naar de stand. Is de code nog geldig, dan krijgt de ouder direct een
// sessie en slaat hij stap 1 over. Dat is net zo veilig als de code: link en
// code staan in dezelfde mail, de token is 40 willekeurige tekens en staat
// achter de # (komt nooit in een serverlog of Referer), en de toestemming
// zelf vraagt nog steeds naam, IBAN en het vinkje. Na 24 uur toont de link
// alleen nog de stand; intrekken met de link kan altijd.

import { useEffect, useState } from 'react'
import { Merk } from './Kop'
import { OuderCode } from './OuderCode'
import { OuderKlaar, OuderMelding } from './OuderKlaar'
import { OuderToestemming, type Toestemming } from './OuderToestemming'
import { OuderFout, type OuderApi, type OuderStand } from './ouderApi'
import { T, naamOf } from './teksten'
import './ouder.css'

type Stap =
  | { soort: 'laden' }
  | { soort: 'code' }
  | { soort: 'toestemming'; sessie: string }
  | { soort: 'klaar'; netGegeven: boolean; gegevenOp?: string; sessie?: string }
  | { soort: 'ingetrokken' }
  | { soort: 'verlopen' }

type Props = { api: OuderApi; token: string }

const melding = (e: unknown) => (e instanceof Error ? e.message : String(e))

export function OuderApp({ api, token }: Props) {
  const [stap, setStap] = useState<Stap>(token ? { soort: 'laden' } : { soort: 'code' })
  const [voornaam, setVoornaam] = useState('')
  const [fout, setFout] = useState('')
  const [bezig, setBezig] = useState(false)
  const naam = naamOf(voornaam)

  /** Van een antwoord van de server naar de juiste stap. */
  function volg(stand: OuderStand, sessie?: string) {
    setVoornaam(stand.voornaam ?? '')
    setFout('')
    if (stand.status === 'verstuurd' && stand.sessie) setStap({ soort: 'toestemming', sessie: stand.sessie })
    else if (stand.status === 'gegeven') setStap({ soort: 'klaar', netGegeven: !!sessie, gegevenOp: stand.gegeven_op, sessie })
    else if (stand.status === 'ingetrokken') setStap({ soort: 'ingetrokken' })
    else setStap({ soort: 'verlopen' })
  }

  useEffect(() => {
    if (!token) return
    let actief = true
    api
      .code({ token })
      .then((stand) => actief && volg(stand))
      .catch((e: unknown) => {
        if (!actief) return
        setFout(melding(e))
        setStap({ soort: 'code' })
      })
    return () => {
      actief = false
    }
    // Alleen bij het openen van de link.
  }, [api, token])

  async function metBezig(fn: () => Promise<void>) {
    setBezig(true)
    try {
      await fn()
    } catch (e) {
      setFout(melding(e))
      // Sessie verlopen (30 min): opnieuw de code, of de link opnieuw openen.
      if (e instanceof OuderFout && e.reden === 'sessie') setStap({ soort: 'code' })
    } finally {
      setBezig(false)
    }
  }

  const opCode = (email: string, code: string) =>
    metBezig(async () => {
      volg(await api.code({ email, code }))
    })

  const opGeef = (t: Toestemming, sessie: string) =>
    metBezig(async () => {
      volg(await api.toestemming({ sessie, naam: t.naam, iban: t.iban, akkoord: true, avp: t.avp }), sessie)
    })

  const opIntrekken = (sessie?: string) =>
    metBezig(async () => {
      volg(await api.intrekken(token ? { token } : { sessie: sessie ?? '' }))
    })

  return (
    <div className="ouder">
      <Merk />
      <main className="ouder-kolom ouder-main" aria-busy={stap.soort === 'laden'}>
        {stap.soort === 'laden' ? <p className="ouder-sub">{T.laden}</p> : null}
        {stap.soort === 'code' ? <OuderCode bezig={bezig} melding={fout} opVerder={opCode} /> : null}
        {stap.soort === 'toestemming' ? (
          <OuderToestemming naam={naam} bezig={bezig} melding={fout} opGeef={(t) => opGeef(t, stap.sessie)} />
        ) : null}
        {stap.soort === 'klaar' ? (
          <OuderKlaar
            naam={naam}
            netGegeven={stap.netGegeven}
            gegevenOp={stap.gegevenOp}
            bezig={bezig}
            melding={fout}
            opIntrekken={() => opIntrekken(stap.sessie)}
          />
        ) : null}
        {stap.soort === 'ingetrokken' || stap.soort === 'verlopen' ? <OuderMelding soort={stap.soort} naam={naam} /> : null}
      </main>
    </div>
  )
}

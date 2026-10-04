// B5 — de ouder keurt een klus goed (#/ouder/klus?token=<token>), besluit
// punt 1: een helper onder 18 reageert, de ouder krijgt een mail, en pas na
// "Goed" ziet de bewoner de reactie. Zelfde stijl en kolom (560) als de
// Ouder*-mockups van B3, op mobiel en desktop. Wat de ouder ziet: wat, waar
// (straat zonder huisnummer, of alleen de plaats), wanneer en de voornaam van
// de bewoner. De vraag vervalt als de klus begint.

import { useEffect, useState } from 'react'
import { Fout, Merk, StapKop, Vinkje } from '../Kop'
import { OuderFout } from '../ouderApi'
import type { Besluit, OuderKlusApi, OuderKlusStand } from './ouderKlusApi'
import { K } from './tekstenKlus'
import '../ouder.css'
import './ouderKlus.css'

type Props = { api: OuderKlusApi; token: string }

const melding = (e: unknown) => (e instanceof Error ? e.message : String(e))

export function OuderKlusApp({ api, token }: Props) {
  const [stand, setStand] = useState<OuderKlusStand | null>(null)
  const [laden, setLaden] = useState(!!token)
  const [fout, setFout] = useState(token ? '' : K.geenLink)
  const [bezig, setBezig] = useState<Besluit | null>(null)

  useEffect(() => {
    if (!token) return
    let actief = true
    api
      .stand(token)
      .then((s) => actief && setStand(s))
      .catch((e: unknown) => actief && setFout(melding(e)))
      .finally(() => actief && setLaden(false))
    return () => {
      actief = false
    }
  }, [api, token])

  async function kies(besluit: Besluit) {
    setBezig(besluit)
    setFout('')
    try {
      setStand(await api.besluit(token, besluit))
    } catch (e) {
      setFout(melding(e))
      if (e instanceof OuderFout && e.reden === 'link') setStand(null)
    } finally {
      setBezig(null)
    }
  }

  return (
    <div className="ouder">
      <Merk />
      <main className="ouder-kolom ouder-main" aria-busy={laden}>
        {laden ? <p className="ouder-sub">{K.laden}</p> : null}
        {!laden && !stand ? <Fout melding={fout} /> : null}
        {stand?.status === 'wacht' ? <Vraag stand={stand} bezig={bezig} fout={fout} opKies={kies} /> : null}
        {stand && stand.status !== 'wacht' ? <Eind stand={stand} /> : null}
      </main>
    </div>
  )
}

type VraagProps = { stand: OuderKlusStand; bezig: Besluit | null; fout: string; opKies: (b: Besluit) => void }

function Vraag({ stand, bezig, fout, opKies }: VraagProps) {
  const k = stand.klus
  const n = stand.helper_voornaam
  return (
    <>
      <StapKop>{K.kop(n)}</StapKop>
      <p className="ouder-sub">{K.sub}</p>
      <section className="ouder-kaart" aria-labelledby="ouder-klus-kop">
        <h2 id="ouder-klus-kop" className="ouder-kaart__kop">
          {K.kaartKop}
        </h2>
        <dl className="ouder-klus">
          <div>
            <dt>{K.wat}</dt>
            <dd>
              <strong>{k.wat}</strong>
              {k.omschrijving ? <span className="ouder-klus__omschrijving">{k.omschrijving}</span> : null}
            </dd>
          </div>
          <div>
            <dt>{K.waar}</dt>
            <dd>{k.waar || K.inDeBuurt}</dd>
          </div>
          <div>
            <dt>{K.wanneer}</dt>
            <dd>{k.wanneer || K.onbekend}</dd>
          </div>
          {k.bewoner_voornaam ? (
            <div>
              <dt>{K.bij}</dt>
              <dd>{k.bewoner_voornaam}</dd>
            </div>
          ) : null}
        </dl>
        {stand.ouder_gaat_mee ? <p className="ouder-klus__mee">{K.ouderMee(n)}</p> : null}
      </section>
      <Fout melding={fout} />
      <div className="ouder-klus__knoppen">
        <button className="ouder-knop" type="button" onClick={() => opKies('goed')} disabled={!!bezig}>
          {bezig === 'goed' ? K.bezig : K.goed}
        </button>
        <button className="ouder-knop ouder-knop--licht" type="button" onClick={() => opKies('lieverniet')} disabled={!!bezig}>
          {bezig === 'lieverniet' ? K.bezig : K.lieverNiet}
        </button>
      </div>
      <p className="ouder-hulptekst">{K.voet}</p>
    </>
  )
}

function Eind({ stand }: { stand: OuderKlusStand }) {
  const n = stand.helper_voornaam
  const [kop, tekst] =
    stand.status === 'goed'
      ? [K.goedKop, K.goedTekst(n)]
      : stand.status === 'lieverniet'
        ? [K.nietKop, K.nietTekst(n)]
        : stand.status === 'ingetrokken'
          ? [K.ingetrokkenKop, K.ingetrokkenTekst(n)]
          : [K.verlopenKop, K.verlopenTekst]
  return (
    <div className="ouder-eind">
      {stand.status === 'goed' ? (
        <span className="ouder-eind__teken" aria-hidden="true">
          <Vinkje />
        </span>
      ) : null}
      <StapKop>{kop}</StapKop>
      <p className="ouder-eind__tekst">{tekst}</p>
    </div>
  )
}

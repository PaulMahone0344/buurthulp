// B11 — "Nog bellen": de meldkamer belt elke nieuwe bewoner 5 minuten voor
// een kennismaking (besluit punt 20). Gesproken = de klussen van de bewoner
// kunnen gekeurd worden (met schakelaar b11_kennismaking_verplicht aan
// wachten ze daar op). Geweigerd = account geblokkeerd en open klussen
// zonder helper geannuleerd. Beide via POST /api/hh/meldkamer/kennismaking/{id}.

import { useState } from 'react'
import { Phone, PhoneCall } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { toonMoment } from '../data/tijd'
import type { Kennismakingbesluit, NieuweBewoner } from '../data/types'
import { Bevestigvenster } from '../gedeeld/Bevestigvenster'

type Props = {
  data: BeheerData
  bewoners: NieuweBewoner[]
  opGewijzigd: () => void
  opGelukt: (melding: string) => void
}

type Keuze = { bewoner: NieuweBewoner; besluit: Kennismakingbesluit }

const NOTITIE_MAX = 500

function telLink(telefoon: string): string {
  return `tel:${telefoon.replace(/[^\d+]/g, '')}`
}

function geluktTekst(naam: string, besluit: Kennismakingbesluit, geannuleerd: number, lopend: number): string {
  if (besluit === 'gesproken') return `Kennismaking met ${naam} staat erin. De klussen van ${naam} kun je nu keuren.`
  const delen = [`${naam} is geweigerd en kan niet meer inloggen.`]
  if (geannuleerd) delen.push(`${geannuleerd} open klus${geannuleerd === 1 ? '' : 'sen'} geannuleerd.`)
  if (lopend) delen.push(`Let op: ${lopend} klus${lopend === 1 ? '' : 'sen'} met een helper loopt nog; kijk die zelf na.`)
  return delen.join(' ')
}

export function Kennismaking({ data, bewoners, opGewijzigd, opGelukt }: Props) {
  const [keuze, setKeuze] = useState<Keuze | null>(null)
  const [notitie, setNotitie] = useState('')

  // Niemand te bellen: het blok blijft één regel, zodat het geen plek inneemt.
  const isLeeg = bewoners.length === 0

  function kies(bewoner: NieuweBewoner, besluit: Kennismakingbesluit) {
    setNotitie('')
    setKeuze({ bewoner, besluit })
  }

  return (
    <section className={isLeeg ? 'admin-card admin-card--kort' : 'admin-card'} aria-labelledby="nog-bellen-kop">
      <div className="admin-card__header">
        <div>
          <PhoneCall size={22} />
          <h2 id="nog-bellen-kop">
            Nog bellen <span className="seg-count">{bewoners.length}</span>
          </h2>
        </div>
      </div>
      {isLeeg ? <p className="empty-note">Iedereen is gebeld.</p> : null}
      {isLeeg ? null : (
        <p className="admin-muted">Nieuwe bewoners: bel ze even (5 minuten) om kennis te maken. Je mag iemand weigeren.</p>
      )}
      {isLeeg ? null : (
        <ul className="klus-kaarten" aria-label="Nieuwe bewoners om te bellen">
          {bewoners.map((b) => (
            <li key={b.id}>
              <article className="klus-kaart" aria-label={`Bellen: ${b.naam}`}>
                <header className="klus-kaart__kop">
                  <h3>{b.naam || 'Onbekende bewoner'}</h3>
                  <span className="admin-muted">aangemeld {toonMoment(b.aangemeldOp)}</span>
                </header>
                <p className="klus-kaart__meta">
                  {b.telefoon ? (
                    <a href={telLink(b.telefoon)}>
                      <Phone size={15} aria-hidden="true" /> {b.telefoon}
                    </a>
                  ) : (
                    <span>Geen telefoonnummer</span>
                  )}
                  <span>{[b.adres, b.plaats].filter(Boolean).join(', ')}</span>
                </p>
                <footer className="klus-kaart__voet">
                  <span />
                  <div className="beheer-acties">
                    <button className="mini-btn" type="button" onClick={() => kies(b, 'gesproken')}>
                      Gesproken
                    </button>
                    <button className="mini-btn mini-btn--ghost" type="button" onClick={() => kies(b, 'geweigerd')}>
                      Weigeren
                    </button>
                  </div>
                </footer>
              </article>
            </li>
          ))}
        </ul>
      )}

      {keuze ? (
        <Bevestigvenster
          titel={keuze.besluit === 'gesproken' ? `Gesproken met ${keuze.bewoner.naam}` : `${keuze.bewoner.naam} weigeren`}
          bevestigTekst={keuze.besluit === 'gesproken' ? 'Gesproken' : 'Weigeren'}
          magBevestigen={notitie.length <= NOTITIE_MAX && (keuze.besluit === 'gesproken' || notitie.trim().length > 0)}
          opSluit={() => setKeuze(null)}
          opBevestig={async () => {
            const uit = await data.kennismaking(keuze.bewoner.id, keuze.besluit, notitie)
            opGelukt(geluktTekst(keuze.bewoner.naam, keuze.besluit, uit.geannuleerd, uit.lopend))
            setKeuze(null)
            opGewijzigd()
          }}
        >
          {keuze.besluit === 'geweigerd' ? (
            <p className="beheer-signaal">
              Het account wordt geblokkeerd en open klussen zonder helper worden geannuleerd. Schrijf kort waarom.
            </p>
          ) : (
            <p className="admin-muted">Optioneel: een korte notitie. Alleen de meldkamer ziet hem.</p>
          )}
          <label className="field">
            <span>Notitie{keuze.besluit === 'geweigerd' ? '' : ' (optioneel)'}</span>
            <textarea value={notitie} maxLength={NOTITIE_MAX} onChange={(e) => setNotitie(e.target.value)} />
          </label>
        </Bevestigvenster>
      ) : null}
    </section>
  )
}

// B4 — "Klussen na te kijken". De meldkamer keurt elke klus voordat helpers
// hem zien (besluit punt 8). Per klus: de foto, de tekst, de markering van
// het voorfilter (telefoonnummer, e-mail, link, woord uit de nee-lijst) en
// twee knoppen. Afkeuren vraagt een reden; die krijgt de bewoner te zien.
// Beide lopen via POST /api/hh/klussen/{id}/keuren (hh_klusplaatsen.pb.js).
// B11: wacht een klus op de kennismaking (schakelaar aan), dan eerst bellen;
// goedkeuren staat uit, afkeuren mag wel.

import { useState } from 'react'
import { CalendarClock, ShieldCheck, UserRound, Wrench } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { toonMoment } from '../data/tijd'
import type { KlusNaTeKijken, Markering } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil } from '../gedeeld/Pil'
import { RedenVenster } from './RedenVenster'

type Props = {
  data: BeheerData
  klussen: KlusNaTeKijken[]
  opGewijzigd: () => void
  opGelukt: (melding: string) => void
}

const MARKERING_LABEL: Record<Markering, string> = {
  telefoon: 'Telefoonnummer',
  email: 'E-mail',
  link: 'Link',
  neelijst: 'Nee-lijst',
}

export function NaTeKijken({ data, klussen, opGewijzigd, opGelukt }: Props) {
  const [afkeuren, setAfkeuren] = useState<KlusNaTeKijken | null>(null)
  const [bezig, setBezig] = useState('')
  const [fout, setFout] = useState('')

  async function goedkeuren(klus: KlusNaTeKijken) {
    setBezig(klus.id)
    setFout('')
    try {
      await data.keurKlus(klus.id, { besluit: 'goedkeuren' })
      opGelukt(`De klus van ${klus.hulpvragerNaam} is goedgekeurd. Helpers in de buurt zien hem nu.`)
      opGewijzigd()
    } catch (e) {
      setFout(e instanceof Error ? e.message : String(e))
    } finally {
      setBezig('')
    }
  }

  return (
    <section className="admin-card" aria-labelledby="na-te-kijken-kop">
      <div className="admin-card__header">
        <div>
          <ShieldCheck size={22} />
          <h2 id="na-te-kijken-kop">
            Klussen na te kijken <span className="seg-count">{klussen.length}</span>
          </h2>
        </div>
      </div>
      <p className="admin-muted">Helpers zien een klus pas als je hem goedkeurt.</p>
      <Foutmelding melding={fout} />
      <ul className="klus-kaarten" aria-label="Klussen na te kijken">
        {klussen.map((klus) => (
          <li key={klus.id}>
            <article className="klus-kaart klus-kaart--nakijken" aria-label={`Na te kijken: klus van ${klus.hulpvragerNaam}`}>
              <header className="klus-kaart__kop">
                <h3>{klus.hulpvragerNaam || 'Onbekende bewoner'}</h3>
                {klus.wachtOpKennismaking ? <Pil toon="stop">Eerst bellen</Pil> : <Pil toon="nieuw">Na te kijken</Pil>}
              </header>
              <div className="klus-nakijken">
                {klus.fotoUrl ? (
                  <img className="klus-nakijken__foto" src={klus.fotoUrl} alt={`Foto bij de klus van ${klus.hulpvragerNaam}`} />
                ) : (
                  <p className="klus-nakijken__geen-foto">Geen foto</p>
                )}
                <div className="klus-nakijken__inhoud">
                  <p className="klus-kaart__meta">
                    <span>
                      <Wrench size={15} aria-hidden="true" /> {klus.klustypeNaam || 'Klus'}
                    </span>
                    <span>
                      <UserRound size={15} aria-hidden="true" /> vanaf {klus.minLeeftijd || 18} jaar
                    </span>
                    <span>
                      <CalendarClock size={15} aria-hidden="true" /> {toonMoment(klus.wanneerVan) || 'geen tijd'}
                    </span>
                  </p>
                  <p className="klus-nakijken__tekst">{klus.omschrijving || 'Geen omschrijving.'}</p>
                  {klus.markering.length ? (
                    <p className="klus-nakijken__markering" aria-label="Markering van het voorfilter">
                      {klus.markering.map((m) => (
                        <Pil key={m} toon="fout">
                          {MARKERING_LABEL[m]}
                        </Pil>
                      ))}
                    </p>
                  ) : null}
                </div>
              </div>
              <footer className="klus-kaart__voet">
                {klus.wachtOpKennismaking ? (
                  <span className="beheer-signaal">Bel eerst de bewoner (zie Nog bellen).</span>
                ) : (
                  <span />
                )}
                <div className="beheer-acties">
                  <button
                    className="mini-btn"
                    type="button"
                    disabled={bezig === klus.id || klus.wachtOpKennismaking}
                    onClick={() => void goedkeuren(klus)}
                  >
                    Goedkeuren
                  </button>
                  <button className="mini-btn mini-btn--ghost" type="button" onClick={() => setAfkeuren(klus)}>
                    Afkeuren
                  </button>
                </div>
              </footer>
            </article>
          </li>
        ))}
      </ul>
      {klussen.length === 0 ? <p className="empty-note">Er is niets na te kijken.</p> : null}

      {afkeuren ? (
        <RedenVenster
          titel={`Klus van ${afkeuren.hulpvragerNaam} afkeuren`}
          uitleg="De klus gaat niet door. De bewoner krijgt een melding met deze reden; schrijf hem in gewone taal."
          bevestigTekst="Afkeuren"
          min={5}
          max={300}
          opBevestig={(reden) => data.keurKlus(afkeuren.id, { besluit: 'afkeuren', reden })}
          opSluit={() => setAfkeuren(null)}
          opKlaar={() => {
            opGelukt(`De klus van ${afkeuren.hulpvragerNaam} is afgekeurd. De bewoner krijgt de reden te zien.`)
            setAfkeuren(null)
            opGewijzigd()
          }}
        />
      ) : null}
    </section>
  )
}

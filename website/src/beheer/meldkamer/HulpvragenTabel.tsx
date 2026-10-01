// M14 — de hulpvragentabel (D1) met de vier filters. Acties per klus:
// open zonder jongere -> handmatig koppelen of annuleren; aangenomen of
// onderweg -> vrijgeven of annuleren. Koppelen en vrijgeven lopen via de
// routes van M10, annuleren via de route van M6.

import { useState } from 'react'
import { ClipboardList } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { filterKlussen, HULPVRAAGFILTERS, type Hulpvraagfilter } from '../data/filters'
import { isZonderMatch } from '../data/tegels'
import { toonMoment } from '../data/tijd'
import type { Klus } from '../data/types'
import { KlusPil } from '../gedeeld/Pil'
import { HULPVRAAGFILTER_LABEL } from '../teksten'
import { KoppelVenster } from './KoppelVenster'
import { RedenVenster } from './RedenVenster'

type Props = {
  data: BeheerData
  klussen: Klus[]
  filter: Hulpvraagfilter
  zetFilter: (filter: Hulpvraagfilter) => void
  nu: () => Date
  opGewijzigd: () => void
}

type Actie = { soort: 'koppelen' | 'vrijgeven' | 'annuleren'; klus: Klus }

const KAN_KOPPELEN = (k: Klus) => k.status === 'open' && !k.jongereId
const KAN_VRIJGEVEN = (k: Klus) => k.status === 'geaccepteerd' || k.status === 'onderweg'
const KAN_ANNULEREN = (k: Klus) => k.status === 'open' || KAN_VRIJGEVEN(k)

export function HulpvragenTabel({ data, klussen, filter, zetFilter, nu, opGewijzigd }: Props) {
  const [actie, setActie] = useState<Actie | null>(null)
  const zichtbaar = filterKlussen(klussen, filter)

  function klaar() {
    setActie(null)
    opGewijzigd()
  }

  return (
    <>
      <div className="admin-card__header">
        <div>
          <ClipboardList size={22} />
          <h2>Hulpvragen</h2>
        </div>
      </div>
      <div className="seg" role="tablist" aria-label="Filter hulpvragen">
        {HULPVRAAGFILTERS.map((f) => (
          <button
            key={f}
            type="button"
            role="tab"
            aria-selected={filter === f}
            className={`seg-btn${filter === f ? ' is-active' : ''}`}
            onClick={() => zetFilter(f)}
          >
            {HULPVRAAGFILTER_LABEL[f]} <span className="seg-count">{filterKlussen(klussen, f).length}</span>
          </button>
        ))}
      </div>
      <div className="request-table" role="table" aria-label="Hulpvragen">
        {zichtbaar.map((klus) => (
          <div className="request-row request-row--beheer" role="row" key={klus.id} aria-label={`Hulpvraag van ${klus.hulpvragerNaam}`}>
            <div role="cell">
              <strong>
                {klus.hulpvragerNaam || 'Onbekende oudere'}
                {klus.bron === 'telefoon' ? <em className="beheer-label"> telefonisch</em> : null}
              </strong>
              <span>
                {klus.klustypeNaam || 'Klus'} · {toonMoment(klus.wanneerVan) || 'geen tijd'}
                {klus.jongereNaam ? ` · ${klus.jongereNaam}` : ''}
              </span>
              {klus.omschrijving ? <span>{klus.omschrijving}</span> : null}
              {isZonderMatch(klus, nu()) ? <span className="beheer-signaal">Langer dan 2 uur zonder match</span> : null}
            </div>
            <span role="cell">
              <KlusPil status={klus.status} />
            </span>
            <div role="cell" className="beheer-acties">
              {KAN_KOPPELEN(klus) ? (
                <button className="mini-btn" type="button" onClick={() => setActie({ soort: 'koppelen', klus })}>
                  Koppelen
                </button>
              ) : null}
              {KAN_VRIJGEVEN(klus) ? (
                <button className="mini-btn" type="button" onClick={() => setActie({ soort: 'vrijgeven', klus })}>
                  Vrijgeven
                </button>
              ) : null}
              {KAN_ANNULEREN(klus) ? (
                <button className="mini-btn mini-btn--ghost" type="button" onClick={() => setActie({ soort: 'annuleren', klus })}>
                  Annuleren
                </button>
              ) : null}
            </div>
          </div>
        ))}
        {zichtbaar.length === 0 ? <p className="empty-note">Geen hulpvragen in dit filter.</p> : null}
      </div>

      {actie?.soort === 'koppelen' ? (
        <KoppelVenster data={data} klus={actie.klus} opSluit={() => setActie(null)} opGekoppeld={klaar} />
      ) : null}
      {actie?.soort === 'vrijgeven' ? (
        <RedenVenster
          titel={`Klus van ${actie.klus.hulpvragerNaam} vrijgeven`}
          uitleg="De jongere gaat eraf en de klus staat weer open. Daarna kun je opnieuw koppelen."
          bevestigTekst="Vrijgeven"
          min={1}
          max={200}
          opBevestig={(reden) => data.vrijgeven(actie.klus.id, reden)}
          opSluit={() => setActie(null)}
          opKlaar={klaar}
        />
      ) : null}
      {actie?.soort === 'annuleren' ? (
        <RedenVenster
          titel={`Klus van ${actie.klus.hulpvragerNaam} annuleren`}
          uitleg="De klus gaat niet door. De reden komt in het logboek van de klus."
          bevestigTekst="Klus annuleren"
          min={5}
          max={300}
          opBevestig={(reden) => data.annuleren(actie.klus.id, reden)}
          opSluit={() => setActie(null)}
          opKlaar={klaar}
        />
      ) : null}
    </>
  )
}

// M14 — de hulpvragentabel (D1) met de vier filters: één regel per klus,
// zodat de lijst kort blijft. Acties per klus:
// open zonder jongere -> handmatig koppelen of annuleren; aangenomen of
// onderweg -> vrijgeven of annuleren. Koppelen en vrijgeven lopen via de
// routes van M10, annuleren via de route van M6.
// B11: bij een klus met helper kan de meldkamer de chat lezen.

import { useState } from 'react'
import { ClipboardList, Clock } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { filterKlussen, HULPVRAAGFILTERS, type Hulpvraagfilter } from '../data/filters'
import { isZonderMatch } from '../data/tegels'
import { toonMoment } from '../data/tijd'
import type { Klus } from '../data/types'
import { KlusPil } from '../gedeeld/Pil'
import { HULPVRAAGFILTER_LABEL } from '../teksten'
import { KoppelVenster } from './KoppelVenster'
import { ChatVenster } from './ChatVenster'
import { RedenVenster } from './RedenVenster'

type Props = {
  data: BeheerData
  klussen: Klus[]
  filter: Hulpvraagfilter
  zetFilter: (filter: Hulpvraagfilter) => void
  nu: () => Date
  opGewijzigd: () => void
  /** Na een actie verhuist een klus vaak naar een ander filter; zeg waar hij nu staat. */
  opGelukt: (melding: string) => void
}

type Actie = { soort: 'koppelen' | 'vrijgeven' | 'annuleren' | 'chat'; klus: Klus }

const KAN_KOPPELEN = (k: Klus) => k.status === 'open' && !k.jongereId
const KAN_VRIJGEVEN = (k: Klus) => k.status === 'geaccepteerd' || k.status === 'onderweg'
const KAN_ANNULEREN = (k: Klus) => k.status === 'open' || KAN_VRIJGEVEN(k)
// Een chat bestaat pas na de match (B6).
const KAN_CHAT_LEZEN = (k: Klus) => !!k.jongereId

export function HulpvragenTabel({ data, klussen, filter, zetFilter, nu, opGewijzigd, opGelukt }: Props) {
  const [actie, setActie] = useState<Actie | null>(null)
  const zichtbaar = filterKlussen(klussen, filter)

  function klaar(melding: string) {
    opGelukt(melding)
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
      {zichtbaar.length ? (
        <div className="beheer-tabel-wrap">
          <table className="beheer-tabel beheer-tabel--hulpvragen" aria-label="Hulpvragen">
            <thead>
              <tr>
                <th scope="col">Bewoner</th>
                <th scope="col" className="beheer-kolom--klus">
                  Klus
                </th>
                <th scope="col" className="beheer-kolom--wanneer">
                  Wanneer
                </th>
                <th scope="col" className="beheer-kolom--helper">
                  Strijder
                </th>
                <th scope="col" className="beheer-kolom--status">
                  Status
                </th>
                <th scope="col" className="beheer-tabel__actie">
                  <span className="beheer-alleen-lezer">Acties</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {zichtbaar.map((klus) => {
                const zonderMatch = isZonderMatch(klus, nu())
                return (
                  <tr
                    key={klus.id}
                    className={zonderMatch ? 'beheer-tabel__rij--wacht' : undefined}
                    aria-label={`Hulpvraag van ${klus.hulpvragerNaam}`}
                  >
                    <td>
                      <strong>{klus.hulpvragerNaam || 'Onbekende oudere'}</strong>
                      {klus.bron === 'telefoon' ? <em className="beheer-label"> telefonisch</em> : null}
                      {klus.omschrijving ? <span className="beheer-tabel__sub beheer-tabel__sub--kort">{klus.omschrijving}</span> : null}
                      {zonderMatch ? (
                        <span className="beheer-signaal beheer-tabel__signaal">
                          <Clock size={14} aria-hidden="true" /> Wacht langer dan 2 uur
                        </span>
                      ) : null}
                    </td>
                    <td>{klus.klustypeNaam || 'Klus'}</td>
                    <td className="beheer-tabel__kort">{toonMoment(klus.wanneerVan) || 'geen tijd'}</td>
                    <td>{klus.jongereNaam || <span className="admin-muted">–</span>}</td>
                    <td>
                      <KlusPil status={klus.status} />
                    </td>
                    <td className="beheer-tabel__actie">
                      <div className="beheer-acties">
                        {KAN_CHAT_LEZEN(klus) ? (
                          <button
                            className="mini-btn mini-btn--ghost"
                            type="button"
                            aria-label={`Chat lezen: klus van ${klus.hulpvragerNaam}`}
                            onClick={() => setActie({ soort: 'chat', klus })}
                          >
                            Chat
                          </button>
                        ) : null}
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
                          <button
                            className="mini-btn mini-btn--ghost"
                            type="button"
                            onClick={() => setActie({ soort: 'annuleren', klus })}
                          >
                            Annuleren
                          </button>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      ) : null}
      {zichtbaar.length === 0 ? <p className="empty-note">Geen hulpvragen in dit filter.</p> : null}

      {actie?.soort === 'chat' ? <ChatVenster data={data} klus={actie.klus} opSluit={() => setActie(null)} /> : null}
      {actie?.soort === 'koppelen' ? (
        <KoppelVenster
          data={data}
          klus={actie.klus}
          opSluit={() => setActie(null)}
          opGekoppeld={() => klaar(`De klus van ${actie.klus.hulpvragerNaam} is gekoppeld. Hij staat nu onder Gematcht.`)}
        />
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
          opKlaar={() => klaar(`De klus van ${actie.klus.hulpvragerNaam} staat weer open. Hij staat nu onder Nieuw.`)}
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
          opKlaar={() => klaar(`De klus van ${actie.klus.hulpvragerNaam} is geannuleerd. Hij staat nu onder Afgerond.`)}
        />
      ) : null}
    </>
  )
}

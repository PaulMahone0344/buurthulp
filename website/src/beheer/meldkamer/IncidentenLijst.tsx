// M14 — incidenten en noodknopmeldingen (D1), nieuwste bovenaan. Afhandelen
// = een aantekening in het veld afhandeling; daarna telt hij niet meer als
// open.

import { useState } from 'react'
import { Bell } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { filterIncidenten, INCIDENTFILTERS, sorteerIncidenten, type Incidentfilter } from '../data/filters'
import { toonMoment } from '../data/tijd'
import type { Incident } from '../data/types'
import { Bevestigvenster } from '../gedeeld/Bevestigvenster'
import { Pil } from '../gedeeld/Pil'
import { INCIDENTFILTER_LABEL, SOORT_LABEL } from '../teksten'

type Props = {
  data: BeheerData
  incidenten: Incident[]
  filter: Incidentfilter
  zetFilter: (filter: Incidentfilter) => void
  opGewijzigd: () => void
}

export function IncidentenLijst({ data, incidenten, filter, zetFilter, opGewijzigd }: Props) {
  const [open, setOpen] = useState<Incident | null>(null)
  const [afhandeling, setAfhandeling] = useState('')
  const zichtbaar = sorteerIncidenten(filterIncidenten(incidenten, filter))

  return (
    <>
      <div className="admin-card__header">
        <div>
          <Bell size={22} />
          <h2>Incidenten</h2>
        </div>
      </div>
      <div className="seg" role="tablist" aria-label="Filter incidenten">
        {INCIDENTFILTERS.map((f) => (
          <button
            key={f}
            type="button"
            role="tab"
            aria-selected={filter === f}
            className={`seg-btn${filter === f ? ' is-active' : ''}`}
            onClick={() => zetFilter(f)}
          >
            {INCIDENTFILTER_LABEL[f]} <span className="seg-count">{filterIncidenten(incidenten, f).length}</span>
          </button>
        ))}
      </div>
      <div className="incident-list" aria-label="Incidenten">
        {zichtbaar.map((incident) => (
          <article className="incident-row incident-row--beheer" key={incident.id} aria-label={`Melding van ${incident.melderNaam}`}>
            <span className={`sev ${incident.soort === 'nood' ? 'sev--hoog' : incident.soort === 'probleem' ? 'sev--middel' : 'sev--laag'}`}>
              {SOORT_LABEL[incident.soort] ?? 'Melding'}
            </span>
            <div>
              <strong>{incident.melderNaam || 'Onbekende melder'}</strong>
              <span>
                {toonMoment(incident.gemeldOp)}
                {incident.melderTelefoon ? ` · ${incident.melderTelefoon}` : ''}
                {incident.klusId ? '' : ' · noodknop, geen klus'}
              </span>
              {incident.omschrijving ? <span>{incident.omschrijving}</span> : null}
              {incident.afhandeling ? <span>Afhandeling: {incident.afhandeling}</span> : null}
            </div>
            {incident.afhandeling.trim() ? (
              <Pil toon="klaar">Afgehandeld</Pil>
            ) : (
              <button
                className="mini-btn"
                type="button"
                onClick={() => {
                  setAfhandeling('')
                  setOpen(incident)
                }}
              >
                Afhandelen
              </button>
            )}
          </article>
        ))}
        {zichtbaar.length === 0 ? <p className="empty-note">Geen meldingen in dit filter.</p> : null}
      </div>

      {open ? (
        <Bevestigvenster
          titel={`Melding van ${open.melderNaam} afhandelen`}
          bevestigTekst="Afgehandeld"
          magBevestigen={afhandeling.trim().length > 0}
          opSluit={() => setOpen(null)}
          opBevestig={async () => {
            await data.incidentAfhandelen(open.id, afhandeling)
            setOpen(null)
            opGewijzigd()
          }}
        >
          {open.omschrijving ? <p className="admin-muted">{open.omschrijving}</p> : null}
          <label className="field">
            <span>Wat heb je gedaan</span>
            <textarea rows={3} maxLength={1000} value={afhandeling} onChange={(e) => setAfhandeling(e.target.value)} />
          </label>
        </Bevestigvenster>
      ) : null}
    </>
  )
}

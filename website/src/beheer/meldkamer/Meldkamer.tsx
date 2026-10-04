// M14 — D1 MELDKAMER. Staat de hele dag open: vijf tegels, de incidenten
// aflopend op tijd, de hulpvragen met vier filters. Ververst vanzelf zodra er
// op de server iets aan hh_klussen of hh_incidenten verandert (realtime).
// B11: "Nog bellen" (kennismaking met nieuwe bewoners).
// Volgorde = wat het eerst moet: incidenten, bellen, nakijken, hulpvragen.
// Zonder filter in de URL staan alleen de nieuwe hulpvragen in beeld.

import { useCallback, useEffect, useState } from 'react'
import { PhoneCall } from 'lucide-react'
import type { BeheerData } from '../data/beheerData'
import { isHulpvraagfilter, isIncidentfilter } from '../data/filters'
import { meldkamerTegels } from '../data/tegels'
import type { Incident, Klus, KlusNaTeKijken, NieuweBewoner } from '../data/types'
import { Foutmelding, Gelukt } from '../gedeeld/Meldbalk'
import { Tegel } from '../gedeeld/Tegel'
import { useLaden } from '../gedeeld/useLaden'
import { HulpvragenTabel } from './HulpvragenTabel'
import { IncidentenLijst } from './IncidentenLijst'
import { Kennismaking } from './Kennismaking'
import { NaTeKijken } from './NaTeKijken'
import { TelefonischeAanmelding } from './TelefonischeAanmelding'

type Props = {
  data: BeheerData
  filters: Record<string, string>
  zetFilters: (filters: Record<string, string>) => void
  nu: () => Date
}

const GEEN_KLUSSEN: Klus[] = []
const GEEN_INCIDENTEN: Incident[] = []
const NIETS_NA_TE_KIJKEN: KlusNaTeKijken[] = []
const NIEMAND_TE_BELLEN: NieuweBewoner[] = []

export function Meldkamer({ data, filters, zetFilters, nu }: Props) {
  const laadKlussen = useCallback(() => data.klussen(), [data])
  const laadIncidenten = useCallback(() => data.incidenten(), [data])
  const laadNaTeKijken = useCallback(() => data.klussenNaTeKijken(), [data])
  const klussen = useLaden(laadKlussen, GEEN_KLUSSEN)
  const incidenten = useLaden(laadIncidenten, GEEN_INCIDENTEN)
  // B4: elke nieuwe klus eerst langs de meldkamer.
  const naTeKijken = useLaden(laadNaTeKijken, NIETS_NA_TE_KIJKEN)
  const laadNogTeBellen = useCallback(() => data.nogTeBellen(), [data])
  const nogTeBellen = useLaden(laadNogTeBellen, NIEMAND_TE_BELLEN)
  const [aanmelden, setAanmelden] = useState(false)
  const [gelukt, setGelukt] = useState('')

  const herlaadKlussen = klussen.herlaad
  const herlaadIncidenten = incidenten.herlaad
  const herlaadNaTeKijken = naTeKijken.herlaad
  const herlaadNogTeBellen = nogTeBellen.herlaad
  const herlaadAlles = useCallback(() => {
    void herlaadKlussen()
    void herlaadIncidenten()
    void herlaadNaTeKijken()
    void herlaadNogTeBellen()
  }, [herlaadKlussen, herlaadIncidenten, herlaadNaTeKijken, herlaadNogTeBellen])

  useEffect(() => data.abonneer(herlaadAlles), [data, herlaadAlles])

  const tegels = meldkamerTegels(klussen.waarde, incidenten.waarde, nu())
  const hulpvraagfilter = isHulpvraagfilter(filters.filter) ? filters.filter : 'nieuw'
  const incidentfilter = isIncidentfilter(filters.incidenten) ? filters.incidenten : 'open'

  return (
    <>
      <header className="dashboard-topbar">
        <div>
          <h1>Meldkamer</h1>
          <p>Hulpvragen en meldingen van vandaag. Ververst vanzelf.</p>
        </div>
        <button className="button button--primary" type="button" onClick={() => setAanmelden(true)}>
          <PhoneCall size={18} />
          Telefonische aanmelding
        </button>
      </header>

      <Gelukt melding={gelukt} />

      <div className="admin-stat-grid admin-stat-grid--vijf">
        <Tegel label="Open hulpvragen" waarde={tegels.open} />
        <Tegel label="Zonder match langer dan 2 uur" waarde={tegels.zonderMatch} />
        <Tegel label="Vandaag gepland" waarde={tegels.vandaagGepland} />
        <Tegel label="Nu bezig" waarde={tegels.nuBezig} />
        <Tegel label="Incidenten open" waarde={tegels.incidentenOpen} />
      </div>

      <section className="admin-card">
        <Foutmelding melding={incidenten.fout} />
        <IncidentenLijst
          data={data}
          incidenten={incidenten.waarde}
          filter={incidentfilter}
          zetFilter={(incidentenFilter) => zetFilters({ ...filters, incidenten: incidentenFilter })}
          opGewijzigd={herlaadAlles}
        />
      </section>

      <Foutmelding melding={nogTeBellen.fout} />
      <Kennismaking data={data} bewoners={nogTeBellen.waarde} opGewijzigd={herlaadAlles} opGelukt={setGelukt} />

      <Foutmelding melding={naTeKijken.fout} />
      <NaTeKijken data={data} klussen={naTeKijken.waarde} opGewijzigd={herlaadAlles} opGelukt={setGelukt} />

      <section className="admin-card">
        <Foutmelding melding={klussen.fout} />
        <HulpvragenTabel
          data={data}
          klussen={klussen.waarde}
          filter={hulpvraagfilter}
          zetFilter={(filter) => zetFilters({ ...filters, filter })}
          nu={nu}
          opGewijzigd={herlaadAlles}
          opGelukt={setGelukt}
        />
      </section>

      {aanmelden ? (
        <TelefonischeAanmelding
          data={data}
          opSluit={() => setAanmelden(false)}
          opGeplaatst={(naam) => {
            setAanmelden(false)
            setGelukt(`De hulpvraag van ${naam} staat open. Jongeren in de wijk zien hem nu.`)
            herlaadAlles()
          }}
        />
      ) : null}
    </>
  )
}

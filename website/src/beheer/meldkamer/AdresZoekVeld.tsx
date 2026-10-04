// ADRES (4 okt) — postcode + huisnummer (+ toevoeging) -> straat en plaats via
// dezelfde server-route als de app (GET /api/hh/adres, PDOK). Zoekt na 400 ms
// rust; meer adressen op één huisnummer = kiezen; niet gevonden = rustige
// melding. Straat en plaats zijn hier niet vrij te typen (alleen via de
// uitzondering "handmatig" in het formulier eromheen).

import { useEffect, useRef, useState } from 'react'
import type { BeheerData } from '../data/beheerData'
import { kanAdresZoeken, postcodeOpmaak } from '../data/telefonisch'
import type { AdresSuggestie } from '../data/types'

export const ADRES_ZOEK_WACHTTIJD_MS = 400

export type AdresInvoer = {
  postcode: string
  huisnummer: string
  toevoeging: string
  gekozen: AdresSuggestie | null
}

type Props = {
  data: BeheerData
  waarde: AdresInvoer
  opWijziging: (waarde: AdresInvoer) => void
}

type Stand =
  | { soort: 'leeg' }
  | { soort: 'zoeken' }
  | { soort: 'kiezen'; adressen: AdresSuggestie[]; melding: string }
  | { soort: 'melding'; tekst: string }

const NIET_IN_BUURT = 'Let op: dit adres ligt buiten het werkgebied (Tiel en 20 km). Aanmelden kan wel; er komt geen wijk bij.'
const DIENST_WEG =
  'PDOK (het adressenregister) is nu niet bereikbaar. Probeer het zo opnieuw, of kies "adres handmatig" als het niet anders kan.'

export function AdresZoekVeld({ data, waarde, opWijziging }: Props) {
  const [stand, setStand] = useState<Stand>({ soort: 'leeg' })
  const volgnummer = useRef(0)
  const { postcode, huisnummer, toevoeging, gekozen } = waarde

  useEffect(() => {
    if (gekozen || !kanAdresZoeken(postcode, huisnummer, toevoeging)) return
    const nummer = ++volgnummer.current
    const wacht = setTimeout(() => {
      setStand({ soort: 'zoeken' })
      void data.zoekAdres(postcode, huisnummer.trim(), toevoeging.trim()).then((uit) => {
        if (nummer !== volgnummer.current) return // intussen verder getypt
        if (uit.soort === 'gevonden' && uit.adressen.length === 1) {
          setStand({ soort: 'leeg' })
          opWijziging({ ...waarde, gekozen: uit.adressen[0] })
        } else if (uit.soort === 'gevonden') {
          setStand({ soort: 'kiezen', adressen: uit.adressen, melding: '' })
        } else if (uit.soort === 'nietgevonden' && uit.keuzes.length) {
          setStand({ soort: 'kiezen', adressen: uit.keuzes, melding: uit.melding })
        } else if (uit.soort === 'dienst') {
          setStand({ soort: 'melding', tekst: DIENST_WEG })
        } else {
          setStand({ soort: 'melding', tekst: uit.melding })
        }
      }).catch(() => {
        if (nummer === volgnummer.current) setStand({ soort: 'melding', tekst: DIENST_WEG })
      })
    }, ADRES_ZOEK_WACHTTIJD_MS)
    return () => clearTimeout(wacht)
    // waarde/opWijziging bewust niet: alleen opnieuw zoeken als de invoer verandert.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data, postcode, huisnummer, toevoeging, gekozen])

  function zet(veld: 'postcode' | 'huisnummer' | 'toevoeging', invoer: string) {
    volgnummer.current++
    setStand({ soort: 'leeg' })
    opWijziging({ ...waarde, [veld]: invoer, gekozen: null })
  }

  function kies(a: AdresSuggestie) {
    volgnummer.current++
    setStand({ soort: 'leeg' })
    opWijziging({ postcode: a.postcode, huisnummer: a.huisnummer, toevoeging: a.toevoeging, gekozen: a })
  }

  return (
    <div className="adres-zoek">
      <div className="adres-zoek__velden">
        <label className="field">
          <span>Postcode</span>
          <input
            value={postcode}
            autoComplete="postal-code"
            onChange={(e) => zet('postcode', postcodeOpmaak(e.target.value))}
          />
        </label>
        <label className="field">
          <span>Huisnummer</span>
          <input
            value={huisnummer}
            inputMode="numeric"
            onChange={(e) => zet('huisnummer', e.target.value.replace(/\D/g, '').slice(0, 5))}
          />
        </label>
        <label className="field">
          <span>Toevoeging (mag leeg)</span>
          <input
            value={toevoeging}
            onChange={(e) => zet('toevoeging', e.target.value.replace(/[^A-Za-z0-9 -]/g, '').slice(0, 6))}
          />
        </label>
      </div>
      <div aria-live="polite">
        {gekozen ? (
          <>
            <p className="adres-zoek__kaartje">
              <span aria-hidden="true">✓ </span>
              {gekozen.weergave}
            </p>
            {!gekozen.binnenWerkgebied ? <p className="beheer-hulp">{NIET_IN_BUURT}</p> : null}
          </>
        ) : stand.soort === 'zoeken' ? (
          <p className="beheer-hulp">Adres zoeken…</p>
        ) : stand.soort === 'kiezen' ? (
          <div className="adres-zoek__keuzes">
            {stand.melding ? <p className="beheer-hulp">{stand.melding}</p> : null}
            <p className="beheer-hulp">Op dit huisnummer zijn meer adressen. Kies het goede:</p>
            {stand.adressen.map((a) => (
              <button key={a.weergave} type="button" className="mini-btn mini-btn--ghost" onClick={() => kies(a)}>
                {a.weergave}
              </button>
            ))}
          </div>
        ) : stand.soort === 'melding' ? (
          <p className="beheer-hulp">{stand.tekst}</p>
        ) : (
          <p className="beheer-hulp">Postcode en huisnummer: straat en plaats vullen we zelf in.</p>
        )}
      </div>
    </div>
  )
}

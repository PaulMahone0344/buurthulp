// B11 — partners (jongerenwerk-organisaties). Besluit Ibrahim 4 okt: ALLEEN
// TELLEN. Elke partner krijgt een code; een helper vult die in bij het
// aanmelden. Hier: hoeveel helpers kwamen via de partner (aangemeld) en
// hoeveel daarvan zijn goedgekeurd. Uitzetten = de code werkt niet meer bij
// nieuwe aanmeldingen; wie er al is, blijft meetellen.

import { useCallback, useState, type FormEvent } from 'react'
import type { BeheerData } from '../data/beheerData'
import { MELDING_PARTNERCODE, partnerCode } from '../data/partners'
import type { Partner } from '../data/types'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil } from '../gedeeld/Pil'
import { useLaden } from '../gedeeld/useLaden'

const GEEN: Partner[] = []
const LEEG = { naam: '', code: '', notitie: '' }

export function Partners({ data }: { data: BeheerData }) {
  const laad = useCallback(() => data.partners(), [data])
  const partners = useLaden(laad, GEEN)
  const [fout, setFout] = useState('')
  const [nieuw, setNieuw] = useState(LEEG)

  async function voegToe(e: FormEvent) {
    e.preventDefault()
    if (nieuw.naam.trim().length < 2) return setFout('Vul de naam van de organisatie in.')
    if (!partnerCode(nieuw.code)) return setFout(MELDING_PARTNERCODE)
    try {
      await data.maakPartner(nieuw)
      setNieuw(LEEG)
      setFout('')
      void partners.herlaad()
    } catch (err) {
      setFout(err instanceof Error ? err.message : String(err))
    }
  }

  async function zetActief(p: Partner, actief: boolean) {
    try {
      await data.zetPartnerActief(p.id, actief)
      setFout('')
      void partners.herlaad()
    } catch (err) {
      setFout(err instanceof Error ? err.message : String(err))
    }
  }

  return (
    <>
      <h2>Partners</h2>
      <p className="admin-muted">
        Jongerenwerk-organisaties met een eigen code. Een helper vult de code in bij het aanmelden; hier zie je hoeveel helpers
        via de partner kwamen.
      </p>
      <Foutmelding melding={fout || partners.fout} />
      <div className="request-table" aria-label="Partners">
        {partners.waarde.map((p) => (
          <div className="request-row request-row--beheer" key={p.id} aria-label={`Partner ${p.naam}`}>
            <div>
              <strong>{p.naam}</strong>
              <span>
                Code <code>{p.code}</code>
                {p.notitie ? ` · ${p.notitie}` : ''}
              </span>
            </div>
            <span aria-label={`Aangemeld via ${p.naam}`}>
              <strong>{p.aangemeld}</strong> aangemeld
            </span>
            <span aria-label={`Goedgekeurd via ${p.naam}`}>
              <strong>{p.goedgekeurd}</strong> goedgekeurd
            </span>
            <Pil toon={p.actief ? 'klaar' : 'stop'}>{p.actief ? 'Code werkt' : 'Uit'}</Pil>
            <button className="mini-btn mini-btn--ghost" type="button" onClick={() => void zetActief(p, !p.actief)}>
              {p.actief ? `Zet ${p.naam} uit` : `Zet ${p.naam} aan`}
            </button>
          </div>
        ))}
      </div>
      {partners.geladen && partners.waarde.length === 0 ? <p className="empty-note">Nog geen partners.</p> : null}
      <form className="beheer-formulier beheer-formulier--raster" onSubmit={(e) => void voegToe(e)} aria-label="Nieuwe partner">
        <label className="field">
          <span>Naam organisatie</span>
          <input value={nieuw.naam} onChange={(e) => setNieuw({ ...nieuw, naam: e.target.value })} />
        </label>
        <label className="field">
          <span>Code (bijv. TIEL-JW)</span>
          <input value={nieuw.code} onChange={(e) => setNieuw({ ...nieuw, code: e.target.value.toUpperCase() })} />
        </label>
        <label className="field">
          <span>Notitie (optioneel)</span>
          <input value={nieuw.notitie} onChange={(e) => setNieuw({ ...nieuw, notitie: e.target.value })} />
        </label>
        <button className="mini-btn" type="submit">
          Partner toevoegen
        </button>
      </form>
    </>
  )
}

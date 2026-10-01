// M14 — één jongere beoordelen (D2). Documentfoto en selfie naast elkaar
// (PROTECTED bestanden: de url draagt een bestandstoken), VOG, IBAN, over mij.
// Goedkeuren en afkeuren alleen met een notitie (hh_profielen.screening_notitie).
// Het intakegesprek staat (nog) niet in het paneel: zie OPEN-PUNTEN-M14.

import { useState } from 'react'
import type { BeheerData } from '../data/beheerData'
import { controleerBesluit } from '../data/screening'
import { vogSignaal } from '../data/tegels'
import { toonDatum, toonMoment } from '../data/tijd'
import type { Profiel, Screeningbesluit, Screeningstatus } from '../data/types'
import { Foutmelding, Gelukt } from '../gedeeld/Meldbalk'
import { SCREENING_LABEL } from '../teksten'

type Props = {
  data: BeheerData
  profiel: Profiel
  nu: () => Date
  opSluit: () => void
  opBeoordeeld: () => void
}

const VOG_STATUSSEN: Screeningstatus[] = ['nieuw', 'in_behandeling', 'goedgekeurd', 'afgewezen']

function Foto({ url, titel }: { url: string; titel: string }) {
  return (
    <figure className="beheer-foto">
      {url ? <img src={url} alt={titel} /> : <p className="empty-note">Geen {titel.toLowerCase()} geüpload.</p>}
      <figcaption>{titel}</figcaption>
    </figure>
  )
}

export function ScreeningDetail({ data, profiel, nu, opSluit, opBeoordeeld }: Props) {
  const [vogStatus, setVogStatus] = useState<Screeningstatus | ''>(profiel.vogStatus)
  const [vogGeldigTot, setVogGeldigTot] = useState(profiel.vogGeldigTot)
  const [ibanGeverifieerd, setIbanGeverifieerd] = useState(profiel.ibanGeverifieerd)
  const [notitie, setNotitie] = useState('')
  const [fout, setFout] = useState('')
  const [gelukt, setGelukt] = useState('')
  const [bezig, setBezig] = useState(false)
  const signaal = vogSignaal(profiel.vogGeldigTot, nu())

  async function besluit(verificatiestatus: Screeningbesluit['verificatiestatus']) {
    const b: Screeningbesluit = { verificatiestatus, notitie, vogStatus, vogGeldigTot, ibanGeverifieerd }
    const probleem = controleerBesluit(b)
    setGelukt('')
    if (probleem) return setFout(probleem)
    setFout('')
    setBezig(true)
    try {
      await data.beoordeel(profiel.id, b)
      setGelukt(verificatiestatus === 'goedgekeurd' ? `${profiel.naam} is goedgekeurd.` : `${profiel.naam} is afgewezen.`)
      setNotitie('')
      opBeoordeeld()
    } catch (e) {
      setFout(e instanceof Error ? e.message : String(e))
    } finally {
      setBezig(false)
    }
  }

  return (
    <section className="admin-card" aria-label={`Screening van ${profiel.naam}`}>
      <div className="admin-card__header">
        <h2>{profiel.naam}</h2>
        <button className="ghost-button" type="button" onClick={opSluit}>
          Sluiten
        </button>
      </div>
      <p className="admin-muted">
        {profiel.email} · {profiel.wijkNaam || 'geen wijk'} · nu {SCREENING_LABEL[profiel.verificatiestatus].toLowerCase()}
      </p>
      <div className="beheer-fotos">
        <Foto url={profiel.documentFotoUrl} titel="Identiteitsbewijs" />
        <Foto url={profiel.selfieUrl} titel="Selfie" />
      </div>
      <dl className="beheer-gegevens">
        <dt>VOG</dt>
        <dd>
          {SCREENING_LABEL[profiel.vogStatus]}
          {profiel.vogAangevraagdOp ? `, aangevraagd ${toonMoment(profiel.vogAangevraagdOp)}` : ''}
          {profiel.vogGeldigTot ? `, geldig tot ${toonDatum(profiel.vogGeldigTot)}` : ''}
          {signaal ? <span className="beheer-signaal"> {signaal === 'verlopen' ? 'Verlopen' : 'Verloopt binnen 60 dagen'}</span> : null}
        </dd>
        <dt>IBAN</dt>
        <dd>
          {profiel.iban || 'niet ingevuld'} {profiel.ibanGeverifieerd ? '(geverifieerd)' : '(niet geverifieerd)'}
        </dd>
        <dt>Over mij</dt>
        <dd>{profiel.overMij || 'niet ingevuld'}</dd>
        {profiel.screeningNotitie ? (
          <>
            <dt>Vorige notitie</dt>
            <dd>{profiel.screeningNotitie}</dd>
          </>
        ) : null}
      </dl>

      <div className="beheer-formulier beheer-formulier--raster" aria-label="Besluit">
        <label className="field">
          <span>VOG-status</span>
          <select value={vogStatus} onChange={(e) => setVogStatus(e.target.value as Screeningstatus)}>
            {VOG_STATUSSEN.map((s) => (
              <option key={s} value={s}>
                {SCREENING_LABEL[s]}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>VOG geldig tot</span>
          <input type="date" value={vogGeldigTot} onChange={(e) => setVogGeldigTot(e.target.value)} />
        </label>
        <label className="beheer-vinkje">
          <input type="checkbox" checked={ibanGeverifieerd} onChange={(e) => setIbanGeverifieerd(e.target.checked)} />
          IBAN gecontroleerd
        </label>
        <label className="field">
          <span>Notitie (verplicht)</span>
          <textarea rows={3} maxLength={1000} value={notitie} onChange={(e) => setNotitie(e.target.value)} />
        </label>
      </div>
      <Foutmelding melding={fout} />
      <Gelukt melding={gelukt} />
      <div className="beheer-acties">
        <button className="mini-btn" type="button" disabled={bezig} onClick={() => void besluit('goedgekeurd')}>
          Goedkeuren
        </button>
        <button className="mini-btn mini-btn--ghost" type="button" disabled={bezig} onClick={() => void besluit('afgewezen')}>
          Afkeuren
        </button>
      </div>
    </section>
  )
}

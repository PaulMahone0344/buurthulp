// M14 — één helper beoordelen (D2). Documentfoto (PROTECTED: de url draagt een
// bestandstoken), VOG, IBAN, over mij. Goedkeuren en afkeuren alleen met een
// notitie (hh_profielen.screening_notitie). B2: selfie en intake zijn weg; er
// is een datumveld "VOG gezien op" (hh_profielen.vog_gezien_op, helper 18+).
// De rest van de meldkamer-ombouw is B11.

import { useState } from 'react'
import type { BeheerData } from '../data/beheerData'
import { controleerBesluit } from '../data/screening'
import { vogSignaal } from '../data/tegels'
import { toonDatum, toonMoment } from '../data/tijd'
import { AdresBronPil, NiveauPil } from '../gedeeld/Pil'
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
  const [vogGezienOp, setVogGezienOp] = useState(profiel.vogGezienOp)
  const [notitie, setNotitie] = useState('')
  const [fout, setFout] = useState('')
  const [gelukt, setGelukt] = useState('')
  const [bezig, setBezig] = useState(false)
  const signaal = vogSignaal(profiel.vogGeldigTot, nu())
  const [ouderStatus, setOuderStatus] = useState(profiel.ouderStatus)

  async function ouderVrij() {
    setGelukt('')
    setFout('')
    setBezig(true)
    try {
      await data.ouderVrijgeven(profiel.gebruikerId)
      setOuderStatus('vrijgegeven')
      setGelukt(`${profiel.naam} kan de ouder weer een mail sturen.`)
    } catch (e) {
      setFout(e instanceof Error ? e.message : String(e))
    } finally {
      setBezig(false)
    }
  }

  async function besluit(verificatiestatus: Screeningbesluit['verificatiestatus']) {
    const b: Screeningbesluit = { verificatiestatus, notitie, vogStatus, vogGeldigTot, ibanGeverifieerd, vogGezienOp }
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
      <AdresBronPil bron={profiel.adresBron} />
      <NiveauPil niveau={profiel.niveau} xp={profiel.xpTotaal} />
      <div className="beheer-fotos">
        <Foto url={profiel.documentFotoUrl} titel="Identiteitsbewijs" />
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
        {/* B3: alleen lezen. De ouder geeft toestemming via de ouder-pagina;
            de meldkamer zet het nooit zelf. */}
        <dt>Ouder</dt>
        <dd>
          {profiel.ouderToestemmingOp
            ? `Ouder gaf toestemming op ${toonDatum(profiel.ouderToestemmingOp)}`
            : 'Geen toestemming van een ouder (nodig onder 18)'}
          {profiel.ouderAvp === null ? null : (
            <span className="admin-muted"> · {profiel.ouderAvp ? 'AVP: ja' : 'AVP: nee'}</span>
          )}
          {/* B3: na intrekken mag het kind pas weer mailen als de meldkamer
              dat toestaat (eerst contact; B11 maakt hier een wachtrij van). */}
          {ouderStatus === 'ingetrokken' ? (
            <>
              <br />
              <span className="beheer-signaal">Ouder trok de toestemming in.</span>{' '}
              <button className="mini-btn mini-btn--ghost" type="button" disabled={bezig} onClick={() => void ouderVrij()}>
                Kind mag ouder opnieuw mailen
              </button>
            </>
          ) : null}
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
        {/* B2: helper 18+ kan pas klussen aannemen als dit gevuld is. */}
        <label className="field">
          <span>VOG gezien op</span>
          <input type="date" value={vogGezienOp} onChange={(e) => setVogGezienOp(e.target.value)} />
        </label>
        <label className="field">
          <span>Notitie (verplicht)</span>
          <textarea
            rows={3}
            maxLength={1000}
            value={notitie}
            aria-describedby="screening-notitie-uitleg"
            onChange={(e) => setNotitie(e.target.value)}
          />
        </label>
        {/* Besluit 2 okt: de jongere leest zijn eigen profiel, dus ook deze notitie. */}
        <small id="screening-notitie-uitleg" className="admin-muted">
          De jongere kan deze notitie lezen. Schrijf hem zakelijk.
        </small>
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

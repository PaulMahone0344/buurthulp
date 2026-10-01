// M14 — gebruikers zoeken, rol wijzigen, blokkeren (D4). Blokkeren zet
// hh_users.geblokkeerd; de hook hh_beheer.pb.js weigert dan inloggen en elke
// hh-aanroep van die gebruiker.

import { useCallback, useState, type FormEvent } from 'react'
import type { BeheerData } from '../data/beheerData'
import type { Gebruiker, Rol } from '../data/types'
import { Bevestigvenster } from '../gedeeld/Bevestigvenster'
import { Foutmelding } from '../gedeeld/Meldbalk'
import { Pil } from '../gedeeld/Pil'
import { useLaden } from '../gedeeld/useLaden'
import { ROL_LABEL } from '../teksten'

const ROLLEN: Rol[] = ['hulpvrager', 'jongere', 'familie', 'coordinator']
const GEEN: Gebruiker[] = []

type Handeling = { soort: 'rol'; gebruiker: Gebruiker; rol: Rol } | { soort: 'blok'; gebruiker: Gebruiker }

export function Gebruikers({ data, zoek, zetZoek }: { data: BeheerData; zoek: string; zetZoek: (zoek: string) => void }) {
  const laad = useCallback(() => data.zoekGebruikers(zoek), [data, zoek])
  const gebruikers = useLaden(laad, GEEN)
  const [invoer, setInvoer] = useState(zoek)
  const [rollen, setRollen] = useState<Record<string, Rol>>({})
  const [handeling, setHandeling] = useState<Handeling | null>(null)

  function zoeken(e: FormEvent) {
    e.preventDefault()
    zetZoek(invoer.trim())
  }

  return (
    <>
      <h2>Gebruikers</h2>
      <form className="beheer-formulier" onSubmit={zoeken} role="search">
        <label className="field">
          <span>Zoek op naam, e-mail of telefoon</span>
          <input value={invoer} onChange={(e) => setInvoer(e.target.value)} />
        </label>
        <button className="mini-btn" type="submit">
          Zoeken
        </button>
      </form>
      <Foutmelding melding={gebruikers.fout} />
      <div className="request-table" aria-label="Gebruikers">
        {gebruikers.waarde.map((g) => {
          const rol = rollen[g.id] ?? g.rol
          return (
            <div className="request-row request-row--beheer" key={g.id} aria-label={`Gebruiker ${g.naam}`}>
              <div>
                <strong>{g.naam}</strong>
                <span>
                  {g.email}
                  {g.telefoon ? ` · ${g.telefoon}` : ''}
                </span>
                {g.geblokkeerd ? <Pil toon="fout">Geblokkeerd</Pil> : null}
              </div>
              <label className="field">
                <span>Rol van {g.naam}</span>
                <select value={rol} onChange={(e) => setRollen({ ...rollen, [g.id]: e.target.value as Rol })}>
                  {ROLLEN.map((r) => (
                    <option key={r} value={r}>
                      {ROL_LABEL[r]}
                    </option>
                  ))}
                </select>
              </label>
              <div className="beheer-acties">
                <button
                  className="mini-btn"
                  type="button"
                  disabled={!rol || rol === g.rol}
                  onClick={() => rol && setHandeling({ soort: 'rol', gebruiker: g, rol })}
                >
                  Rol opslaan
                </button>
                <button className="mini-btn mini-btn--ghost" type="button" onClick={() => setHandeling({ soort: 'blok', gebruiker: g })}>
                  {g.geblokkeerd ? `Deblokkeer ${g.naam}` : `Blokkeer ${g.naam}`}
                </button>
              </div>
            </div>
          )
        })}
        {gebruikers.geladen && gebruikers.waarde.length === 0 ? <p className="empty-note">Niemand gevonden.</p> : null}
      </div>

      {handeling ? (
        <Bevestigvenster
          titel={
            handeling.soort === 'rol'
              ? `Rol van ${handeling.gebruiker.naam} wijzigen`
              : handeling.gebruiker.geblokkeerd
                ? `${handeling.gebruiker.naam} deblokkeren`
                : `${handeling.gebruiker.naam} blokkeren`
          }
          bevestigTekst={handeling.soort === 'rol' ? 'Rol wijzigen' : handeling.gebruiker.geblokkeerd ? 'Deblokkeren' : 'Blokkeren'}
          opSluit={() => setHandeling(null)}
          opBevestig={async () => {
            if (handeling.soort === 'rol') await data.wijzigRol(handeling.gebruiker.id, handeling.rol)
            else await data.zetGeblokkeerd(handeling.gebruiker.id, !handeling.gebruiker.geblokkeerd)
            setHandeling(null)
            void gebruikers.herlaad()
          }}
        >
          <p className="admin-muted">
            {handeling.soort === 'rol'
              ? `Van ${ROL_LABEL[handeling.gebruiker.rol as Rol] ?? 'geen rol'} naar ${ROL_LABEL[handeling.rol]}.`
              : handeling.gebruiker.geblokkeerd
                ? 'Deze gebruiker kan daarna weer inloggen.'
                : 'Deze gebruiker kan daarna niet meer inloggen en de app niet meer gebruiken.'}
          </p>
        </Bevestigvenster>
      ) : null}
    </>
  )
}

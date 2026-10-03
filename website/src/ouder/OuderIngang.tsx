// B3 — ingang van de ouder-pagina (#/ouder). Apart bestand zodat App.tsx hem
// lazy kan laden: bezoekers van de voorpagina krijgen deze code niet binnen.
// De server staat in VITE_POCKETBASE_URL (zoals het beheerpaneel).

import { useState } from 'react'
import { getPocketBaseUrl } from '../domain/serverUrl'
import { leesToken } from './navigatie'
import { OuderApp } from './OuderApp'
import { maakOuderApi } from './ouderApi'

export default function OuderIngang() {
  const [api] = useState(() => maakOuderApi(getPocketBaseUrl()))
  const [token] = useState(() => leesToken(window.location.hash))
  return <OuderApp api={api} token={token} />
}

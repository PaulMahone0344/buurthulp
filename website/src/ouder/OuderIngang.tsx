// B3 — ingang van de ouder-pagina (#/ouder). Apart bestand zodat App.tsx hem
// lazy kan laden: bezoekers van de voorpagina krijgen deze code niet binnen.
// De server staat in VITE_POCKETBASE_URL (zoals het beheerpaneel).

import { useState } from 'react'
import { getPocketBaseUrl } from '../domain/serverUrl'
import { isOuderKlusHash, leesKlusToken } from './klus/navigatieKlus'
import { OuderKlusApp } from './klus/OuderKlusApp'
import { maakOuderKlusApi } from './klus/ouderKlusApi'
import { leesToken } from './navigatie'
import { OuderApp } from './OuderApp'
import { maakOuderApi } from './ouderApi'

export default function OuderIngang() {
  // B5: #/ouder/klus?token= is de vraag "keur deze klus goed".
  const [klus] = useState(() => isOuderKlusHash(window.location.hash))
  return klus ? <KlusIngang /> : <ToestemmingIngang />
}

function ToestemmingIngang() {
  const [api] = useState(() => maakOuderApi(getPocketBaseUrl()))
  const [token] = useState(() => leesToken(window.location.hash))
  return <OuderApp api={api} token={token} />
}

function KlusIngang() {
  const [api] = useState(() => maakOuderKlusApi(getPocketBaseUrl()))
  const [token] = useState(() => leesKlusToken(window.location.hash))
  return <OuderKlusApp api={api} token={token} />
}

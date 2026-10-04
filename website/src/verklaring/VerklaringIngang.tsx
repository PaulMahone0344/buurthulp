// B9 — ingang van de verklaring-pagina (#/verklaring). Apart bestand zodat
// App.tsx hem lazy kan laden. De server staat in VITE_POCKETBASE_URL.

import { useEffect, useState } from 'react'
import { getPocketBaseUrl } from '../domain/serverUrl'
import { leesCode } from './navigatie'
import { maakVerklaringApi } from './verklaringApi'
import { VerklaringApp } from './VerklaringApp'

export default function VerklaringIngang() {
  const [api] = useState(() => maakVerklaringApi(getPocketBaseUrl()))
  const [code, setCode] = useState(() => leesCode(window.location.hash))
  useEffect(() => {
    const opWissel = () => setCode(leesCode(window.location.hash))
    window.addEventListener('hashchange', opWissel)
    return () => window.removeEventListener('hashchange', opWissel)
  }, [])
  return <VerklaringApp key={code} api={api} code={code} />
}

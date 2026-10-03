import { lazy, Suspense, useEffect, useState } from 'react'
import { LandingPage } from './components/landing/LandingPage'
import { isBeheerHash } from './beheer/navigatie'
import { isOuderHash } from './ouder/navigatie'
import './App.css'

// Het beheerpaneel (en de PocketBase-client) laden we pas op #/beheer.
const BeheerIngang = lazy(() => import('./beheer/BeheerIngang'))
// B3: de ouder-pagina's (toestemming met code) pas op #/ouder.
const OuderIngang = lazy(() => import('./ouder/OuderIngang'))

type Pagina = 'voorpagina' | 'beheer' | 'ouder'

function paginaVan(hash: string): Pagina {
  if (isBeheerHash(hash)) return 'beheer'
  if (isOuderHash(hash)) return 'ouder'
  return 'voorpagina'
}

function App() {
  const [pagina, setPagina] = useState(() => paginaVan(window.location.hash))

  useEffect(() => {
    const opWissel = () => setPagina(paginaVan(window.location.hash))
    window.addEventListener('hashchange', opWissel)
    return () => window.removeEventListener('hashchange', opWissel)
  }, [])

  if (pagina === 'ouder') {
    return (
      <Suspense fallback={<p className="empty-note">Laden…</p>}>
        <OuderIngang />
      </Suspense>
    )
  }

  if (pagina === 'beheer') {
    return (
      <Suspense fallback={<p className="empty-note">Beheerpaneel laden…</p>}>
        <BeheerIngang />
      </Suspense>
    )
  }

  return <LandingPage />
}

export default App

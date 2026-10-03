import { lazy, Suspense, useEffect, useState } from 'react'
import { LandingPage } from './components/landing/LandingPage'
import { isBeheerHash } from './beheer/navigatie'
import { isOuderHash } from './ouder/navigatie'
import './App.css'

// Het beheerpaneel (en de PocketBase-client) laden we pas op #/beheer.
const BeheerIngang = lazy(() => import('./beheer/BeheerIngang'))
// B3: de ouder-pagina's (toestemming met code) pas op #/ouder.
const OuderIngang = lazy(() => import('./ouder/OuderIngang'))

function App() {
  const [beheer, setBeheer] = useState(() => isBeheerHash(window.location.hash))
  // B3
  const [ouder, setOuder] = useState(() => isOuderHash(window.location.hash))

  useEffect(() => {
    const opWissel = () => {
      setBeheer(isBeheerHash(window.location.hash))
      setOuder(isOuderHash(window.location.hash)) // B3
    }
    window.addEventListener('hashchange', opWissel)
    return () => window.removeEventListener('hashchange', opWissel)
  }, [])

  // B3: ouder-pagina's
  if (ouder) {
    return (
      <Suspense fallback={<p className="empty-note">Laden…</p>}>
        <OuderIngang />
      </Suspense>
    )
  }

  if (beheer) {
    return (
      <Suspense fallback={<p className="empty-note">Beheerpaneel laden…</p>}>
        <BeheerIngang />
      </Suspense>
    )
  }

  return <LandingPage />
}

export default App

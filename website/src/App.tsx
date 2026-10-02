import { lazy, Suspense, useEffect, useState } from 'react'
import { LandingPage } from './components/landing/LandingPage'
import { isBeheerHash } from './beheer/navigatie'
import './App.css'

// Het beheerpaneel (en de PocketBase-client) laden we pas op #/beheer.
const BeheerIngang = lazy(() => import('./beheer/BeheerIngang'))

function App() {
  const [beheer, setBeheer] = useState(() => isBeheerHash(window.location.hash))

  useEffect(() => {
    const opWissel = () => setBeheer(isBeheerHash(window.location.hash))
    window.addEventListener('hashchange', opWissel)
    return () => window.removeEventListener('hashchange', opWissel)
  }, [])

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

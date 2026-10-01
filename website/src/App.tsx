import { useEffect, useState } from 'react'
import { AdminDashboard } from './components/AdminDashboard'
import { LandingPage } from './components/landing/LandingPage'
import { LoginPanel } from './components/LoginPanel'
import { HelperPortal, ResidentPortal } from './components/UserPortal'
import { roleHomeViews, type AppView, type UserSession } from './domain/auth'
import { createPocketBaseClient } from './domain/pocketbase'
import { BeheerApp } from './beheer/BeheerApp'
import { maakPocketbaseBeheerData } from './beheer/data/pocketbaseBeheerData'
import { isBeheerHash } from './beheer/navigatie'
import './App.css'

function App() {
  const [view, setView] = useState<AppView>('home')
  const [session, setSession] = useState<UserSession | null>(null)
  // M14: het echte beheerpaneel staat op #/beheer, los van de demo.
  const [beheer, setBeheer] = useState(() => isBeheerHash(window.location.hash))
  const [beheerData] = useState(() => (beheer ? maakPocketbaseBeheerData(createPocketBaseClient()) : null))

  useEffect(() => {
    const opWissel = () => setBeheer(isBeheerHash(window.location.hash))
    window.addEventListener('hashchange', opWissel)
    return () => window.removeEventListener('hashchange', opWissel)
  }, [])

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0 })
  }, [view])

  function handleLogin(user: UserSession) {
    setSession(user)
    setView(roleHomeViews[user.role])
  }

  function handleLogout() {
    setSession(null)
    setView('home')
  }

  if (beheer) {
    return <BeheerApp data={beheerData ?? maakPocketbaseBeheerData(createPocketBaseClient())} />
  }

  if (session?.role === 'admin' && view === 'admin') {
    return <AdminDashboard user={session} onLogout={handleLogout} />
  }

  if (session?.role === 'helper' && view === 'helper') {
    return <HelperPortal user={session} onLogout={handleLogout} />
  }

  if (session?.role === 'resident' && view === 'resident') {
    return <ResidentPortal user={session} onLogout={handleLogout} />
  }

  if (view === 'login') {
    return <LoginPanel onCancel={() => setView('home')} onLogin={handleLogin} />
  }

  return <LandingPage onOpenLogin={() => setView('login')} />
}

export default App

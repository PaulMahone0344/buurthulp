import { useEffect, useState } from 'react'
import { AdminDashboard } from './components/AdminDashboard'
import { LandingPage } from './components/landing/LandingPage'
import { LoginPanel } from './components/LoginPanel'
import { HelperPortal, ResidentPortal } from './components/UserPortal'
import { roleHomeViews, type AppView, type UserSession } from './domain/auth'
import './App.css'

function App() {
  const [view, setView] = useState<AppView>('home')
  const [session, setSession] = useState<UserSession | null>(null)

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

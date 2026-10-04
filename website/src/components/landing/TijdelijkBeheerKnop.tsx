// TIJDELIJK (Ibrahim, 4 okt 2026): snelle knop naar de meldkamer zolang de site
// nog niet online staat. Weghalen vóór livegang: dit bestand, de regel in
// LandingPage.tsx, het blok "TIJDELIJK" in landing.css en de test in App.test.tsx.
import { ShieldCheck } from 'lucide-react'

export function TijdelijkBeheerKnop() {
  return (
    <a className="lp-tijdelijk" href="/#/beheer">
      <ShieldCheck size={18} />
      Meldkamer
      <small>tijdelijk</small>
    </a>
  )
}

// De publieke site heeft echte adressen (/helpers, /vragen). Geen router-pakket:
// het adres lezen en bij een wissel opnieuw tekenen is alles wat nodig is.
// Het beheerpaneel en de ouder-pagina's blijven op de hash (#/beheer, #/ouder).
import { useSyncExternalStore } from 'react'

const WISSEL = 'popstate'

export function normaliseerPad(pad: string): string {
  const zonderSlash = pad.replace(/\/+$/, '')
  return zonderSlash === '' ? '/' : zonderSlash
}

function leesPad(): string {
  return normaliseerPad(window.location.pathname)
}

function abonneer(opWissel: () => void): () => void {
  window.addEventListener(WISSEL, opWissel)
  return () => window.removeEventListener(WISSEL, opWissel)
}

export function usePad(): string {
  return useSyncExternalStore(abonneer, leesPad)
}

export function navigeer(pad: string): void {
  if (normaliseerPad(pad) !== leesPad()) {
    window.history.pushState(null, '', pad)
    window.dispatchEvent(new PopStateEvent(WISSEL))
  }
  // een nieuwe pagina begint bovenaan, zonder de zachte scroll van ankers
  window.scrollTo({ top: 0, behavior: 'instant' })
}

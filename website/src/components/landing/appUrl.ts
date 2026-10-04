// Waar de webapp staat. Inloggen en aanmelden gebeurt daar, niet op deze site.
// De app gebruikt adressen met een hekje (#/inloggen).

type AppEnv = {
  VITE_APP_URL?: string
}

const STANDAARD_APP_URL = 'https://heitjehulp.app'

export function getAppUrl(env?: AppEnv): string {
  const bron = env ?? (import.meta.env as AppEnv)
  return (bron.VITE_APP_URL?.trim() || STANDAARD_APP_URL).replace(/\/+$/, '')
}

export const appLinks = {
  inloggen: `${getAppUrl()}/#/inloggen`,
  aanmelden: `${getAppUrl()}/#/registreren`,
}

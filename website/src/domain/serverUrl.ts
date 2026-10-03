// Waar de PocketBase-server staat. Los van pocketbase.ts, zodat de
// ouder-pagina (B3, alleen fetch) de PocketBase-client niet hoeft te laden.

type PocketBaseEnv = {
  VITE_POCKETBASE_URL?: string
}

export function getPocketBaseUrl(env?: PocketBaseEnv): string {
  const source = env ?? import.meta.env

  return source.VITE_POCKETBASE_URL?.trim() || 'http://localhost:8090'
}

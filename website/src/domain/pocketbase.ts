import PocketBase from 'pocketbase'

type PocketBaseEnv = {
  VITE_POCKETBASE_URL?: string
}

export function getPocketBaseUrl(env?: PocketBaseEnv): string {
  const source = env ?? import.meta.env

  return source.VITE_POCKETBASE_URL?.trim() || 'http://localhost:8090'
}

export function createPocketBaseClient(baseUrl = getPocketBaseUrl()) {
  return new PocketBase(baseUrl)
}

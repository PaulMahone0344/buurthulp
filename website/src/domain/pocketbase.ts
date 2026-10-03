import PocketBase from 'pocketbase'
import { getPocketBaseUrl } from './serverUrl'

export { getPocketBaseUrl }

export function createPocketBaseClient(baseUrl = getPocketBaseUrl()) {
  return new PocketBase(baseUrl)
}

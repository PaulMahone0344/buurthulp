import { describe, expect, it } from 'vitest'
import { getPocketBaseUrl } from './pocketbase'

describe('getPocketBaseUrl', () => {
  it('uses localhost PocketBase when no Vite URL is configured', () => {
    expect(getPocketBaseUrl({})).toBe('http://localhost:8090')
  })

  it('uses the configured PocketBase URL without trailing whitespace', () => {
    expect(
      getPocketBaseUrl({
        VITE_POCKETBASE_URL: ' https://api.qawayahbase.com ',
      }),
    ).toBe('https://api.qawayahbase.com')
  })
})

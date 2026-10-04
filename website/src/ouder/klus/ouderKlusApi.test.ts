import { describe, expect, it, vi } from 'vitest'
import { OuderFout } from '../ouderApi'
import { maakOuderKlusApi } from './ouderKlusApi'

function antwoord(status: number, body: unknown) {
  return Promise.resolve(new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }))
}

describe('ouderKlusApi', () => {
  it('vraagt de stand met de token als JSON', async () => {
    const fetchFn = vi.fn(() => antwoord(200, { status: 'wacht', helper_voornaam: 'Daan' }))
    const api = maakOuderKlusApi('https://api.test/', fetchFn)
    const uit = await api.stand('tok')
    expect(uit).toMatchObject({ status: 'wacht', helper_voornaam: 'Daan' })
    expect(fetchFn).toHaveBeenCalledWith('https://api.test/api/hh/ouder/klus', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: 'tok' }),
    })
  })

  it('stuurt het besluit naar de besluit-route', async () => {
    const fetchFn = vi.fn(() => antwoord(200, { status: 'goed' }))
    await maakOuderKlusApi('https://api.test', fetchFn).besluit('tok', 'lieverniet')
    expect(fetchFn).toHaveBeenCalledWith('https://api.test/api/hh/ouder/klus/besluit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: 'tok', besluit: 'lieverniet' }),
    })
  })

  it('geeft de melding en reden van de server door', async () => {
    const api = maakOuderKlusApi('https://api.test', () => antwoord(429, { melding: 'Te veel pogingen.', reden: 'teveel' }))
    const fout = await api.stand('tok').catch((e: unknown) => e)
    expect(fout).toBeInstanceOf(OuderFout)
    expect(fout).toMatchObject({ status: 429, reden: 'teveel', message: 'Te veel pogingen.' })
  })

  it('zonder verbinding een begrijpelijke melding', async () => {
    const api = maakOuderKlusApi('https://api.test', () => Promise.reject(new TypeError('Failed to fetch')))
    const fout = await api.besluit('tok', 'goed').catch((e: unknown) => e)
    expect(fout).toMatchObject({ status: 0, reden: 'verbinding' })
  })
})

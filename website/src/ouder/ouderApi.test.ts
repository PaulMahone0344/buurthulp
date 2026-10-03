import { describe, expect, it, vi } from 'vitest'
import { maakOuderApi, OuderFout } from './ouderApi'

function antwoord(status: number, body: unknown) {
  return Promise.resolve(new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }))
}

describe('ouderApi', () => {
  it('stuurt de code als JSON naar de hook-route', async () => {
    const fetchFn = vi.fn(() => antwoord(200, { status: 'verstuurd', voornaam: 'Daan', sessie: 's' }))
    const api = maakOuderApi('https://api.test/', fetchFn)
    const uit = await api.code({ email: 'mama@x.nl', code: '123456' })
    expect(uit).toEqual({ status: 'verstuurd', voornaam: 'Daan', sessie: 's' })
    expect(fetchFn).toHaveBeenCalledWith('https://api.test/api/hh/ouder/code', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'mama@x.nl', code: '123456' }),
    })
  })

  it('geeft de melding en reden van de server door', async () => {
    const api = maakOuderApi('https://api.test', () => antwoord(429, { melding: 'Te vaak fout.', reden: 'geblokkeerd' }))
    const fout = await api.code({ token: 't' }).catch((e: unknown) => e)
    expect(fout).toBeInstanceOf(OuderFout)
    expect(fout).toMatchObject({ status: 429, reden: 'geblokkeerd', message: 'Te vaak fout.' })
  })

  it('zonder verbinding een begrijpelijke melding', async () => {
    const api = maakOuderApi('https://api.test', () => Promise.reject(new TypeError('Failed to fetch')))
    const fout = await api.intrekken({ token: 't' }).catch((e: unknown) => e)
    expect(fout).toMatchObject({ status: 0, reden: 'verbinding' })
    expect((fout as Error).message).toMatch(/niet bereikbaar/)
  })

  it('toestemming en intrekken gaan naar hun eigen route', async () => {
    const fetchFn = vi.fn(() => antwoord(200, { status: 'gegeven', voornaam: 'Daan' }))
    const api = maakOuderApi('https://api.test', fetchFn)
    await api.toestemming({ sessie: 's', naam: 'Anna', iban: 'NL91ABNA0417164300', akkoord: true, avp: false })
    await api.intrekken({ sessie: 's' })
    expect(fetchFn.mock.calls.map((c) => (c as unknown[])[0])).toEqual([
      'https://api.test/api/hh/ouder/toestemming',
      'https://api.test/api/hh/ouder/intrekken',
    ])
  })
})

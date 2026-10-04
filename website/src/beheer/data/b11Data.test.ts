// B11 — data-laag van de meldkamer: omzetten, routes en de partnercode.

import PocketBase from 'pocketbase'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { zonderCode } from './filters'
import { MELDING_PARTNERCODE, partnerCode } from './partners'
import {
  klustypeBody,
  maakPocketbaseBeheerData,
  naarChatbericht,
  naarKlusNaTeKijken,
  naarKlustype,
  naarNieuweBewoner,
  naarPartner,
  naarVogRij,
} from './pocketbaseBeheerData'

type Antwoord = { status: number; body: unknown }

function nepServer(...antwoorden: Antwoord[]) {
  const aanroepen: Array<{ url: string; methode: string; body: unknown }> = []
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init?: RequestInit) => {
      aanroepen.push({ url: String(url), methode: String(init?.method ?? 'GET'), body: init?.body ? JSON.parse(String(init.body)) : undefined })
      const antwoord = antwoorden.shift() ?? { status: 500, body: {} }
      return new Response(JSON.stringify(antwoord.body), { status: antwoord.status, headers: { 'content-type': 'application/json' } })
    }),
  )
  return aanroepen
}

afterEach(() => {
  vi.unstubAllGlobals()
  localStorage.clear()
})

const record = (velden: Record<string, unknown>) =>
  ({ collectionId: 'c', collectionName: 'x', ...velden }) as unknown as Parameters<typeof naarKlustype>[0]

describe('B11 omzetten', () => {
  it('klustype: min_leeftijd heen en terug', () => {
    expect(naarKlustype(record({ id: 't1', naam: 'Tuin', min_leeftijd: 13 })).minLeeftijd).toBe(13)
    expect(klustypeBody({ richtduur: 60, minLeeftijd: 16 })).toEqual({ richtduur: 60, min_leeftijd: 16 })
    expect(klustypeBody({ richtduur: 60 })).toEqual({ richtduur: 60 })
  })

  it('klus na te kijken: wacht_op_kennismaking van de server', () => {
    const r = record({ id: 'k1', status: 'open', wacht_op_kennismaking: true })
    expect(naarKlusNaTeKijken(r, () => '').wachtOpKennismaking).toBe(true)
    expect(naarKlusNaTeKijken(record({ id: 'k2' }), () => '').wachtOpKennismaking).toBe(false)
  })

  it('VOG-rij, nieuwe bewoner, partner', () => {
    expect(
      naarVogRij({ gebruiker: 'u1', profiel: 'p1', naam: 'Sanne', leeftijd: 20, verificatiestatus: 'goedgekeurd', vog_gezien_op: '2023-09-01 10:00:00.000Z', verloopt_op: '2026-09-01', reden: 'verlopen' }),
    ).toEqual({ gebruikerId: 'u1', profielId: 'p1', naam: 'Sanne', leeftijd: 20, verificatiestatus: 'goedgekeurd', vogGezienOp: '2023-09-01T10:00:00.000Z', verlooptOp: '2026-09-01', reden: 'verlopen' })
    expect(naarVogRij({ reden: 'iets' }).reden).toBe('geen')
    expect(naarNieuweBewoner(record({ id: 'b1', naam: 'Anja', telefoon: '0612345678', adres: 'Kerkstraat 1', plaats: 'Tiel', created: '2026-10-04 08:00:00.000Z' }))).toEqual({
      id: 'b1', naam: 'Anja', telefoon: '0612345678', adres: 'Kerkstraat 1', plaats: 'Tiel', aangemeldOp: '2026-10-04T08:00:00.000Z',
    })
    expect(naarPartner({ id: 'p1', naam: 'JW Tiel', code: 'TIEL-JW', actief: true, aangemeld: 3, goedgekeurd: 2 })).toEqual({
      id: 'p1', naam: 'JW Tiel', code: 'TIEL-JW', actief: true, notitie: '', aangemeld: 3, goedgekeurd: 2,
    })
  })

  it('chatbericht: van de bewoner als afzender = hulpvrager van de klus', () => {
    const r = record({
      id: 'm1', afzender: 'b1', tekst: 'Hoi', created: '2026-10-04 08:00:00.000Z', gefilterd: true,
      expand: { afzender: { naam: 'Anja' }, klus: { hulpvrager: 'b1' } },
    })
    expect(naarChatbericht(r)).toMatchObject({ afzenderNaam: 'Anja', vanBewoner: true, gefilterd: true, contactverzoek: false, gewist: false })
    const h = record({ id: 'm2', afzender: 'h1', expand: { klus: { hulpvrager: 'b1' } } })
    expect(naarChatbericht(h).vanBewoner).toBe(false)
  })

  it('partnercode: zelfde regel als de server', () => {
    expect(partnerCode(' tiel jw ')).toBe('TIELJW')
    expect(partnerCode('tiel-jw')).toBe('TIEL-JW')
    expect(partnerCode('ab')).toBe('')
    expect(partnerCode('é-ok')).toBe('')
    expect(MELDING_PARTNERCODE).toMatch(/3 tot 20/)
  })

  it('zonderCode haalt de zp-code achteraan weg', () => {
    expect(zonderCode('[zelfde paar] Strijder Daan (15) en bewoner Kees. Kijk even. (zp:h1:b1)')).toBe('[zelfde paar] Strijder Daan (15) en bewoner Kees. Kijk even.')
    expect(zonderCode('Gewone melding (met haakjes)')).toBe('Gewone melding (met haakjes)')
  })
})

describe('B11 routes', () => {
  it('kennismaking: POST met besluit en notitie, uitkomst terug', async () => {
    const aanroepen = nepServer({ status: 200, body: { gebruiker: 'b1', kennismaking_status: 'geweigerd', geannuleerd: 2, lopend: 1 } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))
    expect(await data.kennismaking('b1', 'geweigerd', '  Wil zorg. ')).toEqual({ geannuleerd: 2, lopend: 1 })
    expect(aanroepen[0]).toMatchObject({ url: 'http://pb.test/api/hh/meldkamer/kennismaking/b1', methode: 'POST', body: { besluit: 'geweigerd', notitie: 'Wil zorg.' } })
  })

  it('kennismaking: Nederlandse melding van de server bij een weigering', async () => {
    nepServer({ status: 409, body: { melding: 'Een kennismaking is alleen voor bewoners.', reden: 'rol' } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))
    await expect(data.kennismaking('h1', 'gesproken', '')).rejects.toThrow('Een kennismaking is alleen voor bewoners.')
  })

  it('VOG-wachtrij en partners via de meldkamer-routes', async () => {
    const aanroepen = nepServer(
      { status: 200, body: { helpers: [{ gebruiker: 'u1', profiel: 'p1', naam: 'Sanne', leeftijd: 20, reden: 'geen' }] } },
      { status: 200, body: { partners: [{ id: 'p1', naam: 'JW', code: 'JW1', actief: true, aangemeld: 1, goedgekeurd: 0 }] } },
    )
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))
    expect((await data.vogWachtrij())[0]).toMatchObject({ naam: 'Sanne', reden: 'geen' })
    expect((await data.partners())[0]).toMatchObject({ code: 'JW1', aangemeld: 1 })
    expect(aanroepen.map((a) => a.url)).toEqual(['http://pb.test/api/hh/meldkamer/vog', 'http://pb.test/api/hh/meldkamer/partners'])
  })

  it('nieuwe partner: code in hoofdletters, ongeldige code komt niet bij de server', async () => {
    const aanroepen = nepServer({ status: 200, body: { id: 'p1' } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))
    await data.maakPartner({ naam: ' JW Tiel ', code: 'tiel-jw', notitie: '' })
    expect(aanroepen[0]).toMatchObject({ url: 'http://pb.test/api/collections/hh_partners/records', body: { naam: 'JW Tiel', code: 'TIEL-JW', actief: true } })
    await expect(data.maakPartner({ naam: 'X', code: 'a', notitie: '' })).rejects.toThrow(MELDING_PARTNERCODE)
    expect(aanroepen).toHaveLength(1)
  })

  it('klustype wijzigen stuurt min_leeftijd', async () => {
    const aanroepen = nepServer({ status: 200, body: { id: 't1' } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))
    await data.wijzigKlustype('t1', { minLeeftijd: 16 })
    expect(aanroepen[0].body).toEqual({ min_leeftijd: 16 })
  })

  it('chat: alle berichten van de klus, oudste eerst', async () => {
    const aanroepen = nepServer({ status: 200, body: { items: [], page: 1, perPage: 1000, totalItems: 0, totalPages: 1 } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))
    await data.chat('k1')
    const url = decodeURIComponent(aanroepen[0].url)
    expect(url).toContain('/api/collections/hh_berichten/records')
    expect(url).toContain("klus = 'k1'")
    expect(url).toContain('sort=created')
  })
})

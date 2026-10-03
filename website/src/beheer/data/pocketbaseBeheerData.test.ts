import PocketBase from 'pocketbase'
import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  maakPocketbaseBeheerData,
  naarAuditregel,
  naarInstelling,
  naarKlus,
  naarKlusNaTeKijken,
  naarProfiel,
} from './pocketbaseBeheerData'

type Antwoord = { status: number; body: unknown }

/** Een nep-server achter fetch: elke aanroep krijgt het volgende antwoord. */
function nepServer(...antwoorden: Antwoord[]) {
  const aanroepen: Array<{ url: string; methode: string; body: unknown }> = []
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init?: RequestInit) => {
      aanroepen.push({
        url: String(url),
        methode: String(init?.method ?? 'GET'),
        body: init?.body ? JSON.parse(String(init.body)) : undefined,
      })
      const antwoord = antwoorden.shift() ?? { status: 500, body: {} }
      return new Response(JSON.stringify(antwoord.body), {
        status: antwoord.status,
        headers: { 'content-type': 'application/json' },
      })
    }),
  )
  return aanroepen
}

function authAntwoord(rol: string): Antwoord {
  return {
    status: 200,
    body: {
      token: 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDB9.x',
      record: { id: 'u1', collectionName: 'hh_users', rol, naam: 'Iemand', email: 'a@b.nl' },
    },
  }
}

afterEach(() => {
  vi.unstubAllGlobals()
  localStorage.clear()
})

describe('inloggen', () => {
  it('laat een coordinator binnen', async () => {
    nepServer(authAntwoord('coordinator'))
    const pb = new PocketBase('http://pb.test')
    const data = maakPocketbaseBeheerData(pb)

    const uitkomst = await data.inloggen('a@b.nl', 'geheim')

    expect(uitkomst).toEqual({ ok: true, coordinator: { id: 'u1', naam: 'Iemand', email: 'a@b.nl' } })
    expect(data.huidige()?.id).toBe('u1')
  })

  it.each(['hulpvrager', 'jongere', 'familie'])('weigert rol %s en logt meteen weer uit', async (rol) => {
    nepServer(authAntwoord(rol))
    const pb = new PocketBase('http://pb.test')
    const data = maakPocketbaseBeheerData(pb)

    const uitkomst = await data.inloggen('a@b.nl', 'geheim')

    expect(uitkomst.ok).toBe(false)
    expect(pb.authStore.isValid).toBe(false)
    expect(data.huidige()).toBeNull()
  })

  it('geeft de melding van de server door bij een geblokkeerd account', async () => {
    nepServer({
      status: 400,
      body: { status: 400, message: 'Dit account is geblokkeerd. Neem contact op met de meldkamer.', data: {} },
    })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    const uitkomst = await data.inloggen('a@b.nl', 'geheim')

    expect(uitkomst).toEqual({ ok: false, melding: 'Dit account is geblokkeerd. Neem contact op met de meldkamer.' })
  })

  it('zegt niets over het account bij een verkeerd wachtwoord', async () => {
    nepServer({ status: 400, body: { status: 400, message: 'Failed to authenticate.', data: {} } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    expect(await data.inloggen('a@b.nl', 'fout')).toEqual({
      ok: false,
      melding: 'Controleer je e-mail en wachtwoord.',
    })
  })
})

describe('routes', () => {
  it('koppelt via de M10-route en geeft andere_wijk door', async () => {
    const aanroepen = nepServer({ status: 200, body: { klus: 'k1', status: 'geaccepteerd', andere_wijk: true } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    expect(await data.koppelen('k1', 'j1')).toEqual({ andereWijk: true })
    expect(aanroepen[0]).toMatchObject({
      url: 'http://pb.test/api/hh/klussen/k1/koppelen',
      methode: 'POST',
      body: { jongere: 'j1' },
    })
  })

  it('annuleert via de M6-route en toont de Nederlandse melding bij een weigering', async () => {
    nepServer({ status: 403, body: { melding: 'Je hoort niet bij deze klus.', reden: 'geendeelnemer' } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    await expect(data.annuleren('k1', 'Oudere belde af')).rejects.toThrow('Je hoort niet bij deze klus.')
  })

  it('maakt een telefonische klus met bedragen uit het klustype', async () => {
    const aanroepen = nepServer(
      { status: 200, body: { id: 't1', naam: 'tuin', richtduur: 60, richtvergoeding: 1500 } },
      { status: 200, body: { id: 'k9' } },
    )
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    const id = await data.maakTelefonischeKlus({
      hulpvragerId: 'o1',
      klustypeId: 't1',
      omschrijving: 'Heg knippen',
      adres: 'Kerkstraat 1, Tiel',
      wanneerVan: '2026-09-20T08:00:00.000Z',
      wanneerTot: '2026-09-20T09:00:00.000Z',
    })

    expect(id).toBe('k9')
    expect(aanroepen[1].url).toBe('http://pb.test/api/collections/hh_klussen/records')
    expect(aanroepen[1].body).toMatchObject({ bron: 'telefoon', status: 'open', bedrag_bruto: 1500, commissie: 0 })
  })
})

describe('koppelkandidaten', () => {
  it('laat geblokkeerde jongeren en jongeren met een verlopen VOG weg', async () => {
    const profiel = (id: string, naam: string, vog: string, geblokkeerd = false) => ({
      id: `p-${id}`,
      collectionName: 'hh_profielen',
      gebruiker: id,
      vog_geldig_tot: vog,
      klussen_aantal: 0,
      expand: { gebruiker: { id, naam, geblokkeerd, expand: { wijk: { wijk: 'Tiel-West' } } } },
    })
    nepServer({
      status: 200,
      body: {
        page: 1,
        perPage: 1000,
        totalItems: 4,
        totalPages: 1,
        items: [
          profiel('j1', 'Geldig', '2099-01-01 12:00:00.000Z'),
          profiel('j2', 'Zonder datum', ''),
          profiel('j3', 'Verlopen', '2020-01-01 12:00:00.000Z'),
          profiel('j4', 'Geblokkeerd', '2099-01-01 12:00:00.000Z', true),
        ],
      },
    })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    const kandidaten = await data.koppelkandidaten()

    expect(kandidaten.map((k) => k.naam)).toEqual(['Geldig', 'Zonder datum'])
  })
})

describe('omzetten', () => {
  it('zet een klus met uitgebreide relaties om', () => {
    const klus = naarKlus({
      id: 'k1',
      collectionId: 'c',
      collectionName: 'hh_klussen',
      status: 'open',
      bron: 'telefoon',
      created: '2026-09-19 10:00:00.000Z',
      wanneer_van: '2026-09-20 08:00:00.000Z',
      hulpvrager: 'o1',
      toegewezen_jongere: '',
      klustype: 't1',
      bedrag_bruto: 1250,
      expand: {
        hulpvrager: {
          id: 'o1',
          collectionId: 'u',
          collectionName: 'hh_users',
          naam: 'Mevrouw Jansen',
          telefoon: '0612345678',
          expand: { wijk: { id: 'w1', collectionId: 'w', collectionName: 'hh_wijken', wijk: 'Tiel-West' } },
        },
        klustype: { id: 't1', collectionId: 't', collectionName: 'hh_klustypes', naam: 'boodschappen' },
      },
    })

    expect(klus).toMatchObject({
      aangemaaktOp: '2026-09-19T10:00:00.000Z',
      wanneerVan: '2026-09-20T08:00:00.000Z',
      hulpvragerNaam: 'Mevrouw Jansen',
      hulpvragerWijkNaam: 'Tiel-West',
      klustypeNaam: 'boodschappen',
      bedragBruto: 1250,
      jongereNaam: '',
    })
  })

  it('maakt alleen een foto-url als er een bestand is', () => {
    const profiel = naarProfiel(
      {
        id: 'p1',
        collectionId: 'c',
        collectionName: 'hh_profielen',
        document_foto: 'id_abc.jpg',
        vog_geldig_tot: '2027-01-01 12:00:00.000Z',
        vog_gezien_op: '2026-10-01 12:00:00.000Z',
      },
      (bestand) => `https://pb/${bestand}?token=t`,
    )

    expect(profiel.documentFotoUrl).toBe('https://pb/id_abc.jpg?token=t')
    expect(profiel.vogGeldigTot).toBe('2027-01-01')
    expect(profiel.vogGezienOp).toBe('2026-10-01')
  })

  it('maakt van een json-waarde leesbare tekst', () => {
    expect(naarInstelling({ id: 'i', collectionId: 'c', collectionName: 'hh_instellingen', sleutel: 'straal_km', waarde: 5 }).waarde).toBe('5')
    expect(
      naarAuditregel({
        id: 'a',
        collectionId: 'c',
        collectionName: 'hh_auditlog',
        actie: 'wijzigen',
        detail: { velden: ['rol'] },
      }).detail,
    ).toBe('{"velden":["rol"]}')
  })
})

describe('B4 klussen nakijken', () => {
  it('keurt goed en af via de keur-route, met de reden erbij', async () => {
    const aanroepen = nepServer(
      { status: 200, body: { klus: 'k1', besluit: 'goedkeuren', status: 'open' } },
      { status: 200, body: { klus: 'k2', besluit: 'afkeuren', status: 'geannuleerd' } },
    )
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    await data.keurKlus('k1', { besluit: 'goedkeuren' })
    await data.keurKlus('k2', { besluit: 'afkeuren', reden: '  Sigaretten kan niet.  ' })

    expect(aanroepen[0]).toMatchObject({
      url: 'http://pb.test/api/hh/klussen/k1/keuren',
      methode: 'POST',
      body: { besluit: 'goedkeuren' },
    })
    expect(aanroepen[1]).toMatchObject({
      url: 'http://pb.test/api/hh/klussen/k2/keuren',
      body: { besluit: 'afkeuren', reden: 'Sigaretten kan niet.' },
    })
  })

  it('toont de Nederlandse melding als de server weigert', async () => {
    nepServer({ status: 409, body: { melding: 'Deze klus is al goedgekeurd.', reden: 'algoedgekeurd' } })
    const data = maakPocketbaseBeheerData(new PocketBase('http://pb.test'))

    await expect(data.keurKlus('k1', { besluit: 'goedkeuren' })).rejects.toThrow('Deze klus is al goedgekeurd.')
  })

  it('zet een ongekeurde klus om: foto met token, alleen bekende markeringen', () => {
    const klus = naarKlusNaTeKijken(
      {
        id: 'k1',
        collectionId: 'c',
        collectionName: 'hh_klussen',
        created: '2026-10-04 08:00:00.000Z',
        bron: 'app',
        omschrijving: 'Bel 0612345678',
        min_leeftijd: 13,
        wanneer_van: '2026-10-05 12:00:00.000Z',
        wanneer_tot: '',
        foto: ['heg_abc.jpg'],
        controle_markering: ['neelijst', 'telefoon', 'onbekend'],
        expand: {
          hulpvrager: { id: 'o1', collectionId: 'u', collectionName: 'hh_users', naam: 'Mevrouw Jansen' },
          klustype: { id: 't1', collectionId: 't', collectionName: 'hh_klustypes', naam: 'Tuin' },
        },
      },
      (bestand) => `https://pb/${bestand}?token=t`,
    )

    expect(klus).toMatchObject({
      id: 'k1',
      hulpvragerNaam: 'Mevrouw Jansen',
      klustypeNaam: 'Tuin',
      minLeeftijd: 13,
      omschrijving: 'Bel 0612345678',
      markering: ['telefoon', 'neelijst'],
      fotoUrl: 'https://pb/heg_abc.jpg?token=t',
    })
    expect(naarKlusNaTeKijken({ id: 'k2', collectionId: 'c', collectionName: 'hh_klussen' }, () => 'x').fotoUrl).toBe('')
  })
})

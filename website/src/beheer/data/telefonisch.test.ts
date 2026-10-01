import { describe, expect, it } from 'vitest'
import {
  controleerKlus,
  controleerOudere,
  nieuweOudereBody,
  telefonischEmail,
  telefonischeKlusBody,
  willekeurigWachtwoord,
} from './telefonisch'
import type { Klustype, NieuweKlus, NieuweOudere } from './types'

const oudere: NieuweOudere = {
  naam: ' Mevrouw Jansen ',
  telefoon: '06-12 34 56 78',
  email: '',
  adres: 'Kerkstraat 1',
  postcode: '4001AB',
  plaats: 'Tiel',
  wijkId: 'w1',
}

const klustype: Klustype = { id: 't1', naam: 'boodschappen', icoon: '', richtduur: 60, richtvergoeding: 1250 }

const klus: NieuweKlus = {
  hulpvragerId: 'o1',
  klustypeId: 't1',
  omschrijving: ' Boodschappen bij de Jumbo ',
  adres: 'Kerkstraat 1, Tiel',
  wanneerVan: '2026-09-20T08:00:00.000Z',
  wanneerTot: '2026-09-20T09:00:00.000Z',
}

describe('telefonischEmail', () => {
  it('maakt een onbereikbaar adres van de cijfers van het telefoonnummer', () => {
    expect(telefonischEmail('06-12 34 56 78')).toBe('0612345678@telefonisch.heitjehulp.invalid')
  })
})

describe('willekeurigWachtwoord', () => {
  it('is lang genoeg en elke keer anders', () => {
    const a = willekeurigWachtwoord()
    expect(a.length).toBeGreaterThanOrEqual(30)
    expect(willekeurigWachtwoord()).not.toBe(a)
  })
})

describe('nieuwe oudere', () => {
  it('eist naam, telefoon en wijk', () => {
    expect(controleerOudere(oudere)).toBe('')
    expect(controleerOudere({ ...oudere, naam: ' ' })).not.toBe('')
    expect(controleerOudere({ ...oudere, telefoon: '0612' })).not.toBe('')
    expect(controleerOudere({ ...oudere, wijkId: '' })).not.toBe('')
  })

  it('wordt een hulpvrager met het telefonische adres als er geen e-mail is', () => {
    const body = nieuweOudereBody(oudere, 'geheim-wachtwoord')
    expect(body.rol).toBe('hulpvrager')
    expect(body.email).toBe('0612345678@telefonisch.heitjehulp.invalid')
    expect(body.naam).toBe('Mevrouw Jansen')
    expect(body.wijk).toBe('w1')
    expect(body.password).toBe(body.passwordConfirm)
  })

  it('houdt een echte e-mail aan', () => {
    expect(nieuweOudereBody({ ...oudere, email: 'jansen@example.nl' }, 'x').email).toBe('jansen@example.nl')
  })
})

describe('telefonische klus', () => {
  it('controleert de verplichte velden en de volgorde van de tijden', () => {
    expect(controleerKlus(klus)).toBe('')
    expect(controleerKlus({ ...klus, hulpvragerId: '' })).not.toBe('')
    expect(controleerKlus({ ...klus, klustypeId: '' })).not.toBe('')
    expect(controleerKlus({ ...klus, wanneerTot: klus.wanneerVan })).not.toBe('')
  })

  it('heeft dezelfde vorm als een app-klus, met bron telefoon en de coordinator als plaatser', () => {
    expect(telefonischeKlusBody(klus, klustype, 'c1')).toEqual({
      hulpvrager: 'o1',
      geplaatst_door: 'c1',
      klustype: 't1',
      omschrijving: 'Boodschappen bij de Jumbo',
      adres: 'Kerkstraat 1, Tiel',
      wanneer_van: '2026-09-20T08:00:00.000Z',
      wanneer_tot: '2026-09-20T09:00:00.000Z',
      status: 'open',
      bedrag_bruto: 1250,
      vergoeding_jongere: 1250,
      commissie: 0,
      bron: 'telefoon',
    })
  })
})

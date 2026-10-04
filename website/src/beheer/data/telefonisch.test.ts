import { describe, expect, it } from 'vitest'
import {
  controleerKlus,
  controleerOudere,
  kanAdresZoeken,
  klusAdresVoor,
  leesAdresAntwoord,
  nieuweOudereBody,
  postcodeOpmaak,
  telefonischEmail,
  telefonischeKlusBody,
  willekeurigWachtwoord,
} from './telefonisch'
import type { AdresSuggestie, Klustype, NieuweKlus, NieuweOudere } from './types'

const kerkstraat: AdresSuggestie = {
  straat: 'Kerkstraat',
  huisnummer: '1',
  toevoeging: '',
  postcode: '4001 MA',
  plaats: 'Tiel',
  gemeente: 'Tiel',
  lat: 51.88761538,
  lon: 5.43597055,
  adres: 'Kerkstraat 1',
  weergave: 'Kerkstraat 1, 4001 MA Tiel',
  binnenWerkgebied: true,
}

// ADRES (4 okt): een telefonische oudere krijgt een PDOK-adres; zonder PDOK
// alleen als uitzondering ("handmatig", met wijk).
const oudere: NieuweOudere = {
  naam: ' Mevrouw Jansen ',
  telefoon: '06-12 34 56 78',
  email: '',
  postcode: '4001 MA',
  huisnummer: '1',
  toevoeging: '',
  gekozen: kerkstraat,
  handmatig: false,
  adres: '',
  plaats: '',
  wijkId: '',
}

const handmatig: NieuweOudere = {
  ...oudere,
  gekozen: null,
  handmatig: true,
  adres: 'Woonwagenkamp 1',
  plaats: 'Tiel',
  postcode: '',
  huisnummer: '',
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
  it('eist naam, telefoon en een gevonden adres', () => {
    expect(controleerOudere(oudere)).toBe('')
    expect(controleerOudere({ ...oudere, naam: ' ' })).not.toBe('')
    expect(controleerOudere({ ...oudere, telefoon: '0612' })).not.toBe('')
    expect(controleerOudere({ ...oudere, gekozen: null })).toMatch(/adres/)
  })

  it('uitzondering handmatig: straat, plaats en wijk verplicht', () => {
    expect(controleerOudere(handmatig)).toBe('')
    expect(controleerOudere({ ...handmatig, adres: '' })).not.toBe('')
    expect(controleerOudere({ ...handmatig, plaats: '' })).not.toBe('')
    expect(controleerOudere({ ...handmatig, wijkId: '' })).not.toBe('')
  })

  it('wordt een hulpvrager met het telefonische adres als er geen e-mail is', () => {
    const body = nieuweOudereBody(oudere, 'geheim-wachtwoord')
    expect(body.rol).toBe('hulpvrager')
    expect(body.email).toBe('0612345678@telefonisch.heitjehulp.invalid')
    expect(body.naam).toBe('Mevrouw Jansen')
    expect(body.password).toBe(body.passwordConfirm)
  })

  it('PDOK-adres: postcode, huisnummer, toevoeging, straat en plaats van PDOK; wijk bepaalt de server', () => {
    const body = nieuweOudereBody(oudere, 'x')
    expect(body).toMatchObject({ postcode: '4001 MA', huisnummer: '1', toevoeging: '', adres: 'Kerkstraat 1', plaats: 'Tiel' })
    expect('wijk' in body).toBe(false)
    expect('adres_bron' in body).toBe(false)
  })

  it('handmatig: adres_bron handmatig en de gekozen wijk', () => {
    expect(nieuweOudereBody(handmatig, 'x')).toMatchObject({
      adres: 'Woonwagenkamp 1',
      plaats: 'Tiel',
      adres_bron: 'handmatig',
      wijk: 'w1',
    })
  })

  it('houdt een echte e-mail aan', () => {
    expect(nieuweOudereBody({ ...oudere, email: 'jansen@example.nl' }, 'x').email).toBe('jansen@example.nl')
  })
})

describe('adres', () => {
  it('postcodeOpmaak: hoofdletters en een spatie, max 4 cijfers + 2 letters', () => {
    expect(postcodeOpmaak('4001ma')).toBe('4001 MA')
    expect(postcodeOpmaak('4001')).toBe('4001')
    expect(postcodeOpmaak('40011mab')).toBe('4001 MA')
  })

  it('klusAdresVoor: zoals de app, zodat de klus het PDOK-punt van de oudere krijgt', () => {
    expect(klusAdresVoor({ adres: 'Kerkstraat 1', postcode: '4001 MA', plaats: 'Tiel' })).toBe('Kerkstraat 1, 4001 MA Tiel')
    expect(klusAdresVoor({ adres: 'Dorpsstraat 2', postcode: '', plaats: 'Tiel' })).toBe('Dorpsstraat 2, Tiel')
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

describe('antwoord van /api/hh/adres', () => {
  const ruw = { straat: 'Kerkstraat', huisnummer: '1', toevoeging: '', postcode: '4001 MA', plaats: 'Tiel', gemeente: 'Tiel', lat: 51.88, lon: 5.43, adres: 'Kerkstraat 1', weergave: 'Kerkstraat 1, 4001 MA Tiel', binnen_werkgebied: true }

  it('gevonden, niet gevonden (met keuzes), dienst, limiet en ongeldig', () => {
    expect(leesAdresAntwoord(200, { gevonden: true, adressen: [ruw] })).toMatchObject({ soort: 'gevonden', adressen: [{ weergave: 'Kerkstraat 1, 4001 MA Tiel', binnenWerkgebied: true }] })
    expect(leesAdresAntwoord(200, { gevonden: false, reden: 'nietgevonden', melding: 'x' })).toEqual({ soort: 'nietgevonden', melding: 'x', keuzes: [] })
    expect(leesAdresAntwoord(200, { gevonden: false, reden: 'toevoeging', melding: 'k', adressen: [ruw] })).toMatchObject({ soort: 'nietgevonden', keuzes: [{ adres: 'Kerkstraat 1' }] })
    expect(leesAdresAntwoord(200, { gevonden: false, reden: 'dienst' })).toEqual({ soort: 'dienst' })
    expect(leesAdresAntwoord(429, { melding: 'later' })).toEqual({ soort: 'limiet', melding: 'later' })
    expect(leesAdresAntwoord(400, { reden: 'postcode', melding: 'Een postcode is ...' })).toEqual({ soort: 'ongeldig', melding: 'Een postcode is ...' })
    expect(leesAdresAntwoord(404, {})).toEqual({ soort: 'dienst' })
  })

  it('kanAdresZoeken: zelfde regels als de server', () => {
    expect(kanAdresZoeken('4001 MA', '1', '')).toBe(true)
    expect(kanAdresZoeken('4001', '1', '')).toBe(false)
    expect(kanAdresZoeken('0401 MA', '1', '')).toBe(false)
    expect(kanAdresZoeken('4001 MA', '0', '')).toBe(false)
    expect(kanAdresZoeken('4001 MA', '1', 'abcdefg')).toBe(false)
  })
})

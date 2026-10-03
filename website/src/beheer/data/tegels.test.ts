import { describe, expect, it } from 'vitest'
import { meldkamerTegels, screeningTegels, vogSignaal } from './tegels'
import type { Incident, Klus, Profiel } from './types'

const NU = new Date('2026-09-19T14:00:00.000Z')

function klus(overschrijf: Partial<Klus>): Klus {
  return {
    id: 'k',
    status: 'open',
    bron: 'app',
    omschrijving: '',
    adres: '',
    aangemaaktOp: '2026-09-19T13:55:00.000Z',
    wanneerVan: '',
    wanneerTot: '',
    hulpvragerId: 'o1',
    hulpvragerNaam: 'Oudere',
    hulpvragerTelefoon: '',
    jongereId: '',
    jongereNaam: '',
    klustypeId: '',
    klustypeNaam: '',
    bedragBruto: 0,
    vergoedingJongere: 0,
    commissie: 0,
    ...overschrijf,
  }
}

function incident(overschrijf: Partial<Incident>): Incident {
  return {
    id: 'i',
    gemeldOp: '2026-09-19T12:00:00.000Z',
    soort: 'probleem',
    omschrijving: '',
    afhandeling: '',
    melderId: 'o1',
    melderNaam: 'Oudere',
    melderTelefoon: '',
    klusId: '',
    ...overschrijf,
  }
}

function profiel(overschrijf: Partial<Profiel>): Profiel {
  return {
    id: 'p',
    gebruikerId: 'j1',
    naam: 'Jongere',
    email: '',
    wijkNaam: '',
    verificatiestatus: 'in_behandeling',
    vogStatus: 'nieuw',
    vogGeldigTot: '',
    vogAangevraagdOp: '',
    vogGezienOp: '',
    ibanGeverifieerd: false,
    iban: '',
    overMij: '',
    screeningNotitie: '',
    bijgewerktOp: '2026-09-19T10:00:00.000Z',
    documentFotoUrl: '',
    ouderToestemmingOp: '',
    ouderAvp: null,
    ouderStatus: '',
    ...overschrijf,
  }
}

describe('meldkamerTegels', () => {
  it('telt open hulpvragen', () => {
    const tegels = meldkamerTegels(
      [klus({ id: 'a', status: 'open' }), klus({ id: 'b', status: 'afgerond' })],
      [],
      NU,
    )

    expect(tegels.open).toBe(1)
  })

  it('telt een open klus pas als zonder match zodra hij ouder is dan twee uur', () => {
    const netGeplaatst = klus({ id: 'a', aangemaaktOp: '2026-09-19T12:30:00.000Z' })
    const preciesTweeUur = klus({ id: 'b', aangemaaktOp: '2026-09-19T12:00:00.000Z' })
    const ruimOuder = klus({ id: 'c', aangemaaktOp: '2026-09-19T09:00:00.000Z' })

    const tegels = meldkamerTegels([netGeplaatst, preciesTweeUur, ruimOuder], [], NU)

    expect(tegels.zonderMatch).toBe(1)
  })

  it('telt een oude klus die al gematcht is niet als zonder match', () => {
    const tegels = meldkamerTegels(
      [klus({ status: 'geaccepteerd', aangemaaktOp: '2026-09-18T09:00:00.000Z' })],
      [],
      NU,
    )

    expect(tegels.zonderMatch).toBe(0)
  })

  it('telt vandaag gepland op de kalenderdag van wanneer_van', () => {
    const vandaag = klus({ id: 'a', status: 'geaccepteerd', wanneerVan: '2026-09-19T08:00:00.000Z' })
    const morgen = klus({ id: 'b', status: 'geaccepteerd', wanneerVan: '2026-09-20T08:00:00.000Z' })
    const vandaagMaarAfgerond = klus({
      id: 'c',
      status: 'afgerond',
      wanneerVan: '2026-09-19T08:00:00.000Z',
    })

    const tegels = meldkamerTegels([vandaag, morgen, vandaagMaarAfgerond], [], NU)

    expect(tegels.vandaagGepland).toBe(1)
  })

  it('telt nu bezig', () => {
    const tegels = meldkamerTegels([klus({ status: 'bezig' })], [], NU)

    expect(tegels.nuBezig).toBe(1)
  })

  it('telt alleen incidenten zonder afhandeling als open', () => {
    const tegels = meldkamerTegels(
      [],
      [incident({ id: 'a', afhandeling: '' }), incident({ id: 'b', afhandeling: 'Gebeld.' })],
      NU,
    )

    expect(tegels.incidentenOpen).toBe(1)
  })
})

describe('screeningTegels', () => {
  it('telt wachtend, VOG loopt en afgewezen deze maand', () => {
    const tegels = screeningTegels(
      [
        profiel({ id: 'a', verificatiestatus: 'in_behandeling' }),
        profiel({ id: 'b', verificatiestatus: 'goedgekeurd', vogStatus: 'in_behandeling' }),
        profiel({
          id: 'c',
          verificatiestatus: 'afgewezen',
          bijgewerktOp: '2026-09-02T10:00:00.000Z',
        }),
        profiel({
          id: 'd',
          verificatiestatus: 'afgewezen',
          bijgewerktOp: '2026-08-28T10:00:00.000Z',
        }),
      ],
      NU,
    )

    expect(tegels.wachtend).toBe(1)
    expect(tegels.vogLoopt).toBe(1)
    expect(tegels.afgewezenDezeMaand).toBe(1)
  })
})

describe('vogSignaal', () => {
  it('geeft niets terug zonder datum', () => {
    expect(vogSignaal('', NU)).toBe('')
  })

  it('geeft niets terug als de VOG nog ruim geldig is', () => {
    expect(vogSignaal('2027-01-01', NU)).toBe('')
  })

  it('waarschuwt binnen zestig dagen', () => {
    expect(vogSignaal('2026-10-20', NU)).toBe('binnenkort')
  })

  it('meldt een verlopen VOG apart', () => {
    expect(vogSignaal('2026-09-18', NU)).toBe('verlopen')
  })
})

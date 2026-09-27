import { describe, expect, it } from 'vitest'
import {
  filterAuditlog,
  filterIncidenten,
  filterKlussen,
  hulpvraagGroep,
  sorteerIncidenten,
  sorteerKoppelkandidaten,
} from './filters'
import type { Auditregel, Incident, Klus, Koppelkandidaat } from './types'

function klus(id: string, status: Klus['status']): Klus {
  return {
    id,
    status,
    bron: 'app',
    omschrijving: '',
    adres: '',
    aangemaaktOp: '2026-09-19T10:00:00.000Z',
    wanneerVan: '',
    wanneerTot: '',
    hulpvragerId: '',
    hulpvragerNaam: '',
    hulpvragerTelefoon: '',
    jongereId: '',
    jongereNaam: '',
    klustypeId: '',
    klustypeNaam: '',
    bedragBruto: 0,
    vergoedingJongere: 0,
    commissie: 0,
  }
}

function incident(id: string, gemeldOp: string, afhandeling: string): Incident {
  return {
    id,
    gemeldOp,
    soort: 'probleem',
    omschrijving: '',
    afhandeling,
    melderId: '',
    melderNaam: '',
    melderTelefoon: '',
    klusId: '',
  }
}

describe('hulpvraagGroep', () => {
  it('deelt de acht statussen in vier groepen in', () => {
    expect(hulpvraagGroep('concept')).toBe('nieuw')
    expect(hulpvraagGroep('open')).toBe('nieuw')
    expect(hulpvraagGroep('geaccepteerd')).toBe('gematcht')
    expect(hulpvraagGroep('onderweg')).toBe('in_uitvoering')
    expect(hulpvraagGroep('bezig')).toBe('in_uitvoering')
    expect(hulpvraagGroep('afgerond')).toBe('afgerond')
    expect(hulpvraagGroep('geannuleerd')).toBe('afgerond')
    expect(hulpvraagGroep('probleem')).toBe('afgerond')
  })
})

describe('filterKlussen', () => {
  const klussen = [
    klus('a', 'open'),
    klus('b', 'geaccepteerd'),
    klus('c', 'bezig'),
    klus('d', 'afgerond'),
    klus('e', 'geannuleerd'),
  ]

  it('geeft alles terug bij het filter alle', () => {
    expect(filterKlussen(klussen, 'alle')).toHaveLength(5)
  })

  it('filtert op groep', () => {
    expect(filterKlussen(klussen, 'nieuw').map((k) => k.id)).toEqual(['a'])
    expect(filterKlussen(klussen, 'gematcht').map((k) => k.id)).toEqual(['b'])
    expect(filterKlussen(klussen, 'in_uitvoering').map((k) => k.id)).toEqual(['c'])
    expect(filterKlussen(klussen, 'afgerond').map((k) => k.id)).toEqual(['d', 'e'])
  })
})

describe('sorteerIncidenten', () => {
  it('zet het nieuwste incident bovenaan', () => {
    const gesorteerd = sorteerIncidenten([
      incident('oud', '2026-09-18T09:00:00.000Z', ''),
      incident('nieuw', '2026-09-19T09:00:00.000Z', ''),
    ])

    expect(gesorteerd.map((i) => i.id)).toEqual(['nieuw', 'oud'])
  })

  it('laat de meegegeven lijst ongemoeid', () => {
    const origineel = [
      incident('oud', '2026-09-18T09:00:00.000Z', ''),
      incident('nieuw', '2026-09-19T09:00:00.000Z', ''),
    ]
    sorteerIncidenten(origineel)

    expect(origineel.map((i) => i.id)).toEqual(['oud', 'nieuw'])
  })
})

describe('filterIncidenten', () => {
  const lijst = [
    incident('open', '2026-09-19T09:00:00.000Z', ''),
    incident('klaar', '2026-09-19T08:00:00.000Z', 'Gebeld met de oudere.'),
  ]

  it('toont open incidenten', () => {
    expect(filterIncidenten(lijst, 'open').map((i) => i.id)).toEqual(['open'])
  })

  it('toont afgehandelde incidenten', () => {
    expect(filterIncidenten(lijst, 'afgehandeld').map((i) => i.id)).toEqual(['klaar'])
  })

  it('toont alles', () => {
    expect(filterIncidenten(lijst, 'alle')).toHaveLength(2)
  })
})

describe('sorteerKoppelkandidaten', () => {
  it('zet jongeren uit dezelfde wijk vooraan en sorteert daarbinnen op naam', () => {
    const kandidaten: Koppelkandidaat[] = [
      { id: '1', naam: 'Zoe', wijkNaam: 'Tiel-West', klussenAantal: 3 },
      { id: '2', naam: 'Aziz', wijkNaam: 'Passewaaij', klussenAantal: 9 },
      { id: '3', naam: 'Bram', wijkNaam: 'Tiel-West', klussenAantal: 1 },
    ]

    expect(sorteerKoppelkandidaten(kandidaten, 'Tiel-West').map((k) => k.naam)).toEqual([
      'Bram',
      'Zoe',
      'Aziz',
    ])
  })
})

describe('filterAuditlog', () => {
  const regels: Auditregel[] = [
    {
      id: '1',
      gebeurdOp: '2026-09-19T09:00:00.000Z',
      doorId: 'c1',
      doorNaam: 'Coordinator Een',
      actie: 'aanmaken',
      doelCollectie: 'hh_wijken',
      doelId: 'w1',
      detail: '',
    },
    {
      id: '2',
      gebeurdOp: '2026-09-19T10:00:00.000Z',
      doorId: 'c2',
      doorNaam: 'Coordinator Twee',
      actie: 'wijzigen',
      doelCollectie: 'hh_users',
      doelId: 'u1',
      detail: '',
    },
  ]

  it('filtert op actie', () => {
    expect(filterAuditlog(regels, { actie: 'wijzigen', persoon: '' }).map((r) => r.id)).toEqual(['2'])
  })

  it('filtert op persoon, ongeacht hoofdletters', () => {
    expect(filterAuditlog(regels, { actie: '', persoon: 'coordinator een' }).map((r) => r.id)).toEqual([
      '1',
    ])
  })

  it('geeft alles terug zonder filter', () => {
    expect(filterAuditlog(regels, { actie: '', persoon: '' })).toHaveLength(2)
  })
})

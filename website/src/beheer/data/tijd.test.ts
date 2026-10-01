import { describe, expect, it } from 'vitest'
import { naarIso, nlDag, nlTijdNaarIso, toonBedrag } from './tijd'

describe('tijd', () => {
  it('maakt van een PocketBase-datum ISO 8601', () => {
    expect(naarIso('2026-09-19 12:00:00.000Z')).toBe('2026-09-19T12:00:00.000Z')
    expect(naarIso('')).toBe('')
  })

  it('rekent met de Nederlandse kalenderdag', () => {
    expect(nlDag('2026-09-19T22:30:00.000Z')).toBe('2026-09-20')
    expect(nlDag('2026-12-19T22:30:00.000Z')).toBe('2026-12-19')
  })

  it('zet Nederlandse tijd om naar UTC, in zomer- en wintertijd', () => {
    expect(nlTijdNaarIso('2026-09-20', '10:00')).toBe('2026-09-20T08:00:00.000Z')
    expect(nlTijdNaarIso('2026-12-20', '10:00')).toBe('2026-12-20T09:00:00.000Z')
    expect(nlTijdNaarIso('', '10:00')).toBe('')
  })

  it('toont centen als euro', () => {
    expect(toonBedrag(1250).replace(/\s/g, ' ')).toBe('€ 12,50')
  })
})

import { describe, expect, it } from 'vitest'
import { isBeheerHash, leesLocatie, schrijfLocatie } from './navigatie'

describe('isBeheerHash', () => {
  it('herkent het beheerpad', () => {
    expect(isBeheerHash('#/beheer')).toBe(true)
    expect(isBeheerHash('#/beheer/screening')).toBe(true)
    expect(isBeheerHash('#/beheer/systeem?tab=wijken')).toBe(true)
  })

  it('laat de rest van de site met rust', () => {
    expect(isBeheerHash('')).toBe(false)
    expect(isBeheerHash('#/')).toBe(false)
    expect(isBeheerHash('#over-ons')).toBe(false)
    expect(isBeheerHash('#/beheerder')).toBe(false)
  })
})

describe('leesLocatie', () => {
  it('valt terug op de meldkamer', () => {
    expect(leesLocatie('#/beheer')).toEqual({ onderdeel: 'meldkamer', filters: {} })
  })

  it('leest het onderdeel', () => {
    expect(leesLocatie('#/beheer/screening').onderdeel).toBe('screening')
    expect(leesLocatie('#/beheer/systeem').onderdeel).toBe('systeem')
  })

  it('valt bij een onbekend onderdeel terug op de meldkamer', () => {
    expect(leesLocatie('#/beheer/onzin').onderdeel).toBe('meldkamer')
  })

  it('leest de filters uit de zoekparameters', () => {
    expect(leesLocatie('#/beheer/meldkamer?filter=nieuw&zoek=jan').filters).toEqual({
      filter: 'nieuw',
      zoek: 'jan',
    })
  })
})

describe('schrijfLocatie', () => {
  it('schrijft een onderdeel zonder filters', () => {
    expect(schrijfLocatie({ onderdeel: 'screening', filters: {} })).toBe('#/beheer/screening')
  })

  it('schrijft filters in de zoekparameters en laat lege filters weg', () => {
    expect(
      schrijfLocatie({ onderdeel: 'meldkamer', filters: { filter: 'nieuw', zoek: '' } }),
    ).toBe('#/beheer/meldkamer?filter=nieuw')
  })

  it('is heen en terug hetzelfde', () => {
    const hash = schrijfLocatie({ onderdeel: 'systeem', filters: { tab: 'gebruikers' } })

    expect(leesLocatie(hash)).toEqual({ onderdeel: 'systeem', filters: { tab: 'gebruikers' } })
  })
})

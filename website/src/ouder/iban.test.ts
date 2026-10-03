import { describe, expect, it } from 'vitest'
import { isGeldigNlIban, normaliseerIban, toonIban } from './iban'

describe('IBAN (zoals de server en de app)', () => {
  it('accepteert een geldige NL-IBAN met spaties en kleine letters', () => {
    expect(isGeldigNlIban('NL91 ABNA 0417 1643 00')).toBe(true)
    expect(isGeldigNlIban('nl91abna0417164300')).toBe(true)
  })

  it('weigert een foute controle, een buitenlandse of te korte IBAN', () => {
    for (const fout of ['', 'NL91ABNA0417164301', 'DE89370400440532013000', 'NL91ABNA041716430']) {
      expect(isGeldigNlIban(fout)).toBe(false)
    }
  })

  it('maakt schoon en toont in groepjes van vier', () => {
    expect(normaliseerIban(' nl91 abna 0417 1643 00 ')).toBe('NL91ABNA0417164300')
    expect(toonIban('NL91ABNA0417164300')).toBe('NL91 ABNA 0417 1643 00')
  })
})

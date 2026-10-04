import { describe, expect, it } from 'vitest'
import { isOuderHash, leesToken } from '../navigatie'
import { isOuderKlusHash, leesKlusToken } from './navigatieKlus'

const TOKEN = 'G5s0s47LuoHEw524DgsuMibNsouvG0vH4sw7SZmY'

describe('B5 navigatie #/ouder/klus', () => {
  it('herkent de klus-link, en de ouder-ingang blijft hem ook laden', () => {
    expect(isOuderKlusHash(`#/ouder/klus?token=${TOKEN}`)).toBe(true)
    expect(isOuderKlusHash('#/ouder/klus')).toBe(true)
    expect(isOuderKlusHash('#/ouder?t=abc')).toBe(false)
    expect(isOuderKlusHash('#/ouder/klussen')).toBe(false)
    expect(isOuderHash(`#/ouder/klus?token=${TOKEN}`)).toBe(true)
  })

  it('leest alleen een nette token (letters en cijfers, 20-100 tekens)', () => {
    expect(leesKlusToken(`#/ouder/klus?token=${TOKEN}`)).toBe(TOKEN)
    expect(leesKlusToken('#/ouder/klus?token=kort')).toBe('')
    expect(leesKlusToken(`#/ouder/klus?token=${TOKEN}<script>`)).toBe('')
    expect(leesKlusToken(`#/ouder?token=${TOKEN}`)).toBe('')
  })

  it('de B3-token (?t=) komt nooit uit een klus-link', () => {
    expect(leesToken(`#/ouder/klus?token=${TOKEN}`)).toBe('')
  })
})

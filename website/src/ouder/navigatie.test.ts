import { describe, expect, it } from 'vitest'
import { isOuderHash, leesToken } from './navigatie'

describe('ouder-navigatie', () => {
  it('herkent #/ouder met en zonder token', () => {
    expect(isOuderHash('#/ouder')).toBe(true)
    expect(isOuderHash('#/ouder?t=abc')).toBe(true)
    expect(isOuderHash('#/ouderdom')).toBe(false)
    expect(isOuderHash('#/beheer')).toBe(false)
    expect(isOuderHash('')).toBe(false)
  })

  it('leest de token uit de hash (alleen letters en cijfers)', () => {
    expect(leesToken('#/ouder?t=AbC123')).toBe('AbC123')
    expect(leesToken('#/ouder')).toBe('')
    expect(leesToken('#/ouder?t=<script>')).toBe('')
  })
})

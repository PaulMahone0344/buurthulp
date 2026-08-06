import { describe, expect, it } from 'vitest'
import { authenticateDemoUser, roleHomeViews, roleLabels } from './auth'

describe('authenticateDemoUser', () => {
  it('logs an admin into the admin panel with the expected role label', () => {
    const session = authenticateDemoUser({
      email: 'admin@buurthulp.local',
      password: 'buurthulp-admin',
      role: 'admin',
    })

    expect(session.ok).toBe(true)

    if (!session.ok) {
      throw new Error('Expected a successful admin session')
    }

    expect(session.user.role).toBe('admin')
    expect(session.user.name).toBe('Gemeente Admin')
    expect(roleLabels[session.user.role]).toBe('Admin')
    expect(roleHomeViews[session.user.role]).toBe('admin')
  })

  it('rejects a valid account when the selected role does not match', () => {
    const session = authenticateDemoUser({
      email: 'admin@buurthulp.local',
      password: 'buurthulp-admin',
      role: 'helper',
    })

    expect(session).toEqual({
      ok: false,
      message: 'Dit account hoort bij een andere rol.',
    })
  })

  it('rejects an invalid password without exposing account details', () => {
    const session = authenticateDemoUser({
      email: 'jongere@buurthulp.local',
      password: 'verkeerd',
      role: 'helper',
    })

    expect(session).toEqual({
      ok: false,
      message: 'Controleer je e-mail en wachtwoord.',
    })
  })
})

import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it } from 'vitest'
import { BeheerApp } from './BeheerApp'
import { FakeBeheerData } from './data/fakeBeheerData'
import { COORDINATOR, NU } from './testdata'

const accounts = [
  { id: 'c1', email: 'coord@heitjehulp.nl', wachtwoord: 'goed', rol: 'coordinator' as const, naam: 'Coordinator Een' },
  { id: 'j1', email: 'jongere@heitjehulp.nl', wachtwoord: 'goed', rol: 'jongere' as const, naam: 'Sami' },
  { id: 'o1', email: 'oudere@heitjehulp.nl', wachtwoord: 'goed', rol: 'hulpvrager' as const, naam: 'Jansen' },
  { id: 'f1', email: 'familie@heitjehulp.nl', wachtwoord: 'goed', rol: 'familie' as const, naam: 'Kind' },
  { id: 'c2', email: 'blok@heitjehulp.nl', wachtwoord: 'goed', rol: 'coordinator' as const, naam: 'Blok', geblokkeerd: true },
]

async function logIn(email: string) {
  const user = userEvent.setup()
  await user.type(screen.getByLabelText('E-mail'), email)
  await user.type(screen.getByLabelText('Wachtwoord'), 'goed')
  await user.click(screen.getByRole('button', { name: 'Inloggen' }))
}

beforeEach(() => {
  window.location.hash = '#/beheer'
})

describe('toegang tot het beheerpaneel', () => {
  it('laat een coordinator binnen op de meldkamer', async () => {
    render(<BeheerApp data={new FakeBeheerData({ accounts })} nu={() => NU} />)
    await logIn('coord@heitjehulp.nl')

    expect(await screen.findByRole('heading', { name: 'Meldkamer' })).toBeInTheDocument()
  })

  it.each(['jongere@heitjehulp.nl', 'oudere@heitjehulp.nl', 'familie@heitjehulp.nl'])(
    'weigert %s netjes en toont niets van het paneel',
    async (email) => {
      const data = new FakeBeheerData({ accounts })
      render(<BeheerApp data={data} nu={() => NU} />)
      await logIn(email)

      expect(await screen.findByRole('alert')).toHaveTextContent('alleen voor coordinatoren')
      expect(screen.queryByRole('heading', { name: 'Meldkamer' })).not.toBeInTheDocument()
      expect(data.huidige()).toBeNull()
    },
  )

  it('toont de blokkeermelding', async () => {
    render(<BeheerApp data={new FakeBeheerData({ accounts })} nu={() => NU} />)
    await logIn('blok@heitjehulp.nl')

    expect(await screen.findByRole('alert')).toHaveTextContent('geblokkeerd')
  })

  it('navigeert via de URL en logt uit', async () => {
    const user = userEvent.setup()
    render(<BeheerApp data={new FakeBeheerData({}, COORDINATOR)} nu={() => NU} />)
    const nav = screen.getByRole('navigation', { name: 'Beheer navigatie' })

    await user.click(within(nav).getByRole('link', { name: 'Screening' }))
    expect(window.location.hash).toBe('#/beheer/screening')
    expect(await screen.findByRole('heading', { name: 'Screening', level: 1 })).toBeInTheDocument()

    await user.click(within(nav).getByRole('link', { name: 'Systeembeheer' }))
    expect(window.location.hash).toBe('#/beheer/systeem')

    await user.click(screen.getByRole('button', { name: 'Uitloggen' }))
    expect(screen.getByRole('button', { name: 'Inloggen' })).toBeInTheDocument()
  })

  it('opent op het onderdeel uit de URL', async () => {
    window.location.hash = '#/beheer/systeem?tab=klustypes'
    render(<BeheerApp data={new FakeBeheerData({}, COORDINATOR)} nu={() => NU} />)

    expect(await screen.findByRole('heading', { name: 'Klustypes' })).toBeInTheDocument()
  })
})

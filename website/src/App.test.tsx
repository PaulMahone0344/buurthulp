import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import App from './App'

describe('BuurtHulp role login flow', () => {
  it('lets an admin log in and see the admin panel', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: 'Inloggen' }))
    await user.click(screen.getByRole('radio', { name: 'Admin' }))
    await user.clear(screen.getByLabelText('E-mail'))
    await user.type(screen.getByLabelText('E-mail'), 'admin@buurthulp.local')
    await user.clear(screen.getByLabelText('Wachtwoord'))
    await user.type(screen.getByLabelText('Wachtwoord'), 'buurthulp-admin')
    await user.click(screen.getByRole('button', { name: 'Inloggen als Admin' }))

    expect(
      await screen.findByRole('heading', { name: 'Admin panel' }),
    ).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'Hulpvragen' })).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'Jongeren screening' })).toBeInTheDocument()
  })
})

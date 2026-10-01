import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'
import App from './App'

afterEach(() => {
  window.location.hash = ''
})

describe('HeitjeHulp voorpagina', () => {
  it('toont de one-pager met alle secties', () => {
    render(<App />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('eigen wijk')
    const nav = screen.getByRole('navigation', { name: 'Hoofdnavigatie' })
    for (const label of ['Werkwijze', 'Voor wie', 'Veiligheid', 'Vooraf geregeld', 'De proef', 'Vragen']) {
      expect(within(nav).getByRole('link', { name: label })).toBeInTheDocument()
    }
    for (const kop of [
      /tussen wal en schip/,
      /vier stappen/,
      /Wat wij wel en niet doen/,
      /Eén platform, vier rollen/,
      /Vertrouwen is de hoofdvoorwaarde/,
      /Klein beginnen/,
      /Veelgestelde vragen/,
    ]) {
      expect(screen.getByRole('heading', { name: kop })).toBeInTheDocument()
    }
  })

  it('laat geen interne cijfers, verdienmodel of concurrenten zien', () => {
    const { container } = render(<App />)
    const tekst = container.textContent ?? ''

    expect(tekst).not.toMatch(/€/)
    expect(tekst).not.toMatch(/begroting|commissie|cofinanciering|te financieren|subsidie/i)
    expect(tekst).not.toMatch(/BUUV|WeHelpen|Helpling|Charly Cares|Aon/)
  })

  it('heeft geen demo-portaal of demo-login meer', () => {
    render(<App />)

    expect(screen.queryByRole('button', { name: /Inloggen|Open portaal/ })).not.toBeInTheDocument()
  })

  it('opent de vragen in de FAQ', async () => {
    const user = userEvent.setup()
    render(<App />)

    const vraag = screen.getByText('Wie zijn de jongeren?')
    await user.click(vraag)
    expect(vraag.closest('details')).toHaveAttribute('open')
  })

  it('toont op #/beheer het beheerpaneel', async () => {
    window.location.hash = '#/beheer'
    render(<App />)

    expect(await screen.findByRole('heading', { name: /Inloggen voor de meldkamer/ })).toBeInTheDocument()
  })
})

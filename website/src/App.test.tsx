import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'
import App from './App'
import indexHtml from '../index.html?raw'

afterEach(() => {
  window.location.hash = ''
})

// Woorden en cijfers uit het oude verhaal (stichting met jongeren 16-20 voor
// ouderen, pilot met een welzijnspartner) die niet meer op de site mogen staan.
const OUD_VERHAAL =
  /stichting|vrijwilliger|3,40|16 t\/m 20|16-20|Moza[iï]ek|per uur|sociaal tarief|pilot|gemeente|ouderen/i

describe('HeitjeHulp voorpagina', () => {
  it('toont de naam met de slogan in de hero', () => {
    render(<App />)

    const hero = screen.getByRole('region', { name: 'Introductie' })
    expect(within(hero).getByText('HeitjeHulp')).toBeInTheDocument()
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Heitje voor een karweitje, in jouw buurt.')
  })

  it('toont de one-pager met alle secties', () => {
    render(<App />)

    const nav = screen.getByRole('navigation', { name: 'Hoofdnavigatie' })
    for (const label of ['Zo werkt het', 'Voor wie', 'Helpers', 'Veiligheid', 'Partners', 'Vragen']) {
      expect(within(nav).getByRole('link', { name: label })).toBeInTheDocument()
    }
    for (const kop of [
      /Een klein klusje, iemand uit de buurt/,
      /in vier stappen/,
      /Wat kan er/,
      /Bewoners, helpers, ouders en de meldkamer/,
      /Wij bemiddelen. Wij zijn geen werkgever/,
      /Help je buurt en verdien je zakgeld/,
      /Zakgeld, XP, badges en niveaus/,
      /Veilig helpen en geholpen worden/,
      /Samen met het jongerenwerk/,
      /Veelgestelde vragen/,
    ]) {
      expect(screen.getByRole('heading', { name: kop })).toBeInTheDocument()
    }
  })

  it('vertelt het nieuwe verhaal: bemiddelaar, helpers vanaf 10, ouder-toestemming, VOG vanaf 18', () => {
    const { container } = render(<App />)
    const tekst = container.textContent ?? ''

    expect(tekst).toMatch(/geen werkgever/)
    expect(tekst).toMatch(/vanaf 10 jaar/i)
    expect(tekst).toMatch(/code per e-mail of sms/)
    expect(tekst).toMatch(/VOG/)
    expect(tekst).toMatch(/meldkamer/i)
    expect(tekst).toMatch(/nummers? blijv(t|en) verborgen/i)
    expect(tekst).toMatch(/foto/)
    expect(tekst).toMatch(/iDEAL/)
  })

  it('heeft een partners-sectie met een oproep om partner te worden', () => {
    render(<App />)

    const partners = screen.getByRole('region', { name: /Samen met het jongerenwerk/ })
    expect(within(partners).getByRole('heading', { name: 'Word partner' })).toBeInTheDocument()
    expect(within(partners).getByRole('link', { name: /info@heitjehulp\.nl/ })).toHaveAttribute(
      'href',
      expect.stringContaining('mailto:info@heitjehulp.nl'),
    )
  })

  it('bevat niets meer van het oude stichting- en pilotverhaal', () => {
    const { container } = render(<App />)
    const tekst = container.textContent ?? ''

    expect(tekst).not.toMatch(OUD_VERHAAL)
  })

  it('heeft ook in de paginatitel en omschrijving het nieuwe verhaal', () => {
    const html = indexHtml

    expect(html).toMatch(/heitje voor een karweitje, in jouw buurt/i)
    expect(html).not.toMatch(OUD_VERHAAL)
  })

  it('laat geen prijzen, interne cijfers, verdienmodel of concurrenten zien', () => {
    const { container } = render(<App />)
    const tekst = container.textContent ?? ''

    expect(tekst).not.toMatch(/€|euro/i)
    expect(tekst).not.toMatch(/begroting|commissie|cofinanciering|te financieren|subsidie/i)
    expect(tekst).not.toMatch(/BuurtHeld|BUUV|WeHelpen|Helpling|Charly Cares|Aon/)
  })

  it('heeft geen demo-portaal of demo-login meer', () => {
    render(<App />)

    expect(screen.queryByRole('button', { name: /Inloggen|Open portaal/ })).not.toBeInTheDocument()
  })

  it('wisselt de tabbladen bij Goed om te weten', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('tab', { name: 'VOG' }))
    expect(screen.getByRole('tab', { name: 'VOG' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tabpanel')).toHaveTextContent('VOG voor helpers vanaf 18 jaar')
  })

  it('opent de vragen in de FAQ', async () => {
    const user = userEvent.setup()
    render(<App />)

    const vraag = screen.getByText('Is HeitjeHulp de werkgever van de helpers?')
    await user.click(vraag)
    expect(vraag.closest('details')).toHaveAttribute('open')
  })

  it('toont op #/beheer het beheerpaneel', async () => {
    window.location.hash = '#/beheer'
    render(<App />)

    expect(await screen.findByRole('heading', { name: /Inloggen voor de meldkamer/ })).toBeInTheDocument()
  })

describe('B3 ouder-pagina', () => {
  it('#/ouder opent de ouder-pagina (stap 1) en niet de voorpagina', async () => {
    window.location.hash = '#/ouder'
    render(<App />)
    expect(await screen.findByRole('heading', { level: 1, name: 'Je kind wil helper worden bij HeitjeHulp' })).toBeInTheDocument()
    expect(screen.queryByRole('navigation', { name: 'Hoofdnavigatie' })).not.toBeInTheDocument()
  })
})
})

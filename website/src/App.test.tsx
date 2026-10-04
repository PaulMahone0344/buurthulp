import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'
import App from './App'
import indexHtml from '../index.html?raw'

afterEach(() => {
  window.location.hash = ''
  window.history.pushState(null, '', '/')
})

// De site heeft echte pagina's: zet het adres en toon de app.
function toonPagina(pad: string) {
  window.history.pushState(null, '', pad)
  return render(<App />)
}

const PAGINAS = [
  { pad: '/', kop: /^heitje voor een karweitje, in jouw buurt\.$/i },
  { pad: '/zo-werkt-het', kop: /in vier stappen/ },
  { pad: '/voor-wie', kop: /Bewoners, helpers, ouders en de meldkamer/ },
  { pad: '/helpers', kop: /Help je buurt en verdien je zakgeld/ },
  { pad: '/veiligheid', kop: /Veilig helpen en geholpen worden/ },
  { pad: '/partners', kop: /Samen met het jongerenwerk/ },
  { pad: '/vragen', kop: /Veelgestelde vragen/ },
]

// Alle tekst van alle pagina's achter elkaar, voor de inhoudsbewakers.
function alleTekst(): string {
  return PAGINAS.map(({ pad }) => {
    const { container, unmount } = toonPagina(pad)
    const tekst = container.textContent ?? ''
    unmount()
    return tekst
  }).join('\n')
}

// Woorden en cijfers uit het oude verhaal (stichting met jongeren 16-20 voor
// ouderen, pilot met een welzijnspartner) die niet meer op de site mogen staan.
const OUD_VERHAAL =
  /stichting|vrijwilliger|3,40|16 t\/m 20|16-20|Moza[iï]ek|per uur|sociaal tarief|pilot|gemeente|ouderen/i

describe('HeitjeHulp voorpagina', () => {
  it('toont de naam met de slogan in de hero', () => {
    toonPagina('/')

    expect(within(screen.getByRole('banner')).getByRole('link', { name: 'HeitjeHulp home' })).toBeInTheDocument()
    const hero = screen.getByRole('region', { name: 'Introductie' })
    expect(within(hero).getByRole('heading', { level: 1 })).toHaveTextContent(
      /^heitje voor een karweitje, in jouw buurt\.$/i,
    )
  })

  it('houdt de voorpagina kort: de rest staat op eigen pagina\'s', () => {
    toonPagina('/')

    for (const kop of [/Een klein klusje, iemand uit de buurt/, /Wat kan er/, /Voor de buurt/, /Meedoen of meer weten/]) {
      expect(screen.getByRole('heading', { name: kop })).toBeInTheDocument()
    }
    for (const kop of [/in vier stappen/, /Veelgestelde vragen/, /Samen met het jongerenwerk/]) {
      expect(screen.queryByRole('heading', { name: kop })).not.toBeInTheDocument()
    }
  })

  it.each(PAGINAS)('toont op $pad een eigen pagina met één hoofdkop', ({ pad, kop }) => {
    toonPagina(pad)

    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1)
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(kop)
    expect(screen.getByRole('heading', { name: /Meedoen of meer weten/ })).toBeInTheDocument()
  })

  it('gaat met elke link in het hoofdmenu naar de eigen pagina', async () => {
    const user = userEvent.setup()
    toonPagina('/')
    const nav = screen.getByRole('navigation', { name: 'Hoofdnavigatie' })

    for (const [label, pad, kop] of [
      ['Zo werkt het', '/zo-werkt-het', /in vier stappen/],
      ['Voor wie', '/voor-wie', /Bewoners, helpers, ouders en de meldkamer/],
      ['Helpers', '/helpers', /Help je buurt en verdien je zakgeld/],
      ['Veiligheid', '/veiligheid', /Veilig helpen en geholpen worden/],
      ['Partners', '/partners', /Samen met het jongerenwerk/],
      ['Vragen', '/vragen', /Veelgestelde vragen/],
    ] as const) {
      const link = within(nav).getByRole('link', { name: label })
      await user.click(link)

      expect(window.location.pathname).toBe(pad)
      expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(kop)
      expect(link).toHaveAttribute('aria-current', 'page')
    }
  })

  it('gaat met het logo terug naar de voorpagina en met de terugknop naar de vorige pagina', async () => {
    const user = userEvent.setup()
    toonPagina('/helpers')

    await user.click(within(screen.getByRole('banner')).getByRole('link', { name: 'HeitjeHulp home' }))
    expect(window.location.pathname).toBe('/')
    expect(screen.getByRole('region', { name: 'Introductie' })).toBeInTheDocument()

    window.history.pushState(null, '', '/vragen')
    fireEvent.popState(window)
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/Veelgestelde vragen/)
  })

  it('zet de paginatitel bij elke pagina', () => {
    toonPagina('/helpers')
    expect(document.title).toBe('Helpers — HeitjeHulp')
  })

  it('toont een nette melding bij een adres dat niet bestaat', () => {
    toonPagina('/bestaat-niet')

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/Deze pagina bestaat niet/)
    expect(within(screen.getByRole('main')).getByRole('link', { name: /Naar de voorpagina/ })).toHaveAttribute('href', '/')
  })

  it('heeft knoppen Inloggen en Aanmelden die naar de webapp gaan', () => {
    toonPagina('/')
    const kop = screen.getByRole('banner')

    expect(within(kop).getByRole('link', { name: 'Inloggen' })).toHaveAttribute(
      'href',
      'https://heitjehulp.app/#/inloggen',
    )
    expect(within(kop).getByRole('link', { name: 'Aanmelden' })).toHaveAttribute(
      'href',
      'https://heitjehulp.app/#/registreren',
    )
  })

  // TIJDELIJK: hoort bij TijdelijkBeheerKnop.tsx, gaat samen met die knop weg.
  it('heeft tijdelijk een knop naar de meldkamer', () => {
    toonPagina('/helpers')

    expect(screen.getByRole('link', { name: /Meldkamer/ })).toHaveAttribute('href', '/#/beheer')
  })

  it('opent en sluit het menu met de menuknop', async () => {
    const user = userEvent.setup()
    toonPagina('/')

    const knop = screen.getByRole('button', { name: 'Menu' })
    expect(knop).toHaveAttribute('aria-expanded', 'false')
    expect(screen.queryByRole('navigation', { name: 'Menu' })).not.toBeInTheDocument()

    await user.click(knop)
    const menu = screen.getByRole('navigation', { name: 'Menu' })
    expect(knop).toHaveAttribute('aria-expanded', 'true')
    for (const label of ['Zo werkt het', 'Voor wie', 'Helpers', 'Veiligheid', 'Partners', 'Vragen', 'Inloggen', 'Aanmelden']) {
      expect(within(menu).getByRole('link', { name: label })).toBeInTheDocument()
    }

    await user.click(knop)
    expect(screen.queryByRole('navigation', { name: 'Menu' })).not.toBeInTheDocument()
  })

  it('houdt het menu open bij een klik precies op het icoon in de knop', async () => {
    const user = userEvent.setup()
    const { container } = toonPagina('/')

    const icoon = container.querySelector('.lp-menuknop svg')
    expect(icoon).not.toBeNull()
    await user.click(icoon as Element)

    expect(screen.getByRole('navigation', { name: 'Menu' })).toBeInTheDocument()
  })

  it('sluit het menu met Escape, met een klik ernaast en na het kiezen van een link', async () => {
    const user = userEvent.setup()
    toonPagina('/')
    const knop = screen.getByRole('button', { name: 'Menu' })

    await user.click(knop)
    await user.keyboard('{Escape}')
    expect(screen.queryByRole('navigation', { name: 'Menu' })).not.toBeInTheDocument()
    expect(knop).toHaveFocus()

    await user.click(knop)
    await user.click(screen.getByRole('heading', { name: /Een klein klusje/ }))
    expect(screen.queryByRole('navigation', { name: 'Menu' })).not.toBeInTheDocument()

    await user.click(knop)
    await user.click(within(screen.getByRole('navigation', { name: 'Menu' })).getByRole('link', { name: 'Vragen' }))
    expect(screen.queryByRole('navigation', { name: 'Menu' })).not.toBeInTheDocument()
    expect(window.location.pathname).toBe('/vragen')
  })

  it('belooft in de hero geen aantallen of video die er nog niet zijn', () => {
    toonPagina('/')

    const hero = screen.getByRole('region', { name: 'Introductie' })
    expect(hero.textContent ?? '').not.toMatch(/\d+ klussen/)
    expect(within(hero).queryByRole('button')).not.toBeInTheDocument()
  })

  it('vertelt het nieuwe verhaal: bemiddelaar, helpers vanaf 10, ouder-toestemming, VOG vanaf 18', () => {
    const tekst = alleTekst()

    expect(tekst).toMatch(/geen werkgever/)
    expect(tekst).toMatch(/vanaf 10 jaar/i)
    expect(tekst).toMatch(/code per e-mail of sms/)
    expect(tekst).toMatch(/VOG/)
    expect(tekst).toMatch(/meldkamer/i)
    expect(tekst).toMatch(/nummers? blijv(t|en) verborgen/i)
    expect(tekst).toMatch(/foto/)
    expect(tekst).toMatch(/iDEAL/)
  })

  it('B11: zegt eerlijk dat de meldkamer chats kan lezen', async () => {
    const user = userEvent.setup()
    toonPagina('/veiligheid')

    await user.click(screen.getByRole('tab', { name: 'Privacy' }))

    const paneel = screen.getByRole('tabpanel')
    expect(paneel).toHaveTextContent('De meldkamer kan chats lezen om helpers en bewoners veilig te houden.')
    expect(paneel).not.toHaveTextContent(/alleen mee als iemand een melding doet/)
  })

  it('heeft een partners-pagina met een oproep om partner te worden', () => {
    toonPagina('/partners')

    const hoofd = screen.getByRole('main')
    expect(within(hoofd).getByRole('heading', { name: 'Word partner' })).toBeInTheDocument()
    expect(within(hoofd).getByRole('link', { name: /Mail info@heitjehulp\.nl/ })).toHaveAttribute(
      'href',
      expect.stringContaining('mailto:info@heitjehulp.nl'),
    )
  })

  it('bevat op geen enkele pagina iets van het oude stichting- en pilotverhaal', () => {
    expect(alleTekst()).not.toMatch(OUD_VERHAAL)
  })

  it('heeft ook in de paginatitel en omschrijving het nieuwe verhaal', () => {
    const html = indexHtml

    expect(html).toMatch(/heitje voor een karweitje, in jouw buurt/i)
    expect(html).not.toMatch(OUD_VERHAAL)
  })

  it('laat op geen enkele pagina prijzen, interne cijfers, verdienmodel of concurrenten zien', () => {
    const tekst = alleTekst()

    expect(tekst).not.toMatch(/€|euro/i)
    expect(tekst).not.toMatch(/begroting|commissie|cofinanciering|te financieren|subsidie/i)
    expect(tekst).not.toMatch(/BuurtHeld|BUUV|WeHelpen|Helpling|Charly Cares|Aon/)
  })

  it('heeft zelf geen inlogformulier of demo-portaal: inloggen gebeurt in de webapp', () => {
    toonPagina('/')

    expect(screen.queryByRole('button', { name: /Inloggen|Open portaal/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument()
  })

  it('wisselt de tabbladen bij Goed om te weten, ook met de pijltjestoetsen', async () => {
    const user = userEvent.setup()
    toonPagina('/veiligheid')

    await user.click(screen.getByRole('tab', { name: 'VOG' }))
    expect(screen.getByRole('tab', { name: 'VOG' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tabpanel')).toHaveTextContent('VOG voor helpers vanaf 18 jaar')

    await user.keyboard('{ArrowRight}')
    expect(screen.getByRole('tab', { name: 'Privacy' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tab', { name: 'Privacy' })).toHaveFocus()
    await user.keyboard('{ArrowRight}')
    expect(screen.getByRole('tab', { name: 'Betalen' })).toHaveAttribute('aria-selected', 'true')
    await user.keyboard('{End}')
    expect(screen.getByRole('tab', { name: 'Privacy' })).toHaveAttribute('aria-selected', 'true')
  })

  it('opent de vragen op de vragen-pagina', async () => {
    const user = userEvent.setup()
    toonPagina('/vragen')

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

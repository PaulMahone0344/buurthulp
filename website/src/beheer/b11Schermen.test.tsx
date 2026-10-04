// B11 — schermen van de meldkamer: Nog bellen, chat lezen, eerst bellen bij
// nakijken, VOG nodig, minimale leeftijd en partners.

import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { FakeBeheerData } from './data/fakeBeheerData'
import { Meldkamer } from './meldkamer/Meldkamer'
import { Screening } from './screening/Screening'
import { Systeem } from './systeem/Systeem'
import { COORDINATOR, klus, naTeKijken, NU, profiel } from './testdata'

const BEWONER = { id: 'b1', naam: 'Anja de Vries', telefoon: '06 1234 5678', adres: 'Kerkstraat 1', plaats: 'Tiel', aangemeldOp: '2026-09-19T08:00:00.000Z' }

function meldkamer(data: FakeBeheerData, filters: Record<string, string> = {}) {
  render(<Meldkamer data={data} filters={filters} zetFilters={vi.fn()} nu={() => NU} />)
}

describe('B11 meldkamer: nog bellen', () => {
  it('toont nieuwe bewoners met een bel-link en vinkt "gesproken" af', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ nogTeBellen: [BEWONER] }, COORDINATOR)
    meldkamer(data)

    const kaart = await screen.findByRole('article', { name: 'Bellen: Anja de Vries' })
    expect(within(kaart).getByRole('link', { name: /06 1234 5678/ })).toHaveAttribute('href', 'tel:0612345678')
    await user.click(within(kaart).getByRole('button', { name: 'Gesproken' }))
    const venster = screen.getByRole('dialog', { name: 'Gesproken met Anja de Vries' })
    await user.type(within(venster).getByLabelText('Notitie (optioneel)'), 'Aardig')
    await user.click(within(venster).getByRole('button', { name: 'Gesproken' }))

    expect(data.aanroepen).toContainEqual({ methode: 'kennismaking', args: ['b1', 'gesproken', 'Aardig'] })
    expect(await screen.findByText(/Kennismaking met Anja de Vries staat erin/)).toBeInTheDocument()
    expect(await screen.findByText('Iedereen is gebeld.')).toBeInTheDocument()
  })

  it('weigeren vraagt een notitie en meldt hoeveel klussen geannuleerd zijn', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ nogTeBellen: [BEWONER], openKlussenVan: { b1: 2 } }, COORDINATOR)
    meldkamer(data)

    await user.click(await screen.findByRole('button', { name: 'Weigeren' }))
    const venster = screen.getByRole('dialog', { name: 'Anja de Vries weigeren' })
    expect(within(venster).getByText(/geblokkeerd/)).toBeInTheDocument()
    const knop = within(venster).getByRole('button', { name: 'Weigeren' })
    expect(knop).toBeDisabled()
    await user.type(within(venster).getByLabelText('Notitie'), 'Wilde zorgtaken')
    await user.click(knop)

    expect(data.aanroepen).toContainEqual({ methode: 'kennismaking', args: ['b1', 'geweigerd', 'Wilde zorgtaken'] })
    expect(await screen.findByText(/2 open klussen geannuleerd/)).toBeInTheDocument()
  })
})

describe('B11 meldkamer: nakijken en chat', () => {
  it('klus die op de kennismaking wacht: eerst bellen, goedkeuren uit, afkeuren kan', async () => {
    const data = new FakeBeheerData({ naTeKijken: [naTeKijken({ id: 'n1', wachtOpKennismaking: true })] }, COORDINATOR)
    meldkamer(data)

    const kaart = await screen.findByRole('article', { name: 'Na te kijken: klus van Mevrouw Jansen' })
    expect(within(kaart).getByText('Eerst bellen')).toBeInTheDocument()
    expect(within(kaart).getByText(/Bel eerst de bewoner/)).toBeInTheDocument()
    expect(within(kaart).getByRole('button', { name: 'Goedkeuren' })).toBeDisabled()
    expect(within(kaart).getByRole('button', { name: 'Afkeuren' })).toBeEnabled()
  })

  it('leest de chat van een klus met strijder (alleen lezen)', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      {
        klussen: [klus({ id: 'k1', status: 'geaccepteerd', jongereId: 'j1', jongereNaam: 'Sami' }), klus({ id: 'k2', status: 'open' })],
        chats: {
          k1: [
            { id: 'm1', afzenderNaam: 'Mevrouw Jansen', vanBewoner: true, tekst: 'Tot zaterdag!', verstuurdOp: '2026-09-19T08:00:00.000Z', gefilterd: false, contactverzoek: false, gewist: false },
            { id: 'm2', afzenderNaam: 'Sami', vanBewoner: false, tekst: 'Mijn nummer is •••', verstuurdOp: '2026-09-19T08:05:00.000Z', gefilterd: true, contactverzoek: true, gewist: false },
          ],
        },
      },
      COORDINATOR,
    )
    meldkamer(data, { filter: 'alle' })

    const knoppen = await screen.findAllByRole('button', { name: /^Chat lezen/ })
    expect(knoppen).toHaveLength(1)
    await user.click(knoppen[0])
    const venster = screen.getByRole('dialog', { name: /Chat bij de klus van/ })
    expect(await within(venster).findByText('Tot zaterdag!')).toBeInTheDocument()
    expect(within(venster).getByText('Nummer of link weggehaald')).toBeInTheDocument()
    expect(within(venster).getByText('Vraagt contact buiten de app')).toBeInTheDocument()
    expect(within(venster).queryByRole('textbox')).not.toBeInTheDocument()
    await user.click(within(venster).getByRole('button', { name: 'Sluiten' }))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })
})

describe('B11 screening: VOG nodig', () => {
  it('toont 18+ zonder of met verlopen VOG en zet "VOG gezien"', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      {
        profielen: [profiel({ id: 'p1', naam: 'Sanne' })],
        vog: [
          { gebruikerId: 'u1', profielId: 'p1', naam: 'Sanne', leeftijd: 20, verificatiestatus: 'goedgekeurd', vogGezienOp: '', verlooptOp: '', reden: 'geen' },
          { gebruikerId: 'u2', profielId: 'p2', naam: 'Ruud', leeftijd: 30, verificatiestatus: 'goedgekeurd', vogGezienOp: '2023-09-01T10:00:00.000Z', verlooptOp: '2026-09-01', reden: 'verlopen' },
        ],
      },
      COORDINATOR,
    )
    render(<Screening data={data} filters={{ lijst: 'vog' }} zetFilters={vi.fn()} nu={() => NU} />)

    const lijst = await screen.findByLabelText('Strijders die een VOG nodig hebben')
    expect(await within(lijst).findByText(/20 jaar · nog geen VOG gezien/)).toBeInTheDocument()
    expect(within(lijst).getByText(/30 jaar · VOG verlopen op/)).toBeInTheDocument()
    expect(screen.getByRole('tab', { name: /VOG nodig/ })).toHaveTextContent('2')

    await user.click(within(lijst).getByRole('button', { name: 'VOG gezien: Sanne' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'VOG gezien' }))
    expect(data.aanroepen).toContainEqual({ methode: 'vogGezien', args: ['p1'] })
    expect(await screen.findByText(/VOG van Sanne staat erin/)).toBeInTheDocument()
    expect(screen.getByRole('tab', { name: /VOG nodig/ })).toHaveTextContent('1')
  })
})

describe('B11 systeem: minimale leeftijd en partners', () => {
  it('zet de minimale leeftijd van een klustype', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ klustypes: [{ id: 't1', naam: 'Tuin', icoon: '', richtduur: 60, richtvergoeding: 1500, minLeeftijd: 13 }] }, COORDINATOR)
    render(<Systeem data={data} filters={{ tab: 'klustypes' }} zetFilters={vi.fn()} />)

    const keuze = await screen.findByLabelText('Minimale leeftijd Tuin')
    expect(keuze).toHaveValue('13')
    await user.selectOptions(keuze, '16')
    await user.click(screen.getByRole('button', { name: 'Opslaan Tuin' }))
    expect(data.aanroepen).toContainEqual({ methode: 'wijzigKlustype', args: ['t1', { richtduur: 60, richtvergoeding: 1500, minLeeftijd: 16 }] })
  })

  it('nieuw klustype is standaard 18+', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({}, COORDINATOR)
    render(<Systeem data={data} filters={{ tab: 'klustypes' }} zetFilters={vi.fn()} />)
    const form = await screen.findByRole('form', { name: 'Nieuw klustype' })
    await user.type(within(form).getByLabelText('Naam'), 'Ramen')
    await user.type(within(form).getByLabelText('Richtvergoeding (euro)'), '10')
    await user.click(within(form).getByRole('button', { name: 'Klustype toevoegen' }))
    expect(data.aanroepen[0]).toMatchObject({ methode: 'maakKlustype', args: [{ naam: 'Ramen', minLeeftijd: 18 }] })
  })

  it('partners: tellers, toevoegen met code, uitzetten', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      { partners: [{ id: 'p1', naam: 'Jongerenwerk Tiel', code: 'TIEL-JW', actief: true, notitie: '', aangemeld: 12, goedgekeurd: 9 }] },
      COORDINATOR,
    )
    render(<Systeem data={data} filters={{ tab: 'partners' }} zetFilters={vi.fn()} />)

    expect(await screen.findByLabelText('Aangemeld via Jongerenwerk Tiel')).toHaveTextContent('12')
    expect(screen.getByLabelText('Goedgekeurd via Jongerenwerk Tiel')).toHaveTextContent('9')

    const form = screen.getByRole('form', { name: 'Nieuwe partner' })
    await user.type(within(form).getByLabelText('Naam organisatie'), 'Mozaïek')
    await user.type(within(form).getByLabelText('Code (bijv. TIEL-JW)'), 'x')
    await user.click(within(form).getByRole('button', { name: 'Partner toevoegen' }))
    expect(screen.getByText(/3 tot 20 tekens/)).toBeInTheDocument()
    expect(data.aanroepen).toHaveLength(0)

    await user.type(within(form).getByLabelText('Code (bijv. TIEL-JW)'), 'moz-1')
    await user.click(within(form).getByRole('button', { name: 'Partner toevoegen' }))
    expect(data.aanroepen).toContainEqual({ methode: 'maakPartner', args: [{ naam: 'Mozaïek', code: 'XMOZ-1', notitie: '' }] })
    expect(await screen.findByLabelText('Partner Mozaïek')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Zet Jongerenwerk Tiel uit' }))
    expect(data.aanroepen).toContainEqual({ methode: 'zetPartnerActief', args: ['p1', false] })
    expect(await screen.findByRole('button', { name: 'Zet Jongerenwerk Tiel aan' })).toBeInTheDocument()
  })
})

describe('B11 systeem: schakelaars', () => {
  it('zet "keuren wacht op de kennismaking" aan', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ instellingen: [{ id: 'i1', sleutel: 'b11_kennismaking_verplicht', waarde: 'false' }] }, COORDINATOR)
    render(<Systeem data={data} filters={{ tab: 'instellingen' }} zetFilters={vi.fn()} />)

    await user.click(await screen.findByRole('button', { name: 'Keuren wacht op de kennismaking aanzetten' }))
    expect(data.aanroepen).toContainEqual({ methode: 'slaInstellingOp', args: ['b11_kennismaking_verplicht', 'true'] })
    expect(await screen.findByRole('button', { name: 'Keuren wacht op de kennismaking uitzetten' })).toBeInTheDocument()
  })
})

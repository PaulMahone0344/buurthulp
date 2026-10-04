import { act, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { FakeBeheerData } from '../data/fakeBeheerData'
import { COORDINATOR, incident, klus, naTeKijken, NU } from '../testdata'
import { Meldkamer } from './Meldkamer'

function opzet(data: FakeBeheerData, filters: Record<string, string> = {}) {
  const zetFilters = vi.fn()
  render(<Meldkamer data={data} filters={filters} zetFilters={zetFilters} nu={() => NU} />)
  return zetFilters
}

describe('D1 meldkamer', () => {
  it('toont de vijf tegels', async () => {
    const data = new FakeBeheerData(
      {
        klussen: [
          klus({ id: 'a', status: 'open', aangemaaktOp: '2026-09-19T09:00:00.000Z' }),
          klus({ id: 'b', status: 'open' }),
          klus({ id: 'c', status: 'bezig', jongereId: 'j1', jongereNaam: 'Sami' }),
          klus({ id: 'd', status: 'afgerond', wanneerVan: '2026-09-18T08:00:00.000Z' }),
        ],
        incidenten: [incident({ id: 'i1' }), incident({ id: 'i2', afhandeling: 'Gebeld.' })],
      },
      COORDINATOR,
    )
    opzet(data)

    await screen.findAllByRole('article')
    expect(screen.getByRole('article', { name: 'Open hulpvragen' })).toHaveTextContent('2')
    expect(screen.getByRole('article', { name: 'Zonder match langer dan 2 uur' })).toHaveTextContent('1')
    expect(screen.getByRole('article', { name: 'Vandaag gepland' })).toHaveTextContent('3')
    expect(screen.getByRole('article', { name: 'Nu bezig' })).toHaveTextContent('1')
    expect(screen.getByRole('article', { name: 'Incidenten open' })).toHaveTextContent('1')
  })

  describe('volgorde: wat nu moet staat bovenaan', () => {
    const BEWONER = { id: 'b1', naam: 'Anja de Vries', telefoon: '06 1234 5678', adres: 'Kerkstraat 1', plaats: 'Tiel', aangemeldOp: '2026-09-19T08:00:00.000Z' }

    it('zet de incidenten boven nog bellen, nakijken en de hulpvragen', async () => {
      const data = new FakeBeheerData({ incidenten: [incident({ id: 'i1' })], klussen: [klus({ id: 'a' })] }, COORDINATOR)
      opzet(data)

      await screen.findByRole('article', { name: /Melding van/ })
      const koppen = screen.getAllByRole('heading', { level: 2 }).map((kop) => kop.textContent ?? '')
      const plek = (begin: string) => koppen.findIndex((kop) => kop.startsWith(begin))
      expect(plek('Incidenten')).toBe(0)
      expect(plek('Nog bellen')).toBeGreaterThan(plek('Incidenten'))
      expect(plek('Klussen na te kijken')).toBeGreaterThan(plek('Nog bellen'))
      expect(plek('Hulpvragen')).toBeGreaterThan(plek('Klussen na te kijken'))
    })

    it('laat zonder filter in de URL alleen de nieuwe hulpvragen zien', async () => {
      const data = new FakeBeheerData(
        { klussen: [klus({ id: 'a', hulpvragerNaam: 'Jansen' }), klus({ id: 'b', status: 'afgerond', hulpvragerNaam: 'De Vries' })] },
        COORDINATOR,
      )
      opzet(data)

      expect(await screen.findByRole('row', { name: 'Hulpvraag van Jansen' })).toBeInTheDocument()
      expect(screen.queryByRole('row', { name: 'Hulpvraag van De Vries' })).not.toBeInTheDocument()
      expect(screen.getByRole('tab', { name: /Nieuw/ })).toHaveAttribute('aria-selected', 'true')
    })

    it('toont met filter alle ook de afgeronde hulpvragen', async () => {
      const data = new FakeBeheerData({ klussen: [klus({ id: 'b', status: 'afgerond', hulpvragerNaam: 'De Vries' })] }, COORDINATOR)
      opzet(data, { filter: 'alle' })

      expect(await screen.findByRole('row', { name: 'Hulpvraag van De Vries' })).toBeInTheDocument()
    })

    it('toont de hulpvragen als tabel: één regel per klus, kolomkoppen één keer', async () => {
      const data = new FakeBeheerData(
        {
          klussen: [
            klus({ id: 'a', hulpvragerNaam: 'Jansen', aangemaaktOp: '2026-09-19T05:00:00.000Z' }),
            klus({ id: 'b', hulpvragerNaam: 'De Vries', status: 'geaccepteerd', jongereId: 'j1', jongereNaam: 'Sami' }),
          ],
        },
        COORDINATOR,
      )
      opzet(data, { filter: 'alle' })

      const tabel = await screen.findByRole('table', { name: 'Hulpvragen' })
      const jansen = await within(tabel).findByRole('row', { name: 'Hulpvraag van Jansen' })
      expect(within(tabel).getAllByRole('columnheader').map((kop) => kop.textContent)).toEqual([
        'Bewoner',
        'Klus',
        'Wanneer',
        'Strijder',
        'Status',
        'Acties',
      ])
      expect(within(tabel).getAllByRole('row')).toHaveLength(3)
      expect(within(jansen).getByText(/Wacht langer dan 2 uur/)).toBeInTheDocument()
      expect(within(jansen).getByRole('button', { name: 'Koppelen' })).toBeInTheDocument()
      const deVries = within(tabel).getByRole('row', { name: 'Hulpvraag van De Vries' })
      expect(deVries).toHaveTextContent('Sami')
      expect(within(deVries).getByRole('button', { name: /^Chat lezen/ })).toBeInTheDocument()
    })

    it('houdt lege blokken kort: alleen de kop en dat er niets te doen is', async () => {
      opzet(new FakeBeheerData({}, COORDINATOR))

      expect(await screen.findByText('Iedereen is gebeld.')).toBeInTheDocument()
      expect(screen.getByText('Er is niets na te kijken.')).toBeInTheDocument()
      expect(screen.queryByText(/bel ze even/)).not.toBeInTheDocument()
      expect(screen.queryByText(/Strijders zien een klus pas/)).not.toBeInTheDocument()
    })

    it('legt een blok wel uit als er iets te doen is', async () => {
      opzet(new FakeBeheerData({ nogTeBellen: [BEWONER], naTeKijken: [naTeKijken({ id: 'n1' })] }, COORDINATOR))

      expect(await screen.findByText(/bel ze even/)).toBeInTheDocument()
      expect(screen.getByText(/Strijders zien een klus pas/)).toBeInTheDocument()
    })
  })

  it('filtert de hulpvragen via de URL', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      { klussen: [klus({ id: 'a', hulpvragerNaam: 'Jansen' }), klus({ id: 'b', status: 'bezig', hulpvragerNaam: 'De Vries' })] },
      COORDINATOR,
    )
    const zetFilters = opzet(data, { filter: 'in_uitvoering' })

    expect(await screen.findByRole('row', { name: 'Hulpvraag van De Vries' })).toBeInTheDocument()
    expect(screen.queryByRole('row', { name: 'Hulpvraag van Jansen' })).not.toBeInTheDocument()

    await user.click(screen.getByRole('tab', { name: /Nieuw/ }))
    expect(zetFilters).toHaveBeenCalledWith({ filter: 'nieuw' })
  })

  it('ververst bij een realtime-bericht', async () => {
    const data = new FakeBeheerData({}, COORDINATOR)
    opzet(data)
    await screen.findByText('Geen hulpvragen in dit filter.')
    expect(data.aantalAbonnees).toBe(1)

    data.stand.klussen.push(klus({ id: 'nieuw', hulpvragerNaam: 'Bakker' }))
    await act(async () => data.meldWijziging())

    expect(await screen.findByRole('row', { name: 'Hulpvraag van Bakker' })).toBeInTheDocument()
  })

  it('koppelt handmatig met een waarschuwing voor een andere wijk', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      {
        klussen: [klus({ id: 'k1' })],
        kandidaten: [
          { id: 'j2', naam: 'Zoe', wijkNaam: 'Passewaaij', klussenAantal: 4 },
          { id: 'j1', naam: 'Sami', wijkNaam: 'Tiel-West', klussenAantal: 2 },
        ],
      },
      COORDINATOR,
    )
    opzet(data)

    await user.click(await screen.findByRole('button', { name: 'Koppelen' }))
    const venster = screen.getByRole('dialog')
    const keuzes = await within(venster).findAllByRole('radio')
    expect(keuzes[0]).toHaveAccessibleName(/Sami/)

    await user.click(within(venster).getByRole('radio', { name: /Zoe/ }))
    expect(within(venster).getByRole('note')).toHaveTextContent('andere wijk')
    await user.click(within(venster).getByRole('button', { name: 'Koppelen' }))

    expect(data.aanroepen).toContainEqual({ methode: 'koppelen', args: ['k1', 'j2'] })
    // de klus verhuist van Nieuw naar Gematcht; de meldkamer leest waar hij nu staat
    expect(await screen.findByText(/is gekoppeld. Hij staat nu onder Gematcht/)).toBeInTheDocument()
    expect(screen.queryByRole('row', { name: 'Hulpvraag van Mevrouw Jansen' })).not.toBeInTheDocument()
    expect(screen.getByRole('tab', { name: /Gematcht/ })).toHaveTextContent('1')
  })

  it('annuleert met een verplichte reden en toont een weigering van de server', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ klussen: [klus({ id: 'k1' })] }, COORDINATOR)
    opzet(data)

    await user.click(await screen.findByRole('button', { name: 'Annuleren' }))
    const venster = screen.getByRole('dialog')
    const knop = within(venster).getByRole('button', { name: 'Klus annuleren' })
    expect(knop).toBeDisabled()

    await user.type(within(venster).getByLabelText('Reden'), 'Oudere belde af')
    data.volgendeFout = 'Je hoort niet bij deze klus.'
    await user.click(knop)
    expect(await within(venster).findByRole('alert')).toHaveTextContent('Je hoort niet bij deze klus.')

    await user.click(knop)
    expect(data.aanroepen.filter((a) => a.methode === 'annuleren')).toHaveLength(2)
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('handelt een incident af', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ incidenten: [incident({ id: 'i1' })] }, COORDINATOR)
    opzet(data)

    await user.click(await screen.findByRole('button', { name: 'Afhandelen' }))
    await user.type(screen.getByLabelText('Wat heb je gedaan'), 'Oudere gebeld, andere jongere gestuurd.')
    await user.click(screen.getByRole('button', { name: 'Afgehandeld' }))

    expect(data.stand.incidenten[0].afhandeling).toBe('Oudere gebeld, andere jongere gestuurd.')
  })

  it('B5: een signaal na de klus staat in de lijst met een eigen pil', async () => {
    const data = new FakeBeheerData(
      { incidenten: [incident({ id: 's1', soort: 'signaal', omschrijving: '[geheime vraag] Na de klus: "Voelde je je veilig?" Antwoord: nee.' })] },
      COORDINATOR,
    )
    opzet(data)
    const pil = await screen.findByText('Signaal na de klus')
    expect(pil).toHaveClass('sev', 'sev--signaal')
    expect(screen.getByText(/Voelde je je veilig/)).toBeInTheDocument()
    expect(screen.getByRole('article', { name: 'Incidenten open' })).toHaveTextContent('1')
  })

  it('zet de incidenten op volgorde, nieuwste bovenaan', async () => {
    const data = new FakeBeheerData(
      {
        incidenten: [
          incident({ id: 'oud', melderNaam: 'Oud', gemeldOp: '2026-09-18T09:00:00.000Z' }),
          incident({ id: 'nieuw', melderNaam: 'Nieuw', gemeldOp: '2026-09-19T09:00:00.000Z', soort: 'nood', klusId: '' }),
        ],
      },
      COORDINATOR,
    )
    opzet(data)

    const rijen = await screen.findAllByRole('article', { name: /Melding van/ })
    expect(rijen.map((r) => r.getAttribute('aria-label'))).toEqual(['Melding van Nieuw', 'Melding van Oud'])
    expect(rijen[0]).toHaveTextContent('Noodmelding')
  })
})

describe('telefonische aanmelding', () => {
  it('maakt een nieuwe oudere en een klus die loopt als een app-klus', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      {
        wijken: [{ id: 'w1', gemeente: 'Tiel', wijk: 'Tiel-West', postcodes: ['4001'], actief: true }],
        klustypes: [{ id: 't1', naam: 'boodschappen', icoon: '', richtduur: 60, richtvergoeding: 1250, minLeeftijd: 10 }],
      },
      COORDINATOR,
    )
    opzet(data)

    await user.click(screen.getByRole('button', { name: 'Telefonische aanmelding' }))
    await user.type(screen.getByLabelText('Zoek de oudere op naam of telefoon'), '0612345678')
    await user.click(screen.getByRole('button', { name: 'Zoeken' }))
    expect(await screen.findByText('Niemand gevonden.')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Nieuwe oudere aanmaken' }))
    expect(screen.getByLabelText('Telefoon')).toHaveValue('0612345678')
    await user.type(screen.getByLabelText('Naam'), 'Mevrouw Bakker')
    // ADRES: zoals in de app, postcode + huisnummer -> straat en plaats (PDOK).
    expect(screen.queryByLabelText('Adres')).not.toBeInTheDocument()
    await user.type(screen.getByLabelText('Postcode'), '4001ma')
    expect(screen.getByLabelText('Postcode')).toHaveValue('4001 MA')
    await user.type(screen.getByLabelText('Huisnummer'), '1')
    expect(await screen.findByText('Kerkstraat 1, 4001 MA Tiel')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Oudere aanmaken' }))

    expect(await screen.findByText(/Hulpvraag voor/)).toHaveTextContent('Mevrouw Bakker')
    expect(data.stand.ouderen[0].email).toBe('0612345678@telefonisch.heitjehulp.invalid')
    expect(data.adresVerzoeken).toEqual([{ postcode: '4001 MA', huisnummer: '1', toevoeging: '' }])
    expect(screen.getByLabelText('Adres van de klus')).toHaveValue('Kerkstraat 1, 4001 MA Tiel')

    await user.selectOptions(screen.getByLabelText('Soort klus'), 't1')
    await user.type(screen.getByLabelText('Omschrijving'), 'Boodschappen bij de Jumbo')
    await user.type(screen.getByLabelText('Datum'), '2026-09-20')
    await user.type(screen.getByLabelText('Van'), '10:00')
    await user.type(screen.getByLabelText('Tot'), '11:00')
    await user.click(screen.getByRole('button', { name: 'Hulpvraag plaatsen' }))

    expect(await screen.findByRole('status')).toHaveTextContent('Mevrouw Bakker staat open')
    const create = data.aanroepen.find((a) => a.methode === 'hh_klussen.create')
    expect(create?.args[0]).toMatchObject({
      geplaatst_door: 'c1',
      bron: 'telefoon',
      status: 'open',
      bedrag_bruto: 1250,
      vergoeding_jongere: 1250,
      commissie: 0,
      wanneer_van: '2026-09-20T08:00:00.000Z',
      wanneer_tot: '2026-09-20T09:00:00.000Z',
    })
    expect(await screen.findByRole('row', { name: 'Hulpvraag van Mevrouw Bakker' })).toHaveTextContent('telefonisch')
  })

  it('adres niet gevonden: rustige melding en niet aanmaken; uitzondering handmatig kan wel', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      { wijken: [{ id: 'w1', gemeente: 'Tiel', wijk: 'Tiel en omstreken', postcodes: [], actief: true }] },
      COORDINATOR,
    )
    opzet(data)
    await user.click(screen.getByRole('button', { name: 'Telefonische aanmelding' }))
    await user.click(screen.getByRole('button', { name: 'Nieuwe oudere aanmaken' }))
    await user.type(screen.getByLabelText('Naam'), 'Meneer Visser')
    await user.type(screen.getByLabelText('Telefoon'), '0612345679')
    await user.type(screen.getByLabelText('Postcode'), '4001 MA')
    await user.type(screen.getByLabelText('Huisnummer'), '999')
    expect(await screen.findByText('We vinden dit adres niet. Klopt de postcode en het huisnummer?')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Oudere aanmaken' }))
    expect(screen.getByRole('alert')).toHaveTextContent(/adres/)
    expect(data.stand.ouderen).toHaveLength(0)

    await user.click(screen.getByLabelText('Adres handmatig invoeren (uitzondering, zonder controle)'))
    await user.type(screen.getByLabelText('Straat en huisnummer'), 'Woonwagenkamp 1')
    await user.type(screen.getByLabelText('Plaats'), 'Tiel')
    await user.selectOptions(screen.getByLabelText('Wijk'), 'w1')
    await user.click(screen.getByRole('button', { name: 'Oudere aanmaken' }))
    expect(await screen.findByText(/Hulpvraag voor/)).toHaveTextContent('Meneer Visser')
    expect(data.aanroepen.find((a) => a.methode === 'maakOudere')?.args[0]).toMatchObject({ handmatig: true, wijkId: 'w1' })
  })

  it('kiest een bestaande oudere', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      {
        ouderen: [
          { id: 'o1', naam: 'Mevrouw Jansen', email: 'j@x.nl', telefoon: '0612345678', adres: 'Dorpsstraat 2', postcode: '', plaats: 'Tiel', wijkId: 'w1' },
        ],
        klustypes: [{ id: 't1', naam: 'tuin', icoon: '', richtduur: 60, richtvergoeding: 1500, minLeeftijd: 13 }],
      },
      COORDINATOR,
    )
    opzet(data)

    await user.click(screen.getByRole('button', { name: 'Telefonische aanmelding' }))
    await user.type(screen.getByLabelText('Zoek de oudere op naam of telefoon'), 'jansen')
    await user.click(screen.getByRole('button', { name: 'Zoeken' }))
    await user.click(await screen.findByRole('button', { name: 'Kies Mevrouw Jansen' }))

    await user.click(screen.getByRole('button', { name: 'Hulpvraag plaatsen' }))
    expect(screen.getByRole('alert')).toHaveTextContent('Kies wat voor klus het is.')
    expect(data.aanroepen.some((a) => a.methode === 'maakTelefonischeKlus')).toBe(false)
  })

  describe('B4 klussen na te kijken', () => {
    it('toont foto, tekst en de markering van het voorfilter', async () => {
      const data = new FakeBeheerData(
        { naTeKijken: [naTeKijken({ id: 'n1', omschrijving: 'Bel 0612345678 voor bier', markering: ['telefoon', 'neelijst'] })] },
        COORDINATOR,
      )
      opzet(data)

      const kaart = await screen.findByRole('article', { name: 'Na te kijken: klus van Mevrouw Jansen' })
      expect(within(kaart).getByRole('img', { name: 'Foto bij de klus van Mevrouw Jansen' })).toHaveAttribute(
        'src',
        'https://api.test/api/files/hh_klussen/n/heg.jpg?token=t',
      )
      expect(kaart).toHaveTextContent('Bel 0612345678 voor bier')
      expect(kaart).toHaveTextContent('vanaf 13 jaar')
      expect(within(kaart).getByLabelText('Markering van het voorfilter')).toHaveTextContent('Telefoonnummer')
      expect(within(kaart).getByLabelText('Markering van het voorfilter')).toHaveTextContent('Nee-lijst')
    })

    it('goedkeuren stuurt het besluit en haalt de klus uit de lijst', async () => {
      const user = userEvent.setup()
      const data = new FakeBeheerData({ naTeKijken: [naTeKijken({ id: 'n1' })] }, COORDINATOR)
      opzet(data)

      const kaart = await screen.findByRole('article', { name: 'Na te kijken: klus van Mevrouw Jansen' })
      await user.click(within(kaart).getByRole('button', { name: 'Goedkeuren' }))

      expect(data.aanroepen).toContainEqual({ methode: 'keurKlus', args: ['n1', { besluit: 'goedkeuren' }] })
      expect(await screen.findByText('Er is niets na te kijken.')).toBeInTheDocument()
      expect(screen.getByText(/is goedgekeurd/)).toBeInTheDocument()
    })

    it('afkeuren vraagt een reden die de bewoner te zien krijgt', async () => {
      const user = userEvent.setup()
      const data = new FakeBeheerData({ naTeKijken: [naTeKijken({ id: 'n1' })] }, COORDINATOR)
      opzet(data)

      const kaart = await screen.findByRole('article', { name: 'Na te kijken: klus van Mevrouw Jansen' })
      await user.click(within(kaart).getByRole('button', { name: 'Afkeuren' }))
      const venster = screen.getByRole('dialog')
      const bevestig = within(venster).getByRole('button', { name: 'Afkeuren' })
      expect(bevestig).toBeDisabled()

      await user.type(within(venster).getByLabelText('Reden'), 'Sigaretten halen kan niet.')
      await user.click(bevestig)

      expect(data.aanroepen).toContainEqual({
        methode: 'keurKlus',
        args: ['n1', { besluit: 'afkeuren', reden: 'Sigaretten halen kan niet.' }],
      })
      expect(await screen.findByText('Er is niets na te kijken.')).toBeInTheDocument()
    })

    it('geen klussen: een rustige lege melding', async () => {
      opzet(new FakeBeheerData({}, COORDINATOR))
      expect(await screen.findByText('Er is niets na te kijken.')).toBeInTheDocument()
    })
  })
})

import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { FakeBeheerData } from '../data/fakeBeheerData'
import { COORDINATOR } from '../testdata'
import { Systeem } from './Systeem'

function opzet(data: FakeBeheerData, filters: Record<string, string>) {
  const zetFilters = vi.fn()
  render(<Systeem data={data} filters={filters} zetFilters={zetFilters} />)
  return zetFilters
}

describe('D4 systeembeheer', () => {
  it('zet een wijk uit en slaat postcodes op', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      { wijken: [{ id: 'w1', gemeente: 'Tiel', wijk: 'Tiel-West', postcodes: ['4001'], actief: true }] },
      COORDINATOR,
    )
    opzet(data, { tab: 'wijken' })

    await user.click(await screen.findByRole('button', { name: 'Zet Tiel-West uit' }))
    expect(data.aanroepen).toContainEqual({ methode: 'wijzigWijk', args: ['w1', { actief: false }] })
    expect(await screen.findByRole('button', { name: 'Zet Tiel-West aan' })).toBeInTheDocument()

    const veld = screen.getByLabelText('Postcodes van Tiel-West')
    await user.clear(veld)
    await user.type(veld, '4001, 4002')
    await user.click(screen.getByRole('button', { name: 'Postcodes opslaan' }))
    expect(data.aanroepen).toContainEqual({ methode: 'wijzigWijk', args: ['w1', { postcodes: ['4001', '4002'] }] })
  })

  it('wijzigt richtduur en richtvergoeding van een klustype', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      { klustypes: [{ id: 't1', naam: 'tuin', icoon: 'tuin', richtduur: 60, richtvergoeding: 1500, minLeeftijd: 13 }] },
      COORDINATOR,
    )
    opzet(data, { tab: 'klustypes' })

    const vergoeding = await screen.findByLabelText('Richtvergoeding tuin (euro)')
    expect(vergoeding).toHaveValue('15,00')
    await user.clear(vergoeding)
    await user.type(vergoeding, '17,50')
    await user.clear(screen.getByLabelText('Richtduur tuin (minuten)'))
    await user.type(screen.getByLabelText('Richtduur tuin (minuten)'), '90')
    await user.click(screen.getByRole('button', { name: 'Opslaan' }))

    expect(data.aanroepen).toContainEqual({ methode: 'wijzigKlustype', args: ['t1', { richtduur: 90, richtvergoeding: 1750, minLeeftijd: 13 }] })
  })

  it('B2: toont de werkgebied-markering van de server', async () => {
    const data = new FakeBeheerData(
      {
        gebruikers: [
          { id: 'u1', naam: 'Ver', email: 'v@x.nl', rol: 'hulpvrager', telefoon: '', geblokkeerd: false, werkgebiedStatus: 'buiten' },
          { id: 'u2', naam: 'Zoek', email: 'z@x.nl', rol: 'jongere', telefoon: '', geblokkeerd: false, werkgebiedStatus: 'onbekend' },
          { id: 'u3', naam: 'Hier', email: 'h@x.nl', rol: 'jongere', telefoon: '', geblokkeerd: false, werkgebiedStatus: 'binnen' },
        ],
      },
      COORDINATOR,
    )
    opzet(data, { tab: 'gebruikers' })

    expect(within(await screen.findByLabelText('Gebruiker Ver')).getByText('Buiten werkgebied')).toBeInTheDocument()
    expect(within(screen.getByLabelText('Gebruiker Zoek')).getByText('Adres niet gevonden')).toBeInTheDocument()
    expect(within(screen.getByLabelText('Gebruiker Hier')).queryByText(/werkgebied|niet gevonden/)).not.toBeInTheDocument()
  })

  it('ADRES: pil bij een adres dat handmatig of niet gecontroleerd is', async () => {
    const data = new FakeBeheerData(
      {
        gebruikers: [
          { id: 'u1', naam: 'Hand', email: 'a@x.nl', rol: 'hulpvrager', telefoon: '', geblokkeerd: false, werkgebiedStatus: 'binnen', adresBron: 'handmatig' },
          { id: 'u2', naam: 'Weg', email: 'b@x.nl', rol: 'jongere', telefoon: '', geblokkeerd: false, werkgebiedStatus: 'binnen', adresBron: 'ongecontroleerd' },
          { id: 'u3', naam: 'Goed', email: 'c@x.nl', rol: 'jongere', telefoon: '', geblokkeerd: false, werkgebiedStatus: 'binnen', adresBron: 'pdok' },
        ],
      },
      COORDINATOR,
    )
    opzet(data, { tab: 'gebruikers' })

    expect(within(await screen.findByLabelText('Gebruiker Hand')).getByText('Adres handmatig')).toBeInTheDocument()
    expect(within(screen.getByLabelText('Gebruiker Weg')).getByText('Adres niet gecontroleerd')).toBeInTheDocument()
    expect(within(screen.getByLabelText('Gebruiker Goed')).queryByText(/Adres/)).not.toBeInTheDocument()
  })

  it('blokkeert een gebruiker en wijzigt een rol, allebei na bevestigen', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      { gebruikers: [{ id: 'u1', naam: 'Sami', email: 's@x.nl', rol: 'jongere', telefoon: '', geblokkeerd: false, werkgebiedStatus: 'binnen' }] },
      COORDINATOR,
    )
    const zetFilters = opzet(data, { tab: 'gebruikers' })

    await user.type(screen.getByLabelText('Zoek op naam, e-mail of telefoon'), 'sami')
    await user.click(screen.getByRole('button', { name: 'Zoeken' }))
    expect(zetFilters).toHaveBeenCalledWith({ tab: 'gebruikers', zoek: 'sami' })

    await user.click(await screen.findByRole('button', { name: 'Blokkeer Sami' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Blokkeren' }))
    expect(data.aanroepen).toContainEqual({ methode: 'zetGeblokkeerd', args: ['u1', true] })
    expect(await screen.findByText('Geblokkeerd')).toBeInTheDocument()

    await user.selectOptions(screen.getByLabelText('Rol van Sami'), 'hulpvrager')
    await user.click(screen.getByRole('button', { name: 'Rol opslaan' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Rol wijzigen' }))
    expect(data.aanroepen).toContainEqual({ methode: 'wijzigRol', args: ['u1', 'hulpvrager'] })
    // B3 (K5): familie is geen keuze meer.
    expect(within(screen.getByLabelText('Rol van Sami')).queryByRole('option', { name: 'Familie' })).not.toBeInTheDocument()
  })

  it('slaat een instelling op', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ instellingen: [{ id: 'i1', sleutel: 'straal_km', waarde: '5' }] }, COORDINATOR)
    opzet(data, { tab: 'instellingen' })

    expect(await screen.findByLabelText('Standaardstraal (km)')).toHaveValue('5')
    await user.type(screen.getByLabelText('Commissiepercentage (%)'), '10')
    await user.click(screen.getByRole('button', { name: 'Commissiepercentage (%) opslaan' }))

    expect(data.aanroepen).toContainEqual({ methode: 'slaInstellingOp', args: ['commissiepercentage', '10'] })
    expect(await screen.findByRole('status')).toHaveTextContent('opgeslagen')
  })

  it('toont betalingen; opnieuw aanbieden staat uit tot M16', async () => {
    const data = new FakeBeheerData(
      { betalingen: [{ id: 'b1', klusId: 'k1', klusOmschrijving: 'Boodschappen', bedrag: 1250, status: 'mislukt', betaaldOp: '' }] },
      COORDINATOR,
    )
    opzet(data, { tab: 'betalingen' })

    expect(await screen.findByText('Mislukt')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Opnieuw aanbieden' })).toBeDisabled()
  })

  it('filtert het auditlog op actie en persoon uit de URL', async () => {
    const user = userEvent.setup()
    const regel = (id: string, doorNaam: string, actie: string) => ({
      id,
      gebeurdOp: '2026-09-19T09:00:00.000Z',
      doorId: id,
      doorNaam,
      actie,
      doelCollectie: 'hh_users',
      doelId: 'u1',
      detail: '{"velden":["geblokkeerd"]}',
    })
    const data = new FakeBeheerData(
      { auditlog: [regel('1', 'Coordinator Een', 'wijzigen'), regel('2', 'Coordinator Twee', 'aanmaken')] },
      COORDINATOR,
    )
    const zetFilters = opzet(data, { tab: 'auditlog', actie: 'wijzigen' })

    expect(await screen.findByText(/Coordinator Een · wijzigen/)).toBeInTheDocument()
    expect(screen.queryByText(/Coordinator Twee/)).not.toBeInTheDocument()

    await user.selectOptions(screen.getByLabelText('Actie'), 'aanmaken')
    expect(zetFilters).toHaveBeenCalledWith({ tab: 'auditlog', actie: 'aanmaken', persoon: '' })
  })

  it('B9: recensie verbergen met reden en terugzetten', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      {
        recensies: [
          { id: 'b1', sterren: 2, tekst: 'Bel me op 0612345678', vanNaam: 'Anja de Vries', naarNaam: 'Daan', gemaaktOp: '2026-10-01T10:00:00Z', verborgen: false, verborgenReden: '' },
        ],
      },
      COORDINATOR,
    )
    opzet(data, { tab: 'recensies' })
    await user.type(await screen.findByLabelText('Reden om de recensie van Anja de Vries te verbergen'), 'Telefoonnummer')
    await user.click(screen.getByRole('button', { name: 'Verbergen' }))
    expect(data.aanroepen).toContainEqual({ methode: 'verbergRecensie', args: ['b1', true, 'Telefoonnummer'] })
    expect(await screen.findByText('Verborgen')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Terugzetten' }))
    expect(data.aanroepen).toContainEqual({ methode: 'verbergRecensie', args: ['b1', false, ''] })
  })

  it('B9: een verklaring nakijken met de controlecode', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData(
      {
        verklaringen: [
          { code: 'ABCDE-FGH23', uitgegevenOp: '2026-10-04T10:00:00Z', voornaam: 'Daan', klussen: 5, uren: 6.5, periodeVan: '2026-08-01', periodeTot: '2026-09-12', niveau: 'Ervaren', badges: [{ naam: 'Eerste klus', datum: '2026-08-01' }], vertrouwen: [] },
        ],
      },
      COORDINATOR,
    )
    opzet(data, { tab: 'recensies' })
    await user.type(screen.getByLabelText('Controlecode'), 'abcde fgh23')
    await user.click(screen.getByRole('button', { name: 'Nakijken' }))
    expect(await screen.findByText(/ABCDE-FGH23 · Daan · 5 klussen/)).toBeInTheDocument()
    await user.clear(screen.getByLabelText('Controlecode'))
    await user.type(screen.getByLabelText('Controlecode'), 'ZZZZZ-ZZZZZ')
    await user.click(screen.getByRole('button', { name: 'Nakijken' }))
    expect(await screen.findByText('Deze code kennen we niet.')).toBeInTheDocument()
  })
})

import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { FakeBeheerData } from '../data/fakeBeheerData'
import { COORDINATOR, NU, profiel } from '../testdata'
import { Screening } from './Screening'

function opzet(data: FakeBeheerData, filters: Record<string, string> = {}) {
  const zetFilters = vi.fn()
  render(<Screening data={data} filters={filters} zetFilters={zetFilters} nu={() => NU} />)
  return zetFilters
}

describe('D2 screening', () => {
  it('toont tegels en de wachtrij, oudste aanvraag eerst', async () => {
    const data = new FakeBeheerData(
      {
        profielen: [
          profiel({ id: 'p1', naam: 'Nieuwste', bijgewerktOp: '2026-09-18T10:00:00.000Z' }),
          profiel({ id: 'p2', naam: 'Oudste', bijgewerktOp: '2026-09-10T10:00:00.000Z' }),
          profiel({ id: 'p3', naam: 'Klaar', verificatiestatus: 'goedgekeurd', vogStatus: 'goedgekeurd' }),
          profiel({ id: 'p4', naam: 'Nee', verificatiestatus: 'afgewezen', vogStatus: 'nieuw', bijgewerktOp: '2026-09-02T10:00:00.000Z' }),
        ],
      },
      COORDINATOR,
    )
    opzet(data)

    const lijst = await screen.findByRole('button', { name: 'Bekijk Oudste' })
    expect(lijst).toBeInTheDocument()
    expect(screen.getByRole('article', { name: 'Wachtend op beoordeling' })).toHaveTextContent('2')
    expect(screen.getByRole('article', { name: 'VOG loopt' })).toHaveTextContent('2')
    expect(screen.getByRole('article', { name: 'Afgewezen deze maand' })).toHaveTextContent('1')
    const knoppen = screen.getAllByRole('button', { name: /^Bekijk/ })
    expect(knoppen.map((k) => k.textContent)).toEqual(['Bekijk Oudste', 'Bekijk Nieuwste'])
  })

  it('geeft het VOG-signaal binnen 60 dagen', async () => {
    const data = new FakeBeheerData(
      {
        profielen: [
          profiel({ id: 'p1', naam: 'Bijna', verificatiestatus: 'goedgekeurd', vogGeldigTot: '2026-10-20' }),
          profiel({ id: 'p2', naam: 'Ruim', verificatiestatus: 'goedgekeurd', vogGeldigTot: '2027-06-01' }),
        ],
      },
      COORDINATOR,
    )
    opzet(data, { lijst: 'signalen' })

    expect(await screen.findByText(/VOG verloopt binnen 60 dagen/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Bekijk Bijna' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Bekijk Ruim' })).not.toBeInTheDocument()
  })

  it('toont document en selfie naast elkaar en keurt goed met notitie', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ profielen: [profiel({ id: 'p1' })] }, COORDINATOR)
    opzet(data, { jongere: 'p1' })

    const detail = await screen.findByRole('region', { name: 'Screening van Sami' })
    expect(within(detail).getByRole('img', { name: 'Identiteitsbewijs' })).toHaveAttribute('src', 'https://pb.test/id.jpg?token=t')
    expect(within(detail).getByRole('img', { name: 'Selfie' })).toHaveAttribute('src', 'https://pb.test/selfie.jpg?token=t')
    expect(within(detail).getByText(/NL91ABNA0417164300/)).toBeInTheDocument()

    await user.click(within(detail).getByRole('button', { name: 'Goedkeuren' }))
    expect(within(detail).getByRole('alert')).toHaveTextContent('notitie')
    expect(data.aanroepen).toHaveLength(0)

    await user.selectOptions(within(detail).getByLabelText('VOG-status'), 'goedgekeurd')
    await user.type(within(detail).getByLabelText('VOG geldig tot'), '2027-09-01')
    await user.click(within(detail).getByLabelText('IBAN gecontroleerd'))
    expect(within(detail).getByLabelText('Notitie (verplicht)')).toHaveAccessibleDescription(
      'De jongere kan deze notitie lezen. Schrijf hem zakelijk.',
    )
    await user.type(within(detail).getByLabelText('Notitie (verplicht)'), 'Alles klopt.')
    await user.click(within(detail).getByRole('button', { name: 'Goedkeuren' }))

    expect(await within(detail).findByRole('status')).toHaveTextContent('Sami is goedgekeurd.')
    expect(data.aanroepen[0]).toEqual({
      methode: 'beoordeel',
      args: [
        'p1',
        {
          verificatiestatus: 'goedgekeurd',
          screening_notitie: 'Alles klopt.',
          vog_status: 'goedgekeurd',
          vog_geldig_tot: '2027-09-01 12:00:00.000Z',
          iban_geverifieerd: true,
        },
      ],
    })
  })

  it('keurt af met notitie', async () => {
    const user = userEvent.setup()
    const data = new FakeBeheerData({ profielen: [profiel({ id: 'p1', selfieUrl: '' })] }, COORDINATOR)
    opzet(data, { jongere: 'p1' })

    const detail = await screen.findByRole('region', { name: 'Screening van Sami' })
    expect(within(detail).getByText('Geen selfie geüpload.')).toBeInTheDocument()
    await user.type(within(detail).getByLabelText('Notitie (verplicht)'), 'Selfie ontbreekt.')
    await user.click(within(detail).getByRole('button', { name: 'Afkeuren' }))

    expect(await within(detail).findByRole('status')).toHaveTextContent('Sami is afgewezen.')
    expect(data.stand.profielen[0].verificatiestatus).toBe('afgewezen')
  })
})

import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { isVerklaringHash, leesCode, maakCode } from './navigatie'
import { dag } from './teksten'
import { maakVerklaringApi, VerklaringFout, type Verklaring, type VerklaringApi } from './verklaringApi'
import { VerklaringApp } from './VerklaringApp'

const VOORBEELD: Verklaring = {
  code: 'ABCDE-FGH23',
  uitgegeven_op: '2026-10-04 10:00:00.000Z',
  gegevens: {
    voornaam: 'Daan',
    klussen: 5,
    uren: 6.5,
    periode_van: '2026-08-01',
    periode_tot: '2026-09-12',
    niveau: 'Ervaren',
    badges: [{ naam: 'Eerste klus', datum: '2026-08-01' }],
    vertrouwen: [{ naam: 'VOG gezien', datum: '2026-08-20' }],
  },
}

function nepApi(uitkomst: Verklaring | Error): VerklaringApi & { gevraagd: string[] } {
  const gevraagd: string[] = []
  return {
    gevraagd,
    opzoeken: async (code) => {
      gevraagd.push(code)
      if (uitkomst instanceof Error) throw uitkomst
      return uitkomst
    },
  }
}

describe('verklaring-navigatie', () => {
  it('herkent #/verklaring en leest een geldige code', () => {
    expect(isVerklaringHash('#/verklaring')).toBe(true)
    expect(isVerklaringHash('#/verklaring/ABCDE-FGH23')).toBe(true)
    expect(isVerklaringHash('#/verklaringen')).toBe(false)
    expect(leesCode('#/verklaring/abcde-fgh23')).toBe('ABCDE-FGH23')
    expect(leesCode('#/verklaring/ABCDE%20FGH23')).toBe('ABCDE-FGH23')
    expect(leesCode('#/verklaring')).toBe('')
    expect(leesCode('#/verklaring/<script>')).toBe('')
    // O is geen geldig teken (verwarring met 0).
    expect(maakCode('ABCDE-FGH2O')).toBe('')
    expect(dag('2026-10-01')).toBe('1 oktober 2026')
    expect(dag('')).toBe('')
  })
})

describe('verklaringApi', () => {
  it('GET op de publieke route, met nette waarden', async () => {
    const fetchFn = vi.fn(async () => new Response(JSON.stringify(VOORBEELD), { status: 200 }))
    const api = maakVerklaringApi('https://api.voorbeeld.nl/', fetchFn)
    const v = await api.opzoeken('ABCDE-FGH23')
    expect(fetchFn).toHaveBeenCalledWith('https://api.voorbeeld.nl/api/hh/verklaring/ABCDE-FGH23', { method: 'GET' })
    expect(v.gegevens.voornaam).toBe('Daan')
  })

  it('404 en geen verbinding geven een nette melding', async () => {
    const onbekend = maakVerklaringApi('x', async () =>
      new Response(JSON.stringify({ melding: 'Deze code kennen we niet.', reden: 'onbekend' }), { status: 404 }),
    )
    await expect(onbekend.opzoeken('ZZZZZ-ZZZZZ')).rejects.toMatchObject({ status: 404, reden: 'onbekend', message: 'Deze code kennen we niet.' })
    const weg = maakVerklaringApi('x', async () => {
      throw new TypeError('netwerk')
    })
    await expect(weg.opzoeken('ZZZZZ-ZZZZZ')).rejects.toBeInstanceOf(VerklaringFout)
  })
})

describe('VerklaringApp', () => {
  it('toont de verklaring met voornaam, periode, uren, badges en de code; printen kan', async () => {
    const print = vi.spyOn(window, 'print').mockImplementation(() => {})
    const api = nepApi(VOORBEELD)
    render(<VerklaringApp api={api} code="ABCDE-FGH23" />)
    expect(await screen.findByText('Daan hielp buren via HeitjeHulp met 5 klussen.')).toBeInTheDocument()
    expect(screen.getByText('Van 1 augustus 2026 tot 12 september 2026')).toBeInTheDocument()
    expect(screen.getByText('Ongeveer 6,5 uur')).toBeInTheDocument()
    expect(screen.getByText('Eerste klus')).toBeInTheDocument()
    expect(screen.getByText('VOG gezien')).toBeInTheDocument()
    expect(screen.getByText('ABCDE-FGH23')).toBeInTheDocument()
    expect(screen.getByRole('heading', { level: 1, name: 'Verklaring van inzet' })).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Printen of opslaan als pdf' }))
    expect(print).toHaveBeenCalled()
    expect(api.gevraagd).toEqual(['ABCDE-FGH23'])
  })

  it('onbekende code: de melding van de server en opnieuw invullen', async () => {
    const naar = vi.fn()
    render(<VerklaringApp api={nepApi(new VerklaringFout(404, 'onbekend', 'Deze code kennen we niet.'))} code="ZZZZZ-ZZZZZ" opNaarCode={naar} />)
    expect(await screen.findByRole('alert')).toHaveTextContent('Deze code kennen we niet.')
    await userEvent.type(screen.getByLabelText('Controlecode'), 'abcde fgh23')
    await userEvent.click(screen.getByRole('button', { name: 'Nakijken' }))
    expect(naar).toHaveBeenCalledWith('ABCDE-FGH23')
  })

  it('zonder code: invullen; een ongeldige code geeft uitleg, geen verzoek', async () => {
    const api = nepApi(VOORBEELD)
    const naar = vi.fn()
    render(<VerklaringApp api={api} code="" opNaarCode={naar} />)
    expect(screen.getByRole('heading', { level: 1, name: 'Een verklaring nakijken' })).toBeInTheDocument()
    await userEvent.type(screen.getByLabelText('Controlecode'), '123')
    await userEvent.click(screen.getByRole('button', { name: 'Nakijken' }))
    expect(screen.getByRole('alert')).toHaveTextContent('10 tekens')
    expect(naar).not.toHaveBeenCalled()
    expect(api.gevraagd).toEqual([])
  })
})

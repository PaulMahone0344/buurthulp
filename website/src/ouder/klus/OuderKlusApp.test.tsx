import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { NepOuderKlusApi } from './nepOuderKlusApi'
import { OuderKlusApp } from './OuderKlusApp'

const TOKEN = 'G5s0s47LuoHEw524DgsuMibNsouvG0vH4sw7SZmY'

function opzet(api: NepOuderKlusApi, token = TOKEN) {
  render(<OuderKlusApp api={api} token={token} />)
  return userEvent.setup()
}

describe('ouder keurt een klus (B5, #/ouder/klus)', () => {
  it('toont wat, waar (zonder huisnummer), wanneer en de voornaam van de bewoner', async () => {
    const api = new NepOuderKlusApi({ token: TOKEN })
    opzet(api)
    expect(await screen.findByRole('heading', { level: 1, name: 'Daan wil helpen bij een klus' })).toBeInTheDocument()
    expect(screen.getByText('Tuin')).toBeInTheDocument()
    expect(screen.getByText('Onkruid wieden tussen de tegels.')).toBeInTheDocument()
    expect(screen.getByText('Kerkstraat, Tiel')).toBeInTheDocument()
    expect(screen.getByText('zaterdag 10 oktober om 10:00')).toBeInTheDocument()
    expect(screen.getByText('Anja')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Goed' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Liever niet' })).toBeInTheDocument()
    expect(document.body.textContent ?? '').not.toMatch(/\d{4}\s?[A-Z]{2}|Kerkstraat \d/)
    expect(api.aanroepen[0]).toEqual({ route: 'klus', body: { token: TOKEN } })
  })

  it('"Goed" -> de bewoner ziet de reactie nu', async () => {
    const api = new NepOuderKlusApi({ token: TOKEN })
    const user = opzet(api)
    await user.click(await screen.findByRole('button', { name: 'Goed' }))
    expect(await screen.findByRole('heading', { name: 'Dank je. Je koos "Goed".' })).toBeInTheDocument()
    expect(screen.getByText(/De bewoner ziet nu de reactie van Daan/)).toBeInTheDocument()
    expect(api.aanroepen[1]).toEqual({ route: 'klus/besluit', body: { token: TOKEN, besluit: 'goed' } })
  })

  it('"Liever niet" -> de bewoner ziet niets', async () => {
    const api = new NepOuderKlusApi({ token: TOKEN })
    const user = opzet(api)
    await user.click(await screen.findByRole('button', { name: 'Liever niet' }))
    expect(await screen.findByRole('heading', { name: 'Helder. Je koos "Liever niet".' })).toBeInTheDocument()
    expect(screen.getByText(/De bewoner ziet de reactie niet/)).toBeInTheDocument()
  })

  it('eerste klus: "jij gaat mee" staat erbij', async () => {
    opzet(new NepOuderKlusApi({ token: TOKEN, ouderGaatMee: true }))
    expect(await screen.findByText(/Daan gaf aan dat jij meegaat/)).toBeInTheDocument()
  })

  it('verlopen (klus begonnen of al vergeven): geen knoppen meer', async () => {
    opzet(new NepOuderKlusApi({ token: TOKEN, status: 'verlopen' }))
    expect(await screen.findByRole('heading', { name: 'Deze vraag is verlopen' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Goed' })).not.toBeInTheDocument()
  })

  it('al gekozen: de stand blijft staan bij opnieuw openen', async () => {
    opzet(new NepOuderKlusApi({ token: TOKEN, status: 'goed' }))
    expect(await screen.findByRole('heading', { name: 'Dank je. Je koos "Goed".' })).toBeInTheDocument()
  })

  it('een oude of foute link: de melding van de server', async () => {
    opzet(new NepOuderKlusApi({ token: TOKEN }), 'AndereTokenVanTwintigTekens1')
    expect(await screen.findByRole('alert')).toHaveTextContent('Deze link werkt niet meer.')
  })

  it('zonder token: uitleg, geen verzoek', async () => {
    const api = new NepOuderKlusApi({ token: TOKEN })
    opzet(api, '')
    expect(screen.getByRole('alert')).toHaveTextContent('Open de link uit de mail van HeitjeHulp opnieuw.')
    expect(api.aanroepen).toHaveLength(0)
  })

  it('de kop krijgt focus (schermlezer hoort de vraag)', async () => {
    opzet(new NepOuderKlusApi({ token: TOKEN }))
    const kop = await screen.findByRole('heading', { level: 1 })
    expect(kop).toHaveFocus()
  })
})

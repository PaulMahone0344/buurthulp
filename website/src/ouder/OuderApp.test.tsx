import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { OuderApp } from './OuderApp'
import { NepOuderApi } from './nepOuderApi'

const GOEDE_CODE = '482913'

function opzet(api: NepOuderApi, token = '') {
  render(<OuderApp api={api} token={token} />)
  return userEvent.setup()
}

async function vulCodeIn(user: ReturnType<typeof userEvent.setup>, email: string, code: string) {
  await user.type(screen.getByLabelText('Je e-mailadres'), email)
  await user.click(screen.getByLabelText('Cijfer 1'))
  await user.paste(code)
  await user.click(screen.getByRole('button', { name: 'Verder' }))
}

async function vulToestemmingIn(user: ReturnType<typeof userEvent.setup>, { avp = true } = {}) {
  await user.type(screen.getByLabelText('Rekeningnummer voor uitbetaling (IBAN)'), 'NL91 ABNA 0417 1643 00')
  await user.type(screen.getByLabelText('Je naam'), 'Anna Verhoeven')
  await user.click(screen.getByLabelText(/Ik geef toestemming dat Daan helper wordt/))
  if (avp) await user.click(screen.getByLabelText(/Ik heb een aansprakelijkheidsverzekering \(AVP\)/))
  await user.click(screen.getByRole('button', { name: 'Toestemming geven' }))
}

describe('ouder-pagina zonder link: e-mail + code', () => {
  it('stap 1 toont uitleg, e-mail en 6 vakjes; plakken vult alle vakjes', async () => {
    const user = opzet(new NepOuderApi({ code: GOEDE_CODE }))
    expect(screen.getByText('Stap 1 van 2')).toBeInTheDocument()
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Je kind wil helper worden bij HeitjeHulp')
    expect(screen.getByText(/HeitjeHulp brengt buren en helpers samen/)).toBeInTheDocument()
    expect(screen.getByText(/De code is 24 uur geldig/)).toBeInTheDocument()
    await user.click(screen.getByLabelText('Cijfer 1'))
    await user.paste('48 29-13')
    const vakjes = [1, 2, 3, 4, 5, 6].map((i) => screen.getByLabelText(`Cijfer ${i}`) as HTMLInputElement)
    expect(vakjes.map((v) => v.value).join('')).toBe(GOEDE_CODE)
  })

  it('cijfer typen springt door, letters tellen niet, backspace gaat terug', async () => {
    const user = opzet(new NepOuderApi({ code: GOEDE_CODE }))
    await user.click(screen.getByLabelText('Cijfer 1'))
    await user.keyboard('4a8')
    expect((screen.getByLabelText('Cijfer 1') as HTMLInputElement).value).toBe('4')
    expect((screen.getByLabelText('Cijfer 2') as HTMLInputElement).value).toBe('8')
    expect(screen.getByLabelText('Cijfer 3')).toHaveFocus()
    await user.keyboard('{Backspace}')
    expect(screen.getByLabelText('Cijfer 2')).toHaveFocus()
  })

  it('goede code -> stap 2 met de voornaam', async () => {
    const api = new NepOuderApi({ code: GOEDE_CODE })
    const user = opzet(api)
    await vulCodeIn(user, 'mama@voorbeeld.nl', GOEDE_CODE)
    expect(await screen.findByRole('heading', { name: 'Geef toestemming voor Daan' })).toBeInTheDocument()
    expect(screen.getByText('Stap 2 van 2')).toBeInTheDocument()
    expect(api.aanroepen[0]).toEqual({ route: 'code', body: { email: 'mama@voorbeeld.nl', code: GOEDE_CODE } })
  })

  it('foute code: de melding van de server, je blijft op stap 1', async () => {
    const user = opzet(new NepOuderApi({ code: GOEDE_CODE }))
    await vulCodeIn(user, 'mama@voorbeeld.nl', '000000')
    expect(await screen.findByRole('alert')).toHaveTextContent('Deze code klopt niet')
    expect(screen.getByText('Stap 1 van 2')).toBeInTheDocument()
  })

  it('onvolledige invoer: eerst zelf melden, niets naar de server', async () => {
    const api = new NepOuderApi({ code: GOEDE_CODE })
    const user = opzet(api)
    await user.type(screen.getByLabelText('Je e-mailadres'), 'mama@voorbeeld.nl')
    await user.click(screen.getByRole('button', { name: 'Verder' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Vul de code van 6 cijfers in.')
    expect(api.aanroepen).toEqual([])
  })
})

describe('ouder-pagina met de link uit de mail', () => {
  it('geldige link slaat de code-stap over', async () => {
    const api = new NepOuderApi({ code: GOEDE_CODE, token: 'tok' })
    opzet(api, 'tok')
    expect(await screen.findByRole('heading', { name: 'Geef toestemming voor Daan' })).toBeInTheDocument()
    expect(screen.queryByLabelText('Cijfer 1')).not.toBeInTheDocument()
    expect(api.aanroepen[0]).toEqual({ route: 'code', body: { token: 'tok' } })
  })

  it('stap 2 toont de 4 punten, IBAN-uitleg en de AVP-uitleg', async () => {
    opzet(new NepOuderApi({ code: GOEDE_CODE, token: 'tok' }), 'tok')
    const punten = await screen.findByRole('region', { name: 'Wat je moet weten' })
    expect(within(punten).getAllByRole('listitem')).toHaveLength(4)
    expect(punten).toHaveTextContent('Jij blijft verantwoordelijk voor Daan.')
    expect(punten).toHaveTextContent('Je kunt je toestemming altijd intrekken via de link in de mail.')
    expect(screen.getByText(/Mag ook de rekening van Daan zelf zijn/)).toBeInTheDocument()
    expect(screen.getByText(/Een AVP betaalt als Daan per ongeluk iets kapotmaakt/)).toBeInTheDocument()
  })

  it('zonder vinkje akkoord of met een foute IBAN gaat er niets naar de server', async () => {
    const api = new NepOuderApi({ code: GOEDE_CODE, token: 'tok' })
    const user = opzet(api, 'tok')
    await screen.findByRole('heading', { name: 'Geef toestemming voor Daan' })
    await user.type(screen.getByLabelText('Rekeningnummer voor uitbetaling (IBAN)'), 'NL91 ABNA 0417 1643 01')
    await user.type(screen.getByLabelText('Je naam'), 'Anna')
    await user.click(screen.getByRole('button', { name: 'Toestemming geven' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Zet het vinkje om toestemming te geven.')
    await user.click(screen.getByLabelText(/Ik geef toestemming dat Daan helper wordt/))
    await user.click(screen.getByRole('button', { name: 'Toestemming geven' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Vul een geldig Nederlands rekeningnummer (IBAN) in.')
    expect(api.aanroepen).toHaveLength(1)
  })

  it('toestemming geven -> klaar; daarna intrekken met de link', async () => {
    const api = new NepOuderApi({ code: GOEDE_CODE, token: 'tok' })
    const user = opzet(api, 'tok')
    await screen.findByRole('heading', { name: 'Geef toestemming voor Daan' })
    await vulToestemmingIn(user)
    expect(await screen.findByRole('heading', { name: 'Bedankt! Je toestemming is binnen.' })).toBeInTheDocument()
    expect(api.aanroepen[1]).toEqual({
      route: 'toestemming',
      body: { sessie: 'sessie-1', naam: 'Anna Verhoeven', iban: 'NL91ABNA0417164300', akkoord: true, avp: true },
    })
    await user.click(screen.getByRole('button', { name: 'Toestemming intrekken' }))
    const vraag = screen.getByRole('dialog', { name: 'Toestemming intrekken?' })
    await user.click(within(vraag).getByRole('button', { name: 'Ja, intrekken' }))
    expect(await screen.findByRole('heading', { name: 'Je toestemming is ingetrokken' })).toBeInTheDocument()
    expect(api.aanroepen[2]).toEqual({ route: 'intrekken', body: { token: 'tok' } })
  })

  it('intrekken kun je nog afbreken', async () => {
    const api = new NepOuderApi({ code: GOEDE_CODE, token: 'tok', status: 'gegeven' })
    const user = opzet(api, 'tok')
    await user.click(await screen.findByRole('button', { name: 'Toestemming intrekken' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Nee, terug' }))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(api.aanroepen.map((a) => a.route)).toEqual(['code'])
  })

  it('via de code (geen link) trekt de ouder in met de sessie', async () => {
    const api = new NepOuderApi({ code: GOEDE_CODE })
    const user = opzet(api)
    await vulCodeIn(user, 'mama@voorbeeld.nl', GOEDE_CODE)
    await screen.findByRole('heading', { name: 'Geef toestemming voor Daan' })
    await vulToestemmingIn(user, { avp: false })
    await user.click(await screen.findByRole('button', { name: 'Toestemming intrekken' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Ja, intrekken' }))
    await screen.findByRole('heading', { name: 'Je toestemming is ingetrokken' })
    expect(api.aanroepen.at(-1)).toEqual({ route: 'intrekken', body: { sessie: 'sessie-1' } })
    expect(api.aanroepen[1].body).toMatchObject({ avp: false })
  })

  it('link na toestemming: direct "klaar" met intrekken', async () => {
    opzet(new NepOuderApi({ code: GOEDE_CODE, token: 'tok', status: 'gegeven' }), 'tok')
    expect(await screen.findByRole('heading', { name: 'Je hebt toestemming gegeven voor Daan' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Toestemming intrekken' })).toBeInTheDocument()
  })

  it('verlopen link: uitleg om een nieuwe mail te vragen', async () => {
    opzet(new NepOuderApi({ code: GOEDE_CODE, token: 'tok', status: 'verlopen' }), 'tok')
    expect(await screen.findByRole('heading', { name: 'Deze code is verlopen' })).toBeInTheDocument()
    expect(screen.getByText(/Vraag Daan om in de app een nieuwe code te sturen/)).toBeInTheDocument()
  })

  it('ingetrokken link: dat staat er', async () => {
    opzet(new NepOuderApi({ code: GOEDE_CODE, token: 'tok', status: 'ingetrokken' }), 'tok')
    expect(await screen.findByRole('heading', { name: 'Je toestemming is ingetrokken' })).toBeInTheDocument()
  })

  it('onbekende of oude link: melding en de code-stap', async () => {
    opzet(new NepOuderApi({ code: GOEDE_CODE, token: 'nieuw' }), 'oud')
    expect(await screen.findByRole('alert')).toHaveTextContent('Deze link werkt niet meer')
    expect(screen.getByLabelText('Cijfer 1')).toBeInTheDocument()
  })
})

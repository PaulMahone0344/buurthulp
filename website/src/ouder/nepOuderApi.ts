// B3 — nep-API voor de tests van de ouder-pagina: gedraagt zich als de
// hook-routes (zelfde meldingen en redenen), zonder server.

import { OuderFout, type CodeInvoer, type IntrekInvoer, type OuderApi, type OuderStand, type OuderStatus, type ToestemmingInvoer } from './ouderApi'

type Opties = { code: string; token?: string; status?: OuderStatus; voornaam?: string }

export class NepOuderApi implements OuderApi {
  readonly aanroepen: { route: string; body: object }[] = []
  private status: OuderStatus
  private sessies = 0
  private readonly opties: Opties

  constructor(opties: Opties) {
    this.opties = opties
    this.status = opties.status ?? 'verstuurd'
  }

  private stand(extra: Partial<OuderStand> = {}): OuderStand {
    return { status: this.status, voornaam: this.opties.voornaam ?? 'Daan', ...extra }
  }

  async code(invoer: CodeInvoer): Promise<OuderStand> {
    this.aanroepen.push({ route: 'code', body: invoer })
    if ('token' in invoer) {
      if (invoer.token !== this.opties.token) {
        throw new OuderFout(404, 'link', 'Deze link werkt niet meer. Gebruik de link uit de nieuwste mail.')
      }
      return this.status === 'verstuurd' ? this.stand({ sessie: `sessie-${++this.sessies}` }) : this.stand()
    }
    if (invoer.code !== this.opties.code || this.status !== 'verstuurd') {
      throw new OuderFout(400, 'code', 'Deze code klopt niet. Kijk de code en je e-mailadres na.')
    }
    return this.stand({ sessie: `sessie-${++this.sessies}` })
  }

  async toestemming(invoer: ToestemmingInvoer): Promise<OuderStand> {
    this.aanroepen.push({ route: 'toestemming', body: invoer })
    this.status = 'gegeven'
    return this.stand({ avp: invoer.avp, gegeven_op: '2026-10-04 10:00:00.000Z' })
  }

  async intrekken(invoer: IntrekInvoer): Promise<OuderStand> {
    this.aanroepen.push({ route: 'intrekken', body: invoer })
    this.status = 'ingetrokken'
    return this.stand()
  }
}

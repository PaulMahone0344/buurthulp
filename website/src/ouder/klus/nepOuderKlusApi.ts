// B5 — nep-API voor de tests van de ouder-kluspagina: gedraagt zich als de
// hook-routes (zelfde meldingen en redenen), zonder server.

import { OuderFout } from '../ouderApi'
import type { Besluit, KlusStatus, OuderKlusApi, OuderKlusStand } from './ouderKlusApi'

type Opties = { token: string; status?: KlusStatus; ouderGaatMee?: boolean }

export class NepOuderKlusApi implements OuderKlusApi {
  readonly aanroepen: { route: string; body: object }[] = []
  private status: KlusStatus
  private readonly opties: Opties

  constructor(opties: Opties) {
    this.opties = opties
    this.status = opties.status ?? 'wacht'
  }

  private huidig(): OuderKlusStand {
    return {
      status: this.status,
      helper_voornaam: 'Daan',
      ouder_gaat_mee: this.opties.ouderGaatMee ?? false,
      klus: {
        wat: 'Tuin',
        omschrijving: 'Onkruid wieden tussen de tegels.',
        waar: 'Kerkstraat, Tiel',
        wanneer: 'zaterdag 10 oktober om 10:00',
        bewoner_voornaam: 'Anja',
      },
    }
  }

  private controleer(token: string) {
    if (token !== this.opties.token) {
      throw new OuderFout(404, 'link', 'Deze link werkt niet meer. Gebruik de link uit de nieuwste mail.')
    }
  }

  async stand(token: string): Promise<OuderKlusStand> {
    this.aanroepen.push({ route: 'klus', body: { token } })
    this.controleer(token)
    return this.huidig()
  }

  async besluit(token: string, besluit: Besluit): Promise<OuderKlusStand> {
    this.aanroepen.push({ route: 'klus/besluit', body: { token, besluit } })
    this.controleer(token)
    if (this.status === 'wacht') this.status = besluit
    return this.huidig()
  }
}

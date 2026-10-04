// M14 — vaste testdata voor de componenttests van het beheerpaneel.

import type { Incident, Klus, KlusNaTeKijken, Profiel } from './data/types'

export const NU = new Date('2026-09-19T14:00:00.000Z')
export const COORDINATOR = { id: 'c1', naam: 'Coordinator Een', email: 'coord@heitjehulp.nl' }

export function klus(o: Partial<Klus>): Klus {
  return {
    id: 'k',
    status: 'open',
    bron: 'app',
    omschrijving: '',
    adres: 'Kerkstraat 1',
    aangemaaktOp: '2026-09-19T13:00:00.000Z',
    wanneerVan: '2026-09-19T08:00:00.000Z',
    wanneerTot: '2026-09-19T09:00:00.000Z',
    hulpvragerId: 'o1',
    hulpvragerNaam: 'Mevrouw Jansen',
    hulpvragerTelefoon: '0612345678',
    hulpvragerWijkNaam: 'Tiel-West',
    jongereId: '',
    jongereNaam: '',
    klustypeId: 't1',
    klustypeNaam: 'boodschappen',
    bedragBruto: 1000,
    vergoedingJongere: 1000,
    commissie: 0,
    ...o,
  }
}

export function incident(o: Partial<Incident>): Incident {
  return {
    id: 'i',
    gemeldOp: '2026-09-19T12:00:00.000Z',
    soort: 'probleem',
    omschrijving: 'Jongere kwam niet',
    afhandeling: '',
    melderId: 'o1',
    melderNaam: 'Mevrouw Jansen',
    melderTelefoon: '0612345678',
    klusId: 'k1',
    ...o,
  }
}

export function profiel(o: Partial<Profiel>): Profiel {
  return {
    id: 'p1',
    gebruikerId: 'j1',
    naam: 'Sami',
    email: 'sami@example.nl',
    wijkNaam: 'Tiel-West',
    verificatiestatus: 'in_behandeling',
    vogStatus: 'in_behandeling',
    vogGeldigTot: '',
    vogAangevraagdOp: '2026-09-10T10:00:00.000Z',
    vogGezienOp: '',
    ibanGeverifieerd: false,
    iban: 'NL91ABNA0417164300',
    overMij: 'Ik help graag.',
    screeningNotitie: '',
    bijgewerktOp: '2026-09-18T10:00:00.000Z',
    documentFotoUrl: 'https://pb.test/id.jpg?token=t',
    ouderToestemmingOp: '',
    ouderAvp: null,
    ouderStatus: '',
    ...o,
  }
}

export function naTeKijken(o: Partial<KlusNaTeKijken>): KlusNaTeKijken {
  return {
    id: 'n',
    aangemaaktOp: '2026-09-19T12:30:00.000Z',
    bron: 'app',
    hulpvragerNaam: 'Mevrouw Jansen',
    klustypeNaam: 'Tuin',
    minLeeftijd: 13,
    wanneerVan: '2026-09-20T12:00:00.000Z',
    wanneerTot: '',
    omschrijving: 'De heg aan de voorkant knippen.',
    markering: [],
    fotoUrl: 'https://api.test/api/files/hh_klussen/n/heg.jpg?token=t',
    wachtOpKennismaking: false,
    ...o,
  }
}

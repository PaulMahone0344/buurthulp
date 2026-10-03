// M14 — de echte data-laag: PocketBase (VITE_POCKETBASE_URL) en alleen
// hh_-collecties. De rechten zitten in de API-rules op de server; dit bestand
// vertrouwt daar volledig op en verbergt niets "voor de zekerheid".
//
// De omzetfuncties (naarKlus, naarIncident, ...) zijn los geëxporteerd zodat
// ze zonder server te testen zijn.

import PocketBase, { ClientResponseError, type RecordModel } from 'pocketbase'
import { BeheerFout, type BeheerData, type Inlogresultaat } from './beheerData'
import { isVogVerlopen } from './filters'
import { besluitBody } from './screening'
import { nieuweOudereBody, telefonischeKlusBody, willekeurigWachtwoord } from './telefonisch'
import { naarIso } from './tijd'
import type {
  Auditregel,
  Betaling,
  Coordinator,
  Gebruiker,
  Incident,
  Instelling,
  Klus,
  Klustype,
  Koppelkandidaat,
  Oudere,
  Profiel,
  Wijk,
} from './types'

const MELDING_GEEN_COORDINATOR =
  'Dit beheerpaneel is alleen voor coordinatoren. Je bent weer uitgelogd.'
const MELDING_INLOG = 'Controleer je e-mail en wachtwoord.'
const MELDING_VERBINDING = 'De server is niet bereikbaar. Probeer het zo opnieuw.'
const MELDING_GEEN_RECHT = 'Dit mag alleen een coordinator.'

type Uitgebreid = RecordModel & { expand?: Record<string, RecordModel | RecordModel[] | undefined> }

function tekst(waarde: unknown): string {
  return waarde === null || waarde === undefined ? '' : String(waarde)
}

function getal(waarde: unknown): number {
  const n = Number(waarde)
  return Number.isFinite(n) ? n : 0
}

function uitgebreid(record: Uitgebreid, veld: string): Uitgebreid | undefined {
  const waarde = record.expand?.[veld]
  return Array.isArray(waarde) ? (waarde[0] as Uitgebreid | undefined) : (waarde as Uitgebreid | undefined)
}

/** Een json-veld als leesbare tekst (instellingen, auditdetail). */
function jsonTekst(waarde: unknown): string {
  if (waarde === null || waarde === undefined || waarde === '') return ''
  return typeof waarde === 'string' ? waarde : JSON.stringify(waarde)
}

export function naarKlus(r: Uitgebreid): Klus {
  const oudere = uitgebreid(r, 'hulpvrager')
  const jongere = uitgebreid(r, 'toegewezen_jongere')
  const klustype = uitgebreid(r, 'klustype')
  const wijk = oudere ? uitgebreid(oudere, 'wijk') : undefined
  return {
    id: r.id,
    status: tekst(r.status) as Klus['status'],
    bron: tekst(r.bron) as Klus['bron'],
    omschrijving: tekst(r.omschrijving),
    adres: tekst(r.adres),
    aangemaaktOp: naarIso(r.created),
    wanneerVan: naarIso(r.wanneer_van),
    wanneerTot: naarIso(r.wanneer_tot),
    hulpvragerId: tekst(r.hulpvrager),
    hulpvragerNaam: tekst(oudere?.naam),
    hulpvragerTelefoon: tekst(oudere?.telefoon),
    hulpvragerWijkNaam: tekst(wijk?.wijk),
    jongereId: tekst(r.toegewezen_jongere),
    jongereNaam: tekst(jongere?.naam),
    klustypeId: tekst(r.klustype),
    klustypeNaam: tekst(klustype?.naam),
    bedragBruto: getal(r.bedrag_bruto),
    vergoedingJongere: getal(r.vergoeding_jongere),
    commissie: getal(r.commissie),
  }
}

export function naarIncident(r: Uitgebreid): Incident {
  const melder = uitgebreid(r, 'melder')
  return {
    id: r.id,
    gemeldOp: naarIso(r.created),
    soort: tekst(r.soort) as Incident['soort'],
    omschrijving: tekst(r.omschrijving),
    afhandeling: tekst(r.afhandeling),
    melderId: tekst(r.melder),
    melderNaam: tekst(melder?.naam),
    melderTelefoon: tekst(melder?.telefoon),
    klusId: tekst(r.klus),
  }
}

export function naarProfiel(r: Uitgebreid, bestandUrl: (bestand: string) => string): Profiel {
  const gebruiker = uitgebreid(r, 'gebruiker')
  const wijk = gebruiker ? uitgebreid(gebruiker, 'wijk') : undefined
  const document = tekst(r.document_foto)
  return {
    id: r.id,
    gebruikerId: tekst(r.gebruiker),
    naam: tekst(gebruiker?.naam),
    email: tekst(gebruiker?.email),
    wijkNaam: tekst(wijk?.wijk),
    verificatiestatus: tekst(r.verificatiestatus) as Profiel['verificatiestatus'],
    vogStatus: tekst(r.vog_status) as Profiel['vogStatus'],
    vogGeldigTot: naarIso(r.vog_geldig_tot).slice(0, 10),
    vogAangevraagdOp: naarIso(r.vog_aangevraagd_op),
    vogGezienOp: naarIso(r.vog_gezien_op).slice(0, 10),
    ibanGeverifieerd: r.iban_geverifieerd === true,
    iban: tekst(r.iban),
    overMij: tekst(r.over_mij),
    screeningNotitie: tekst(r.screening_notitie),
    bijgewerktOp: naarIso(r.updated),
    documentFotoUrl: document ? bestandUrl(document) : '',
  }
}

export function naarOudere(r: RecordModel): Oudere {
  return {
    id: r.id,
    naam: tekst(r.naam),
    email: tekst(r.email),
    telefoon: tekst(r.telefoon),
    adres: tekst(r.adres),
    postcode: tekst(r.postcode),
    plaats: tekst(r.plaats),
    wijkId: tekst(r.wijk),
  }
}

export function naarWijk(r: RecordModel): Wijk {
  return {
    id: r.id,
    gemeente: tekst(r.gemeente),
    wijk: tekst(r.wijk),
    postcodes: Array.isArray(r.postcodes) ? r.postcodes.map(tekst) : [],
    actief: r.actief === true,
  }
}

export function naarKlustype(r: RecordModel): Klustype {
  return {
    id: r.id,
    naam: tekst(r.naam),
    icoon: tekst(r.icoon),
    richtduur: getal(r.richtduur),
    richtvergoeding: getal(r.richtvergoeding),
  }
}

export function naarGebruiker(r: RecordModel): Gebruiker {
  return {
    id: r.id,
    naam: tekst(r.naam),
    email: tekst(r.email),
    rol: tekst(r.rol) as Gebruiker['rol'],
    telefoon: tekst(r.telefoon),
    geblokkeerd: r.geblokkeerd === true,
  }
}

export function naarInstelling(r: RecordModel): Instelling {
  return { id: r.id, sleutel: tekst(r.sleutel), waarde: jsonTekst(r.waarde) }
}

export function naarBetaling(r: Uitgebreid): Betaling {
  const klus = uitgebreid(r, 'klus')
  return {
    id: r.id,
    klusId: tekst(r.klus),
    klusOmschrijving: tekst(klus?.omschrijving),
    bedrag: getal(r.bedrag),
    status: tekst(r.status) as Betaling['status'],
    betaaldOp: naarIso(r.betaald_op),
  }
}

export function naarAuditregel(r: Uitgebreid): Auditregel {
  const door = uitgebreid(r, 'door')
  return {
    id: r.id,
    gebeurdOp: naarIso(r.created),
    doorId: tekst(r.door),
    doorNaam: tekst(door?.naam),
    actie: tekst(r.actie),
    doelCollectie: tekst(r.doel_collectie),
    doelId: tekst(r.doel_id),
    detail: jsonTekst(r.detail),
  }
}

/** De Nederlandse melding uit een foutantwoord, met een nette terugval. */
export function foutmelding(fout: unknown): string {
  if (fout instanceof BeheerFout) return fout.message
  if (fout instanceof ClientResponseError) {
    const data = (fout.response ?? {}) as { melding?: unknown; message?: unknown }
    if (typeof data.melding === 'string' && data.melding) return data.melding
    if (fout.status === 0) return MELDING_VERBINDING
    if (fout.status === 401 || fout.status === 403 || fout.status === 404) {
      return typeof data.message === 'string' && data.message && fout.status === 403
        ? data.message
        : MELDING_GEEN_RECHT
    }
    if (typeof data.message === 'string' && data.message) return data.message
  }
  return 'Er ging iets mis. Probeer het opnieuw.'
}

async function metFout<T>(werk: () => Promise<T>): Promise<T> {
  try {
    return await werk()
  } catch (fout) {
    throw new BeheerFout(foutmelding(fout))
  }
}

export function naarCoordinator(r: RecordModel | null | undefined): Coordinator | null {
  if (!r || r.collectionName !== 'hh_users' || r.rol !== 'coordinator') return null
  return { id: r.id, naam: tekst(r.naam), email: tekst(r.email) }
}

export function maakPocketbaseBeheerData(pb: PocketBase): BeheerData {
  pb.autoCancellation(false)
  const col = (naam: string) => pb.collection(naam)
  const ikId = () => tekst(pb.authStore.record?.id)

  return {
    async inloggen(email, wachtwoord): Promise<Inlogresultaat> {
      try {
        const antwoord = await col('hh_users').authWithPassword(email.trim(), wachtwoord)
        const coordinator = naarCoordinator(antwoord.record)
        if (!coordinator) {
          pb.authStore.clear()
          return { ok: false, melding: MELDING_GEEN_COORDINATOR }
        }
        return { ok: true, coordinator }
      } catch (fout) {
        pb.authStore.clear()
        if (fout instanceof ClientResponseError && fout.status === 400) {
          const data = (fout.response ?? {}) as { melding?: unknown; message?: unknown }
          // De hook van M14 geeft een geblokkeerde gebruiker een eigen melding.
          if (typeof data.melding === 'string' && data.melding) return { ok: false, melding: data.melding }
          if (typeof data.message === 'string' && data.message.includes('geblokkeerd')) {
            return { ok: false, melding: data.message }
          }
          return { ok: false, melding: MELDING_INLOG }
        }
        return { ok: false, melding: foutmelding(fout) }
      }
    },

    huidige() {
      if (!pb.authStore.isValid) return null
      const coordinator = naarCoordinator(pb.authStore.record)
      if (!coordinator) pb.authStore.clear()
      return coordinator
    },

    uitloggen() {
      pb.authStore.clear()
    },

    klussen: () =>
      metFout(async () =>
        (
          await col('hh_klussen').getFullList({
            sort: '-created',
            expand: 'hulpvrager,hulpvrager.wijk,toegewezen_jongere,klustype',
          })
        ).map(naarKlus),
      ),

    incidenten: () =>
      metFout(async () =>
        (await col('hh_incidenten').getFullList({ sort: '-created', expand: 'melder' })).map(naarIncident),
      ),

    incidentAfhandelen: (id, afhandeling) =>
      metFout(async () => {
        await col('hh_incidenten').update(id, { afhandeling: afhandeling.trim() })
      }),

    abonneer(opWijziging) {
      let gestopt = false
      const afmelders: Array<() => Promise<void>> = []
      for (const naam of ['hh_klussen', 'hh_incidenten']) {
        col(naam)
          .subscribe('*', () => opWijziging())
          .then((afmelden) => {
            if (gestopt) void afmelden().catch(() => undefined)
            else afmelders.push(afmelden)
          })
          .catch(() => undefined)
      }
      return () => {
        gestopt = true
        for (const afmelden of afmelders) void afmelden().catch(() => undefined)
      }
    },

    zoekOuderen: (zoek) =>
      metFout(async () => {
        const q = zoek.trim()
        const filter = q
          ? pb.filter('rol = "hulpvrager" && (naam ~ {:q} || telefoon ~ {:q} || email ~ {:q})', { q })
          : 'rol = "hulpvrager"'
        return (await col('hh_users').getList(1, 20, { filter, sort: 'naam' })).items.map(naarOudere)
      }),

    maakOudere: (oudere) =>
      metFout(async () => naarOudere(await col('hh_users').create(nieuweOudereBody(oudere, willekeurigWachtwoord())))),

    maakTelefonischeKlus: (klus) =>
      metFout(async () => {
        const klustype = naarKlustype(await col('hh_klustypes').getOne(klus.klustypeId))
        const record = await col('hh_klussen').create(telefonischeKlusBody(klus, klustype, ikId()))
        return record.id
      }),

    koppelkandidaten: () =>
      metFout(async () => {
        const profielen = await col('hh_profielen').getFullList({
          filter: 'verificatiestatus = "goedgekeurd" && gebruiker.rol = "jongere"',
          expand: 'gebruiker,gebruiker.wijk',
        })
        return profielen
          .filter((p) => uitgebreid(p as Uitgebreid, 'gebruiker')?.geblokkeerd !== true)
          // Besluit 2 okt: verlopen VOG = niet koppelen (de server weigert het ook).
          .filter((p) => !isVogVerlopen(tekst(p.vog_geldig_tot), new Date()))
          .map((p): Koppelkandidaat => {
            const gebruiker = uitgebreid(p as Uitgebreid, 'gebruiker')
            const wijk = gebruiker ? uitgebreid(gebruiker, 'wijk') : undefined
            return {
              id: tekst(p.gebruiker),
              naam: tekst(gebruiker?.naam),
              wijkNaam: tekst(wijk?.wijk),
              klussenAantal: getal(p.klussen_aantal),
            }
          })
      }),

    koppelen: (klusId, jongereId) =>
      metFout(async () => {
        const antwoord = await pb.send<{ andere_wijk?: boolean }>(
          `/api/hh/klussen/${encodeURIComponent(klusId)}/koppelen`,
          { method: 'POST', body: { jongere: jongereId } },
        )
        return { andereWijk: antwoord?.andere_wijk === true }
      }),

    vrijgeven: (klusId, reden) =>
      metFout(async () => {
        await pb.send(`/api/hh/klussen/${encodeURIComponent(klusId)}/vrijgeven`, {
          method: 'POST',
          body: { reden: reden.trim() },
        })
      }),

    annuleren: (klusId, reden) =>
      metFout(async () => {
        await pb.send(`/api/hh/klussen/${encodeURIComponent(klusId)}/annuleren`, {
          method: 'POST',
          body: { reden: reden.trim() },
        })
      }),

    profielen: () =>
      metFout(async () => {
        const records = await col('hh_profielen').getFullList({
          filter: 'gebruiker.rol = "jongere"',
          sort: '-updated',
          expand: 'gebruiker,gebruiker.wijk',
        })
        // document_foto is PROTECTED: zonder bestandstoken 404.
        const token = records.length ? await pb.files.getToken() : ''
        return records.map((r) => naarProfiel(r, (bestand) => pb.files.getURL(r, bestand, { token })))
      }),

    beoordeel: (profielId, besluit) =>
      metFout(async () => {
        await col('hh_profielen').update(profielId, besluitBody(besluit))
      }),

    wijken: () => metFout(async () => (await col('hh_wijken').getFullList({ sort: 'gemeente,wijk' })).map(naarWijk)),
    maakWijk: (wijk) =>
      metFout(async () => {
        await col('hh_wijken').create(wijk)
      }),
    wijzigWijk: (id, wijk) =>
      metFout(async () => {
        await col('hh_wijken').update(id, wijk)
      }),

    klustypes: () =>
      metFout(async () => (await col('hh_klustypes').getFullList({ sort: 'naam' })).map(naarKlustype)),
    maakKlustype: (klustype) =>
      metFout(async () => {
        await col('hh_klustypes').create(klustype)
      }),
    wijzigKlustype: (id, klustype) =>
      metFout(async () => {
        await col('hh_klustypes').update(id, klustype)
      }),

    zoekGebruikers: (zoek) =>
      metFout(async () => {
        const q = zoek.trim()
        const filter = q ? pb.filter('naam ~ {:q} || email ~ {:q} || telefoon ~ {:q}', { q }) : ''
        return (await col('hh_users').getList(1, 50, { filter, sort: 'naam' })).items.map(naarGebruiker)
      }),
    wijzigRol: (id, rol) =>
      metFout(async () => {
        await col('hh_users').update(id, { rol })
      }),
    zetGeblokkeerd: (id, geblokkeerd) =>
      metFout(async () => {
        await col('hh_users').update(id, { geblokkeerd })
      }),

    instellingen: () =>
      metFout(async () => (await col('hh_instellingen').getFullList({ sort: 'sleutel' })).map(naarInstelling)),
    slaInstellingOp: (sleutel, waarde) =>
      metFout(async () => {
        let json: unknown
        try {
          json = JSON.parse(waarde)
        } catch {
          json = waarde
        }
        const bestaand = await col('hh_instellingen').getFullList({
          filter: pb.filter('sleutel = {:sleutel}', { sleutel }),
        })
        if (bestaand[0]) await col('hh_instellingen').update(bestaand[0].id, { waarde: json })
        else await col('hh_instellingen').create({ sleutel, waarde: json })
      }),

    betalingen: () =>
      metFout(async () =>
        (await col('hh_betalingen').getFullList({ sort: '-created', expand: 'klus' })).map(naarBetaling),
      ),

    auditlog: () =>
      metFout(async () =>
        (await col('hh_auditlog').getList(1, 500, { sort: '-created', expand: 'door' })).items.map(naarAuditregel),
      ),
  }
}

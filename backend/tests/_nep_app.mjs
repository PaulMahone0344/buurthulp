// HeitjeHulp B5 — nep-app voor de tests van hh_reacties_hulp.js (GEEN test:
// node --test draait alleen *.test.mjs). Records in het geheugen, een klein
// filter (&&, ||, haakjes, = != > >= < <= ~, {:param}, "tekst", getallen,
// true/false, relaties met een punt: klus.wanneer_van), sorteren op één veld
// en runInTransaction. Genoeg om de hulp zonder server te toetsen; de echte
// rules en de echte PocketBase bewijst 132-b5check.mjs.

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));

/// Laadt een hulpbestand uit pb_hooks zoals de JSVM (module.exports). Een
/// require() binnen het bestand (B5: hh_reacties_basis.js) laadt het andere
/// hulpbestand op dezelfde manier; __hooks bestaat hier niet.
const geladen = new Map();
export function laadHulp(naam) {
  if (geladen.has(naam)) return geladen.get(naam);
  const bron = readFileSync(path.join(hier, '..', 'pb_hooks', naam), 'utf8');
  const module_ = { exports: {} };
  const eis = (pad) => laadHulp(path.basename(pad));
  new Function('module', 'exports', 'require', bron)(module_, module_.exports, eis);
  geladen.set(naam, module_.exports);
  return module_.exports;
}

/// Welke relatie naar welke collectie wijst (voor "klus.wanneer_van").
const RELATIES = {
  hh_reacties: { klus: 'hh_klussen', helper: 'hh_users' },
  hh_klussen: { hulpvrager: 'hh_users', toegewezen_jongere: 'hh_users', klustype: 'hh_klustypes', geplaatst_door: 'hh_users' },
  hh_profielen: { gebruiker: 'hh_users' },
  hh_beoordelingen: { klus: 'hh_klussen', van_gebruiker: 'hh_users', naar_gebruiker: 'hh_users' },
  hh_meldingen: { ontvanger: 'hh_users', klus: 'hh_klussen' },
  hh_klus_status: { klus: 'hh_klussen', door: 'hh_users' },
  hh_incidenten: { klus: 'hh_klussen', melder: 'hh_users' },
  hh_ouder_toestemming: { helper: 'hh_users' },
  hh_users: { wijk: 'hh_wijken' },
};

export class NepRecord {
  constructor(collectie, data = {}) {
    this._collectie = typeof collectie === 'string' ? collectie : collectie.name;
    this.id = data.id || '';
    this.data = { ...data };
    delete this.data.id;
  }
  collection() {
    return { name: this._collectie };
  }
  get(veld) {
    if (veld === 'id') return this.id;
    const v = this.data[veld];
    return v === undefined ? '' : v;
  }
  set(veld, waarde) {
    this.data[veld] = waarde;
  }
  getString(veld) {
    const v = this.get(veld);
    return typeof v === 'string' ? v : JSON.stringify(v);
  }
  getBool(veld) {
    return this.data[veld] === true;
  }
  getInt(veld) {
    return Math.trunc(Number(this.data[veld] || 0));
  }
}

// ---- filter ---------------------------------------------------------------

function tokens(filter) {
  const uit = [];
  const re = /\s*(\(|\)|&&|\|\||!=|>=|<=|\?=|=|>|<|~|\{:[a-zA-Z0-9_]+\}|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|-?\d+(?:\.\d+)?|[a-zA-Z_][a-zA-Z0-9_.]*)/y;
  let m;
  let i = 0;
  while (i < filter.length) {
    re.lastIndex = i;
    m = re.exec(filter);
    if (!m) {
      if (/^\s*$/.test(filter.slice(i))) break;
      throw new Error(`nep-filter snapt dit niet: "${filter.slice(i)}"`);
    }
    uit.push(m[1]);
    i = re.lastIndex;
  }
  return uit;
}

function parse(lijst) {
  let p = 0;
  const kijk = () => lijst[p];
  const neem = () => lijst[p++];
  const of = () => {
    let links = en();
    while (kijk() === '||') {
      neem();
      const rechts = en();
      const l = links;
      links = (ctx) => l(ctx) || rechts(ctx);
    }
    return links;
  };
  const en = () => {
    let links = een();
    while (kijk() === '&&') {
      neem();
      const rechts = een();
      const l = links;
      links = (ctx) => l(ctx) && rechts(ctx);
    }
    return links;
  };
  const een = () => {
    if (kijk() === '(') {
      neem();
      const binnen = of();
      if (neem() !== ')') throw new Error('nep-filter: ) ontbreekt');
      return binnen;
    }
    const a = operand(neem());
    const op = neem();
    const b = operand(neem());
    return (ctx) => vergelijk(a(ctx), op, b(ctx));
  };
  const resultaat = of();
  if (p !== lijst.length) throw new Error(`nep-filter: rest "${lijst.slice(p).join(' ')}"`);
  return resultaat;
}

function operand(t) {
  if (t === undefined) throw new Error('nep-filter: operand ontbreekt');
  if (t.startsWith('{:')) {
    const naam = t.slice(2, -1);
    return (ctx) => {
      if (!(naam in ctx.params)) throw new Error(`nep-filter: param ${naam} ontbreekt`);
      return ctx.params[naam];
    };
  }
  if (t.startsWith('"') || t.startsWith("'")) {
    const w = t.slice(1, -1).replace(/\\(.)/g, '$1');
    return () => w;
  }
  if (/^-?\d/.test(t)) return () => Number(t);
  if (t === 'true') return () => true;
  if (t === 'false') return () => false;
  return (ctx) => ctx.pad(ctx.record, t);
}

function normaal(v) {
  if (v === undefined || v === null) return '';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  return v;
}

function vergelijk(a, op, b) {
  const x = normaal(a);
  const y = normaal(b);
  const getal = typeof x === 'number' && typeof y === 'number';
  const sx = String(x);
  const sy = String(y);
  switch (op) {
    case '=':
    case '?=':
      if (typeof x === 'number' || typeof y === 'number') return Number(x || 0) === Number(y || 0);
      return sx === sy;
    case '!=':
      if (typeof x === 'number' || typeof y === 'number') return Number(x || 0) !== Number(y || 0);
      return sx !== sy;
    case '>':
      return getal ? x > y : sx > sy;
    case '>=':
      return getal ? x >= y : sx >= sy;
    case '<':
      return getal ? x < y : sx < sy;
    case '<=':
      return getal ? x <= y : sx <= sy;
    case '~':
      return sx.includes(sy.replace(/%/g, ''));
    default:
      throw new Error(`nep-filter: onbekende operator ${op}`);
  }
}

// ---- app ------------------------------------------------------------------

export function nepApp(rijen = {}, opties = {}) {
  const db = {};
  for (const [collectie, lijst] of Object.entries(rijen)) {
    db[collectie] = lijst.map((d) => new NepRecord(collectie, d));
  }
  let teller = 0;
  const klok = opties.klok || (() => Date.now());
  const uniek = opties.uniek || { hh_reacties: [['klus', 'helper']] };
  const log = { opgeslagen: [], verwijderd: [], transacties: 0 };

  const zoekId = (collectie, id) => (db[collectie] || []).find((r) => r.id === id) || null;
  const pad = (record, veld) => {
    if (!record) return '';
    const delen = veld.split('.');
    let r = record;
    for (let i = 0; i < delen.length - 1; i++) {
      const doel = (RELATIES[r._collectie] || {})[delen[i]];
      if (!doel) throw new Error(`nep-filter: relatie ${r._collectie}.${delen[i]} onbekend`);
      r = zoekId(doel, String(r.get(delen[i]) || ''));
      if (!r) return '';
    }
    return r.get(delen[delen.length - 1]);
  };
  const sorteer = (lijst, sort) => {
    if (!sort) return lijst;
    const af = sort.startsWith('-');
    const veld = af ? sort.slice(1) : sort;
    return [...lijst].sort((a, b) => {
      const x = String(normaal(a.get(veld)));
      const y = String(normaal(b.get(veld)));
      return af ? (x < y ? 1 : x > y ? -1 : 0) : x < y ? -1 : x > y ? 1 : 0;
    });
  };
  const filteren = (collectie, filter, params) => {
    const lijst = db[collectie] || [];
    if (!filter || !filter.trim()) return [...lijst];
    const f = parse(tokens(filter));
    return lijst.filter((record) => f({ record, params: params || {}, pad }));
  };

  const app = {
    db,
    log,
    findCollectionByNameOrId(naam) {
      return { name: naam };
    },
    findRecordById(collectie, id) {
      const r = zoekId(collectie, id);
      if (!r) throw new Error(`niet gevonden: ${collectie}/${id}`);
      return r;
    },
    findRecordsByFilter(collectie, filter, sort, limit, offset, params) {
      const uit = sorteer(filteren(collectie, filter, params), sort);
      const vanaf = offset || 0;
      return limit ? uit.slice(vanaf, vanaf + limit) : uit.slice(vanaf);
    },
    findFirstRecordByFilter(collectie, filter, params) {
      const uit = filteren(collectie, filter, params);
      if (!uit.length) throw new Error('geen rij');
      return uit[0];
    },
    countRecords(collectie, filter, params) {
      return filteren(collectie, filter, params).length;
    },
    save(record) {
      const collectie = record._collectie;
      db[collectie] = db[collectie] || [];
      for (const velden of uniek[collectie] || []) {
        const dubbel = db[collectie].find(
          (r) => r !== record && r.id !== record.id && velden.every((v) => String(r.get(v)) === String(record.get(v)))
        );
        if (dubbel) throw new Error(`UNIQUE constraint failed: ${collectie}.${velden.join(', ')}`);
      }
      if (!record.id) {
        record.id = `${collectie.replace('hh_', '')}${++teller}`;
        if (!record.data.created) record.data.created = new Date(klok() + teller).toISOString().replace('T', ' ');
        db[collectie].push(record);
      } else if (!db[collectie].includes(record)) {
        const bestaand = db[collectie].findIndex((r) => r.id === record.id);
        if (bestaand >= 0) db[collectie][bestaand] = record;
        else db[collectie].push(record);
      }
      record.data.updated = new Date(klok()).toISOString().replace('T', ' ');
      log.opgeslagen.push(`${collectie}/${record.id}`);
    },
    delete(record) {
      const collectie = record._collectie;
      db[collectie] = (db[collectie] || []).filter((r) => r !== record && r.id !== record.id);
      log.verwijderd.push(`${collectie}/${record.id}`);
    },
    runInTransaction(fn) {
      log.transacties++;
      fn(app);
    },
  };
  return app;
}

/// "2026-10-10 08:00:00.000Z" zoals PocketBase.
export function pbDatum(ms) {
  return new Date(ms).toISOString().replace('T', ' ');
}

// HeitjeHulp B11 — rekenwerk voor hh_meldkamer.pb.js (getest zonder server:
// backend/tests/hh_meldkamer_hulp.test.mjs). Geen $app/Record hier: de hook
// geeft env = { app, Record, nu } mee (nu = ms), de tests een nep-app.
//
//   partnerVoorCode    partnercode bij aanmelden helper -> partner-id
//   kennismaking       meldkamer vinkt het belletje met een nieuwe bewoner
//                      af: gesproken of geweigerd (= blokkeren + open en
//                      concept-klussen zonder helper annuleren)
//   wachtOpKennismaking  keuren (B4) wacht zolang de bewoner niet gesproken is
//                      (alleen met schakelaar b11_kennismaking_verplicht aan)
//   vogWachtrij        helpers 18+ zonder VOG of met verlopen VOG
//   partnerTellers     per partner: aangemeld en goedgekeurd
//   zelfdePaar         signaal (incident soort "signaal", geen alarm) bij de
//                      N-de afgeronde klus van een helper ONDER 18 met
//                      dezelfde bewoner binnen D dagen (b11_zelfde_paar_*)
//
// Gotcha (PB 0.25 JSVM): countRecords werkt niet met een filter-tekst ->
// findRecordsByFilter(...).length. Een json-waarde komt als bytes binnen ->
// getString + JSON.parse.

var INSTELLING = {
  KENNISMAKING: "b11_kennismaking_verplicht",
  PAAR_AAN: "b11_zelfde_paar_aan",
  PAAR_AANTAL: "b11_zelfde_paar_aantal",
  PAAR_DAGEN: "b11_zelfde_paar_dagen",
};
// Wat script 150 als startwaarde in hh_instellingen zet (besluit Ibrahim 4 okt).
var STANDAARD_INSTELLINGEN = [
  { sleutel: INSTELLING.KENNISMAKING, waarde: false },
  { sleutel: INSTELLING.PAAR_AAN, waarde: false },
  { sleutel: INSTELLING.PAAR_AANTAL, waarde: 4 },
  { sleutel: INSTELLING.PAAR_DAGEN, waarde: 30 },
];
var PAAR_AANTAL = 4;
var PAAR_DAGEN = 30;

var KENNISMAKING = { NOG: "nog", GESPROKEN: "gesproken", GEWEIGERD: "geweigerd" };
var KENNISMAKING_STATUSSEN = [KENNISMAKING.NOG, KENNISMAKING.GESPROKEN, KENNISMAKING.GEWEIGERD];
var NOTITIE_MAX = 500;
var VOLWASSEN = 18;
var VOG_JAREN = 3; // gelijk aan hh_xp_regels.VOG_JAREN (B9 vraag 3)
var DAG_MS = 24 * 3600 * 1000;
var CODE_PATROON = /^[A-Z0-9-]{3,20}$/;
var MERK_PAAR = "[zelfde paar]";
var TOELICHTING_GEWEIGERD = "kennismaking geweigerd door de meldkamer";

var MELDING_CODE = "Deze code kennen we niet. Vraag je jongerenwerker om de juiste code, of laat het vakje leeg.";
var MELDING_BESLUIT = "Kies gesproken of geweigerd.";
var MELDING_NOTITIE = "De notitie mag hooguit " + NOTITIE_MAX + " tekens zijn.";
var MELDING_NIET_GEVONDEN = "Deze bewoner bestaat niet (meer).";
var MELDING_ROL = "Een kennismaking is alleen voor bewoners.";
var MELDING_KEUREN = "Bel eerst de bewoner voor de kennismaking; daarna kun je de klus goedkeuren.";

// --------------------------------------------------------------------------
// kleine hulpjes
// --------------------------------------------------------------------------

function tekst(v) {
  return v === null || v === undefined ? "" : String(v).trim();
}

function datumTekst(ms) {
  return new Date(ms).toISOString().replace("T", " ");
}

function msVan(v) {
  var t = tekst(v);
  if (!t) return NaN;
  return Date.parse(t.replace(" ", "T"));
}

function voornaam(naam) {
  return tekst(naam).split(/\s+/)[0] || "";
}

function zoekId(app, collectie, id) {
  if (!id) return null;
  try {
    return app.findRecordById(collectie, String(id));
  } catch (_) {
    return null;
  }
}

function zoekAlle(app, collectie, filter, params, sort) {
  try {
    return app.findRecordsByFilter(collectie, filter, sort || "", 0, 0, params || {});
  } catch (_) {
    return [];
  }
}

function zoekEerste(app, collectie, filter, params, sort) {
  var lijst;
  try {
    lijst = app.findRecordsByFilter(collectie, filter, sort || "", 1, 0, params || {});
  } catch (_) {
    lijst = [];
  }
  return lijst.length ? lijst[0] : null;
}

// --------------------------------------------------------------------------
// instellingen (hh_instellingen: sleutel + json-waarde)
// --------------------------------------------------------------------------

function instellingWaarde(app, sleutel) {
  var rij = zoekEerste(app, "hh_instellingen", "sleutel = {:s}", { s: sleutel });
  if (!rij) return undefined;
  var w = rij.get("waarde");
  if (typeof w === "boolean" || typeof w === "number") return w;
  var t = "";
  try {
    t = typeof rij.getString === "function" ? rij.getString("waarde") : String(w);
  } catch (_) {
    t = "";
  }
  try {
    return JSON.parse(String(t));
  } catch (_) {
    return undefined;
  }
}

function instellingAan(app, sleutel) {
  return instellingWaarde(app, sleutel) === true;
}

function instellingGetal(app, sleutel, standaard) {
  var w = instellingWaarde(app, sleutel);
  return typeof w === "number" && isFinite(w) && w > 0 ? Math.floor(w) : standaard;
}

// --------------------------------------------------------------------------
// partnercode
// --------------------------------------------------------------------------

/// "tiel jw" -> "TIELJW"; ongeldig -> "".
function normaliseerCode(ruw) {
  var c = tekst(ruw).toUpperCase().replace(/\s+/g, "");
  return CODE_PATROON.test(c) ? c : "";
}

/// Leeg = geen partner (ok). Anders moet er een ACTIEVE partner met die code zijn.
function partnerVoorCode(app, ruw) {
  if (!tekst(ruw)) return { ok: true, partner: "" };
  var code = normaliseerCode(ruw);
  if (!code) return { ok: false, reden: "code" };
  var p = zoekEerste(app, "hh_partners", "code = {:c} && actief = true", { c: code });
  return p ? { ok: true, partner: p.id } : { ok: false, reden: "code" };
}

/// Per partner (op naam): aangemeld (hh_users.partner) en goedgekeurd
/// (profiel verificatiestatus = goedgekeurd).
function partnerTellers(app) {
  return zoekAlle(app, "hh_partners", "id != ''", {}, "naam").map(function (p) {
    var aangemeld = zoekAlle(app, "hh_users", "partner = {:p}", { p: p.id }).length;
    var goed = zoekAlle(app, "hh_profielen", "gebruiker.partner = {:p} && verificatiestatus = 'goedgekeurd'", { p: p.id }).length;
    return {
      id: p.id,
      naam: tekst(p.get("naam")),
      code: tekst(p.get("code")),
      actief: p.get("actief") === true,
      aangemeld: aangemeld,
      goedgekeurd: goed,
    };
  });
}

// --------------------------------------------------------------------------
// kennismaking
// --------------------------------------------------------------------------

function wachtOpKennismaking(app, bewonerId) {
  if (!instellingAan(app, INSTELLING.KENNISMAKING)) return false;
  var b = zoekId(app, "hh_users", tekst(bewonerId));
  if (!b) return false;
  return tekst(b.get("kennismaking_status")) !== KENNISMAKING.GESPROKEN;
}

function fout(status, reden, melding) {
  return { status: status, body: { melding: melding, reden: reden } };
}

///   invoer = { coordinatorId, userId, besluit, notitie }
///   -> { status, body }   (200 body = { gebruiker, kennismaking_status, geannuleerd, lopend })
function kennismaking(env, invoer) {
  var app = env.app;
  var besluit = tekst(invoer.besluit);
  if (besluit !== KENNISMAKING.GESPROKEN && besluit !== KENNISMAKING.GEWEIGERD) {
    return fout(400, "besluit", MELDING_BESLUIT);
  }
  var notitie = tekst(invoer.notitie);
  if (notitie.length > NOTITIE_MAX) return fout(400, "notitie", MELDING_NOTITIE);
  var gebruiker = zoekId(app, "hh_users", tekst(invoer.userId));
  if (!gebruiker) return fout(404, "nietgevonden", MELDING_NIET_GEVONDEN);
  if (tekst(gebruiker.get("rol")) !== "hulpvrager") return fout(409, "rol", MELDING_ROL);

  var nu = datumTekst(env.nu());
  var geannuleerd = 0;
  var lopend = 0;
  app.runInTransaction(function (tx) {
    var u = tx.findRecordById("hh_users", gebruiker.id);
    var voor = tekst(u.get("kennismaking_status")) || KENNISMAKING.NOG;
    var velden = ["kennismaking_status"];
    var van = { kennismaking_status: voor };
    var naar = { kennismaking_status: besluit };
    u.set("kennismaking_status", besluit);
    u.set("kennismaking_op", nu);
    u.set("kennismaking_door", invoer.coordinatorId);
    u.set("kennismaking_notitie", notitie);
    if (besluit === KENNISMAKING.GEWEIGERD) {
      if (u.get("geblokkeerd") !== true) {
        velden.push("geblokkeerd");
        van.geblokkeerd = false;
        naar.geblokkeerd = true;
      }
      u.set("geblokkeerd", true);
      geannuleerd = annuleerOpenKlussen(env, tx, u.id, invoer.coordinatorId);
      lopend = zoekAlle(tx, "hh_klussen", "hulpvrager = {:b} && toegewezen_jongere != '' && status != 'afgerond' && status != 'geannuleerd'", { b: u.id }).length;
    }
    tx.save(u);

    var regel = new env.Record(tx.findCollectionByNameOrId("hh_auditlog"));
    regel.set("door", invoer.coordinatorId);
    regel.set("actie", "wijzigen");
    regel.set("doel_collectie", "hh_users");
    regel.set("doel_id", u.id);
    regel.set("detail", { velden: velden, van: van, naar: naar });
    tx.save(regel);
  });
  return {
    status: 200,
    body: { gebruiker: gebruiker.id, kennismaking_status: besluit, geannuleerd: geannuleerd, lopend: lopend },
  };
}

/// Open en concept-klussen zonder helper -> geannuleerd, met logregel (M6).
function annuleerOpenKlussen(env, tx, bewonerId, coordinatorId) {
  var lijst = zoekAlle(tx, "hh_klussen", "hulpvrager = {:b} && (status = 'open' || status = 'concept') && toegewezen_jongere = ''", { b: bewonerId });
  for (var i = 0; i < lijst.length; i++) {
    var k = lijst[i];
    var van = tekst(k.get("status"));
    k.set("status", "geannuleerd");
    tx.save(k);
    var log = new env.Record(tx.findCollectionByNameOrId("hh_klus_status"));
    log.set("klus", k.id);
    log.set("door", coordinatorId);
    log.set("van", van);
    log.set("naar", "geannuleerd");
    log.set("toelichting", TOELICHTING_GEWEIGERD);
    tx.save(log);
  }
  return lijst.length;
}

// --------------------------------------------------------------------------
// VOG-wachtrij
// --------------------------------------------------------------------------

/// Leeftijd in hele jaren op dag [nuMs] (UTC-datum). Geen datum -> null.
function leeftijd(geboortedatum, nuMs) {
  var t = tekst(geboortedatum).slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(t)) return null;
  var d = new Date(nuMs).toISOString().slice(0, 10);
  var jaren = Number(d.slice(0, 4)) - Number(t.slice(0, 4));
  if (d.slice(5) < t.slice(5)) jaren--;
  return jaren;
}

function vogVerlooptOp(profiel) {
  var tot = tekst(profiel.get("vog_geldig_tot"));
  if (tot) return tot.slice(0, 10);
  var gezien = msVan(profiel.get("vog_gezien_op"));
  if (isNaN(gezien)) return "";
  var d = new Date(gezien);
  d.setUTCFullYear(d.getUTCFullYear() + VOG_JAREN);
  return d.toISOString().slice(0, 10);
}

/// Helpers 18+ (in behandeling of goedgekeurd) zonder VOG ("geen") of met
/// een verlopen VOG ("verlopen"). Eerst "geen", dan op naam.
function vogWachtrij(app, nuMs) {
  var vandaag = new Date(nuMs).toISOString().slice(0, 10);
  var uit = [];
  var profielen = zoekAlle(app, "hh_profielen", "gebruiker.rol = 'jongere' && (verificatiestatus = 'in_behandeling' || verificatiestatus = 'goedgekeurd')", {});
  for (var i = 0; i < profielen.length; i++) {
    var p = profielen[i];
    var u = zoekId(app, "hh_users", tekst(p.get("gebruiker")));
    if (!u) continue;
    var jaren = leeftijd(u.get("geboortedatum"), nuMs);
    if (jaren === null || jaren < VOLWASSEN) continue;
    var gezien = tekst(p.get("vog_gezien_op"));
    var verloopt = gezien ? vogVerlooptOp(p) : "";
    var reden = !gezien ? "geen" : verloopt && verloopt < vandaag ? "verlopen" : "";
    if (!reden) continue;
    uit.push({
      gebruiker: u.id,
      profiel: p.id,
      naam: tekst(u.get("naam")),
      leeftijd: jaren,
      verificatiestatus: tekst(p.get("verificatiestatus")),
      vog_gezien_op: gezien,
      verloopt_op: verloopt,
      reden: reden,
    });
  }
  uit.sort(function (a, b) {
    if (a.reden !== b.reden) return a.reden === "geen" ? -1 : 1;
    return a.naam < b.naam ? -1 : a.naam > b.naam ? 1 : 0;
  });
  return uit;
}

// --------------------------------------------------------------------------
// zelfde paar
// --------------------------------------------------------------------------

/// Na een statusregel naar "afgerond": signaal als een helper ONDER 18 de
/// N-de klus binnen D dagen met dezelfde bewoner deed. Hooguit één signaal
/// per paar per periode. Geeft het incident-id of "".
function zelfdePaar(env, statusRij) {
  var app = env.app;
  if (tekst(statusRij.get("naar")) !== "afgerond") return "";
  if (!instellingAan(app, INSTELLING.PAAR_AAN)) return "";
  var klus = zoekId(app, "hh_klussen", tekst(statusRij.get("klus")));
  if (!klus) return "";
  var helperId = tekst(klus.get("toegewezen_jongere"));
  var bewonerId = tekst(klus.get("hulpvrager"));
  var helper = zoekId(app, "hh_users", helperId);
  var bewoner = zoekId(app, "hh_users", bewonerId);
  if (!helper || !bewoner) return "";
  var nu = env.nu();
  var jaren = leeftijd(helper.get("geboortedatum"), nu);
  if (jaren === null || jaren >= VOLWASSEN) return "";

  var aantal = instellingGetal(app, INSTELLING.PAAR_AANTAL, PAAR_AANTAL);
  var dagen = instellingGetal(app, INSTELLING.PAAR_DAGEN, PAAR_DAGEN);
  var vanaf = datumTekst(nu - dagen * DAG_MS);
  var logs = zoekAlle(app, "hh_klus_status", "naar = 'afgerond' && created >= {:v} && klus.hulpvrager = {:b} && klus.toegewezen_jongere = {:h}", {
    v: vanaf, b: bewonerId, h: helperId,
  });
  var klussen = {};
  var n = 0;
  for (var i = 0; i < logs.length; i++) {
    var k = tekst(logs[i].get("klus"));
    if (!klussen[k]) {
      klussen[k] = true;
      n++;
    }
  }
  if (n < aantal) return "";

  var code = "zp:" + helperId + ":" + bewonerId;
  if (zoekEerste(app, "hh_incidenten", "soort = 'signaal' && omschrijving ~ {:c} && created >= {:v}", { c: code, v: vanaf })) return "";
  // melder is verplicht; nooit de helper of bewoner (die lezen hun eigen incidenten).
  var coordinator = zoekEerste(app, "hh_users", "rol = 'coordinator'", {}, "created");
  if (!coordinator) return "";

  var r = new env.Record(app.findCollectionByNameOrId("hh_incidenten"));
  r.set("klus", klus.id);
  r.set("melder", coordinator.id);
  r.set("soort", "signaal");
  r.set(
    "omschrijving",
    MERK_PAAR + " Strijder " + voornaam(helper.get("naam")) + " (" + jaren + ") en bewoner " + voornaam(bewoner.get("naam")) +
      " deden " + n + " klussen samen in " + dagen + " dagen. Kijk even of het goed gaat. (" + code + ")"
  );
  app.save(r);
  return r.id;
}

module.exports = {
  INSTELLING: INSTELLING,
  STANDAARD_INSTELLINGEN: STANDAARD_INSTELLINGEN,
  KENNISMAKING: KENNISMAKING,
  KENNISMAKING_STATUSSEN: KENNISMAKING_STATUSSEN,
  NOTITIE_MAX: NOTITIE_MAX,
  VOLWASSEN: VOLWASSEN,
  VOG_JAREN: VOG_JAREN,
  MERK_PAAR: MERK_PAAR,
  MELDING_CODE: MELDING_CODE,
  MELDING_KEUREN: MELDING_KEUREN,
  normaliseerCode: normaliseerCode,
  partnerVoorCode: partnerVoorCode,
  partnerTellers: partnerTellers,
  instellingAan: instellingAan,
  instellingGetal: instellingGetal,
  wachtOpKennismaking: wachtOpKennismaking,
  kennismaking: kennismaking,
  leeftijd: leeftijd,
  vogWachtrij: vogWachtrij,
  zelfdePaar: zelfdePaar,
};

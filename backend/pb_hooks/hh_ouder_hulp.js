// HeitjeHulp B3 — hh_ouder_hulp.js (hulpbestand, GEEN hook)
//
// Ouder-toestemming met een code (K1: alleen e-mail; K2: de OUDER vult de
// code in op de website). Bewust .js en niet .pb.js: PocketBase laadt alleen
// *.pb.js als hook. hh_ouder.pb.js haalt dit bestand BINNEN de handler op met
//   const hulp = require(`${__hooks}/hh_ouder_hulp.js`);
// en geeft een omgeving mee, zodat dit bestand niet op de globals van de JSVM
// leunt en backend/tests/hh_ouder_hulp.test.mjs het zonder server en ZONDER
// echte mail kan testen:
//   env = { app ($app), Record, nu() -> ms, willekeurig(lengte, alfabet),
//           sha256(tekst), gelijk(a, b) (vergelijken in vaste tijd),
//           mail({aan, onderwerp, tekst, html}) (gooit bij een fout),
//           store {get, set} ($app.store()), log(...) }
//
// OPSLAG: één rij per helper in hh_ouder_toestemming (script 90). De code en
// de link-token staan er NOOIT zelf in, alleen een sha256 met een vast
// voorvoegsel (en bij de code de helper-id erbij). De rij is alleen leesbaar
// voor de coordinator; de hash-velden zijn "hidden" (ook voor hem niet).
//
// DE STAPPEN
//   verstuur      helper < 18 (ingelogd): nieuwe code (6 cijfers, 24 uur) en
//                 nieuwe link-token; mail naar de ouder. Max 3 per UTC-dag.
//                 Opnieuw sturen: de oude code en de oude link vervallen.
//   controleerCode (publiek) e-mail + code, OF alleen de link-token:
//                 geeft een ouder-sessie van 30 minuten. Max 5 foute codes per
//                 verstuurde code, daarna geblokkeerd tot een nieuwe code.
//                 De link slaat de code-stap over zolang de code nog geldig
//                 is: link en code staan in dezelfde mail, de token is 40
//                 tekens (~238 bits) en staat achter de # (komt nooit in
//                 serverlogs of de Referer). Daarna toont de link alleen de
//                 stand (gegeven / verlopen / ingetrokken).
//   geefToestemming (ouder-sessie) naam, IBAN (NL, mod-97), vinkje akkoord
//                 (verplicht), vinkje AVP (mag nee) -> hh_users.
//                 ouder_toestemming_op = nu, ouder_iban_ok = ja.
//   trekIn        (link-token, altijd geldig; of de ouder-sessie) wist
//                 ouder_toestemming_op: de helper ziet direct geen open
//                 klussen meer (lijst-rule B2). Bevestigingsmail.
//   statusVoorHelper  wat de app toont (nooit hashes of IBAN).
// Rate-limit: alle publieke stappen samen hooguit 30 per IP per uur
// ($app.store(); een herstart zet de teller terug, de 5-pogingen-grens per
// code staat wel in de database).

var BASIS_URL = "https://heitjehulp.nl"; // K3: de site staat nog niet online
var CIJFERS = "0123456789";
var TEKENS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
var CODE_LENGTE = 6;
var TOKEN_LENGTE = 40;
var CODE_GELDIG_MS = 24 * 3600 * 1000;
var SESSIE_GELDIG_MS = 30 * 60 * 1000;
var MAX_POGINGEN = 5;
var MAX_PER_DAG = 3;
var MAX_PER_IP_PER_UUR = 30;
var VOLWASSEN = 18;
var COLLECTIE = "hh_ouder_toestemming";

var MELDING = {
  rol: "Alleen een helper kan zijn ouder om toestemming vragen.",
  volwassen: "Vanaf 18 jaar heb je geen toestemming van je ouder nodig.",
  geboortedatum: "Je geboortedatum ontbreekt. Neem contact op met de meldkamer.",
  email: "Vul het e-mailadres van je ouder in.",
  eigenadres: "Vul het e-mailadres van je ouder in, niet je eigen adres.",
  algegeven: "Je ouder heeft al toestemming gegeven.",
  limiet: "Je hebt vandaag al 3 keer een mail gestuurd. Probeer het morgen opnieuw.",
  mail: "De mail kon niet worden verstuurd. Probeer het later opnieuw.",
  verstuurd: "We hebben je ouder een mail gestuurd.",
  invoer: "Vul je e-mailadres en de code van 6 cijfers in.",
  code: "Deze code klopt niet. Kijk de code en je e-mailadres na.",
  geblokkeerd:
    "Er is 5 keer een verkeerde code ingevuld. Vraag je kind om een nieuwe code te sturen.",
  teveel: "Te veel pogingen. Probeer het over een uur opnieuw.",
  link: "Deze link werkt niet meer. Gebruik de link uit de nieuwste mail.",
  sessie: "Je sessie is verlopen. Open de link uit de mail opnieuw of vul de code in.",
  akkoord: "Zet het vinkje om toestemming te geven.",
  naam: "Vul je naam in.",
  iban: "Vul een geldig Nederlands rekeningnummer (IBAN) in.",
  status: "Er is geen openstaande vraag om toestemming.",
  intrekkenZonder: "Open de link uit de mail om je toestemming in te trekken.",
};

// --------------------------------------------------------------------------
// PUUR
// --------------------------------------------------------------------------

function normaliseerEmail(waarde) {
  return String(waarde || "").trim().toLowerCase();
}

function isGeldigEmail(waarde) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(waarde || ""));
}

/// Gereserveerde namen (RFC 2606/6761): daar gaat nooit echte mail heen.
/// 92-b3check gebruikt ...@heitjehulp.invalid, zodat ook een check op prod
/// geen mail verstuurt.
function isNepAdres(email) {
  var domein = normaliseerEmail(email).split("@")[1] || "";
  return /(^|\.)(invalid|test|example|localhost)$/.test(domein);
}

function normaliseerIban(invoer) {
  return String(invoer || "").replace(/\s+/g, "").toUpperCase();
}

/// Zoals de app (app/lib/features/jongere/iban_validatie.dart, M3): NL, 18
/// tekens, NL + 2 cijfers + 4 letters + 10 cijfers, mod-97 = 1.
function isGeldigNlIban(invoer) {
  var iban = normaliseerIban(invoer);
  if (!/^NL\d{2}[A-Z]{4}\d{10}$/.test(iban)) return false;
  var herschikt = iban.slice(4) + iban.slice(0, 4);
  var rest = 0;
  for (var i = 0; i < herschikt.length; i++) {
    var c = herschikt.charCodeAt(i);
    var stuk = c >= 65 && c <= 90 ? String(c - 55) : herschikt[i];
    for (var j = 0; j < stuk.length; j++) rest = (rest * 10 + (stuk.charCodeAt(j) - 48)) % 97;
  }
  return rest === 1;
}

function voornaam(naam) {
  return String(naam || "").trim().split(/\s+/)[0] || "";
}

function zonderRegeleinden(tekst) {
  return String(tekst || "").replace(/[\r\n]+/g, " ").trim();
}

function ontsnap(tekst) {
  return String(tekst || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function linkVoor(basis, token) {
  return basis + "/#/ouder?t=" + token;
}

function tweeCijfers(n) {
  return n < 10 ? "0" + n : String(n);
}

function dagSleutel(ms) {
  var d = new Date(ms);
  return d.getUTCFullYear() + "-" + tweeCijfers(d.getUTCMonth() + 1) + "-" + tweeCijfers(d.getUTCDate());
}

/// Zoals PocketBase datums bewaart: "2026-10-04 10:00:00.000Z".
function isoVan(ms) {
  return new Date(ms).toISOString().replace("T", " ");
}

/// Een datumveld (tekst of DateTime van de JSVM) naar ms, of 0.
function msVan(waarde) {
  var t = String(waarde || "").trim();
  if (!t) return 0;
  var ms = Date.parse(t.replace(" ", "T"));
  return isFinite(ms) ? ms : 0;
}

function codeHash(sha256, helperId, code) {
  return sha256("hh-ouder-code:" + helperId + ":" + code);
}
function tokenHash(sha256, token) {
  return sha256("hh-ouder-token:" + token);
}
function sessieHash(sha256, sessie) {
  return sha256("hh-ouder-sessie:" + sessie);
}

function uitnodigingsMail(g) {
  var naam = zonderRegeleinden(g.voornaam) || "Je kind";
  var onderwerp = naam + " wil helper worden bij HeitjeHulp";
  var tekst = [
    "Hallo,",
    "",
    naam + " wil helper worden bij HeitjeHulp. HeitjeHulp brengt buren en helpers samen voor kleine klussen, zoals boodschappen of tuinwerk.",
    naam + " is jonger dan 18. Daarom vragen we eerst jouw toestemming.",
    "",
    "Je code: " + g.code,
    "",
    "Open deze link en geef toestemming: " + g.link,
    "Of ga naar " + BASIS_URL + "/#/ouder en vul je e-mailadres en de code in.",
    "Code 24 uur geldig.",
    "Met dezelfde link kun je je toestemming later altijd weer intrekken.",
    "",
    "Was jij dit niet? Negeer deze mail. Er gebeurt dan niets.",
    "",
    "Groet,",
    "HeitjeHulp",
  ].join("\n");
  var n = ontsnap(naam);
  var l = ontsnap(g.link);
  var html =
    '<div style="font-family:Arial,sans-serif;font-size:16px;line-height:24px;color:#0B2A25;max-width:560px">' +
    "<p>Hallo,</p>" +
    "<p>" + n + " wil helper worden bij HeitjeHulp. HeitjeHulp brengt buren en helpers samen voor kleine klussen, zoals boodschappen of tuinwerk.</p>" +
    "<p>" + n + " is jonger dan 18. Daarom vragen we eerst jouw toestemming.</p>" +
    '<p style="margin:24px 0 4px">Je code:</p>' +
    '<p style="margin:0 0 24px;font-size:36px;line-height:44px;font-weight:bold;letter-spacing:6px;color:#17453E">' + ontsnap(g.code) + "</p>" +
    '<p><a href="' + l + '" style="display:inline-block;background:#17453E;color:#FFFFFF;padding:12px 20px;border-radius:10px;text-decoration:none;font-weight:bold">Toestemming geven</a></p>' +
    '<p style="font-size:14px;color:#4A5754">Werkt de knop niet? Open ' + l + "<br>Of ga naar " + BASIS_URL + "/#/ouder en vul je e-mailadres en de code in.</p>" +
    "<p>Code 24 uur geldig.<br>Met dezelfde link kun je je toestemming later altijd weer intrekken.</p>" +
    "<p>Was jij dit niet? Negeer deze mail. Er gebeurt dan niets.</p>" +
    "<p>Groet,<br>HeitjeHulp</p>" +
    "</div>";
  return { onderwerp: onderwerp, tekst: tekst, html: html };
}

function intrekMail(g) {
  var naam = zonderRegeleinden(g.voornaam) || "je kind";
  var onderwerp = "Je toestemming voor " + naam + " is ingetrokken";
  var tekst = [
    "Hallo,",
    "",
    "Je hebt je toestemming voor " + naam + " ingetrokken. " + naam + " kan nu geen klussen meer aannemen bij HeitjeHulp.",
    "Wil je later toch weer toestemming geven? Dan kan " + naam + " je in de app een nieuwe code sturen.",
    "",
    "Was jij dit niet? Neem dan contact op met HeitjeHulp.",
    "",
    "Groet,",
    "HeitjeHulp",
  ].join("\n");
  var n = ontsnap(naam);
  var html =
    '<div style="font-family:Arial,sans-serif;font-size:16px;line-height:24px;color:#0B2A25;max-width:560px">' +
    "<p>Hallo,</p>" +
    "<p>Je hebt je toestemming voor " + n + " ingetrokken. " + n + " kan nu geen klussen meer aannemen bij HeitjeHulp.</p>" +
    "<p>Wil je later toch weer toestemming geven? Dan kan " + n + " je in de app een nieuwe code sturen.</p>" +
    "<p>Was jij dit niet? Neem dan contact op met HeitjeHulp.</p>" +
    "<p>Groet,<br>HeitjeHulp</p>" +
    "</div>";
  return { onderwerp: onderwerp, tekst: tekst, html: html };
}

function antwoord(status, reden, extra) {
  var body = { melding: MELDING[reden] || "", reden: reden };
  if (extra) for (var k in extra) body[k] = extra[k];
  return { status: status, body: body };
}

function ok(body) {
  return { status: 200, body: body };
}

// --------------------------------------------------------------------------
// MET env
// --------------------------------------------------------------------------

function zoekEerste(app, filter, params) {
  try {
    return app.findFirstRecordByFilter(COLLECTIE, filter, params);
  } catch (_) {
    return null;
  }
}

function rijVanHelper(env, helperId) {
  return zoekEerste(env.app, "helper = {:helper}", { helper: helperId });
}

function helperVan(env, rij) {
  try {
    return env.app.findRecordById("hh_users", String(rij.get("helper") || ""));
  } catch (_) {
    return null;
  }
}

/// De stand zoals de buitenwereld hem ziet: "verstuurd" met een verlopen
/// code is "verlopen".
function standVan(rij, nu) {
  var s = String(rij.get("status") || "");
  if (s === "verstuurd" && msVan(rij.get("code_verloopt_op")) <= nu) return "verlopen";
  return s;
}

function isGeblokkeerd(rij) {
  return Number(rij.get("pogingen") || 0) >= MAX_POGINGEN;
}

function verstuurdVandaag(rij, nu) {
  if (!rij || String(rij.get("verstuur_dag") || "") !== dagSleutel(nu)) return 0;
  return Number(rij.get("verstuur_aantal") || 0);
}

/// Telt dit verzoek mee voor [ip]; false = boven de grens.
function binnenIpGrens(env, ip) {
  var sleutel = "hh_ouder_ip:" + String(ip || "onbekend") + ":" + Math.floor(env.nu() / 3600000);
  var aantal = Number(env.store.get(sleutel) || 0);
  if (aantal >= MAX_PER_IP_PER_UUR) return false;
  env.store.set(sleutel, aantal + 1);
  return true;
}

function nieuweSessie(env, rij) {
  var sessie = env.willekeurig(TOKEN_LENGTE, TEKENS);
  rij.set("sessie_hash", sessieHash(env.sha256, sessie));
  rij.set("sessie_verloopt_op", isoVan(env.nu() + SESSIE_GELDIG_MS));
  env.app.save(rij);
  return sessie;
}

function rijVanSessie(env, sessie) {
  if (!sessie) return null;
  var rij = zoekEerste(env.app, "sessie_hash = {:sessie_hash}", {
    sessie_hash: sessieHash(env.sha256, String(sessie)),
  });
  if (!rij || msVan(rij.get("sessie_verloopt_op")) <= env.nu()) return null;
  return rij;
}

function rijVanToken(env, token) {
  if (!token) return null;
  return zoekEerste(env.app, "token_hash = {:token_hash}", {
    token_hash: tokenHash(env.sha256, String(token)),
  });
}

/// Wat de ouder-pagina over de stand te zien krijgt.
function standVoorOuder(env, rij) {
  var helper = helperVan(env, rij);
  var body = {
    status: standVan(rij, env.nu()),
    voornaam: helper ? voornaam(helper.get("naam")) : "",
  };
  if (body.status === "gegeven") {
    body.gegeven_op = String(rij.get("gegeven_op") || "");
    body.avp = rij.get("avp_verklaard") === true;
  }
  if (body.status === "ingetrokken") body.ingetrokken_op = String(rij.get("ingetrokken_op") || "");
  return body;
}

// ---- verstuur ---------------------------------------------------------------
///   invoer = { helper (record), leeftijd (getal of null), ouderEmail }
function verstuur(env, invoer) {
  var helper = invoer.helper;
  if (String(helper.get("rol") || "") !== "jongere") return antwoord(403, "rol");
  if (invoer.leeftijd === null || invoer.leeftijd === undefined) return antwoord(409, "geboortedatum");
  if (invoer.leeftijd >= VOLWASSEN) return antwoord(409, "volwassen");

  var email = normaliseerEmail(invoer.ouderEmail || helper.get("ouder_email"));
  if (!isGeldigEmail(email)) return antwoord(400, "email");
  if (email === normaliseerEmail(helper.get("email"))) return antwoord(400, "eigenadres");

  var nu = env.nu();
  var rij = rijVanHelper(env, helper.id);
  if (rij && String(rij.get("status") || "") === "gegeven" && String(helper.get("ouder_toestemming_op") || "")) {
    return antwoord(409, "algegeven");
  }
  var eerder = verstuurdVandaag(rij, nu);
  if (eerder >= MAX_PER_DAG) return antwoord(429, "limiet");

  var code = env.willekeurig(CODE_LENGTE, CIJFERS);
  var token = env.willekeurig(TOKEN_LENGTE, TEKENS);
  if (!rij) {
    rij = new env.Record(env.app.findCollectionByNameOrId(COLLECTIE));
    rij.set("helper", helper.id);
  }
  rij.set("ouder_email", email);
  rij.set("code_hash", codeHash(env.sha256, helper.id, code));
  rij.set("code_verloopt_op", isoVan(nu + CODE_GELDIG_MS));
  rij.set("pogingen", 0);
  rij.set("token_hash", tokenHash(env.sha256, token));
  rij.set("sessie_hash", "");
  rij.set("sessie_verloopt_op", "");
  rij.set("status", "verstuurd");
  rij.set("verstuur_dag", dagSleutel(nu));
  rij.set("verstuur_aantal", eerder);
  rij.set("laatst_verstuurd_op", isoVan(nu));
  env.app.save(rij);
  if (normaliseerEmail(helper.get("ouder_email")) !== email) {
    helper.set("ouder_email", email);
    env.app.save(helper);
  }

  var mail = uitnodigingsMail({ voornaam: voornaam(helper.get("naam")), code: code, link: linkVoor(BASIS_URL, token) });
  if (isNepAdres(email)) {
    env.log("[hh_ouder] nep-adres, geen mail verstuurd (helper " + helper.id + ")");
  } else {
    try {
      env.mail({ aan: email, onderwerp: mail.onderwerp, tekst: mail.tekst, html: mail.html });
    } catch (err) {
      env.log("[hh_ouder] mail mislukt (helper " + helper.id + "):", String(err));
      return antwoord(502, "mail");
    }
  }
  rij.set("verstuur_aantal", eerder + 1);
  env.app.save(rij);
  return ok({
    melding: MELDING.verstuurd,
    status: "verstuurd",
    ouder_email: email,
    verstuurd_op: isoVan(nu),
    code_verloopt_op: isoVan(nu + CODE_GELDIG_MS),
    nog_te_sturen: MAX_PER_DAG - (eerder + 1),
  });
}

// ---- controleerCode -----------------------------------------------------------
///   invoer = { token } of { email, code }, plus ip
function controleerCode(env, invoer) {
  if (!binnenIpGrens(env, invoer.ip)) return antwoord(429, "teveel");
  var nu = env.nu();

  if (invoer.token) {
    var rijT = rijVanToken(env, invoer.token);
    if (!rijT) return antwoord(404, "link");
    var stand = standVan(rijT, nu);
    if (stand === "verlopen" && String(rijT.get("status")) !== "verlopen") {
      rijT.set("status", "verlopen");
      env.app.save(rijT);
    }
    var body = standVoorOuder(env, rijT);
    if (stand === "verstuurd") body.sessie = nieuweSessie(env, rijT);
    return ok(body);
  }

  var email = normaliseerEmail(invoer.email);
  var code = String(invoer.code || "").trim();
  if (!isGeldigEmail(email) || !/^\d{6}$/.test(code)) return antwoord(400, "invoer");

  var rijen = [];
  try {
    rijen = env.app.findRecordsByFilter(COLLECTIE, 'ouder_email = {:ouder_email} && status = "verstuurd"', "", 0, 0, {
      ouder_email: email,
    });
  } catch (_) {
    rijen = [];
  }
  var open = [];
  var geblokkeerd = 0;
  for (var i = 0; i < rijen.length; i++) {
    var r = rijen[i];
    if (standVan(r, nu) !== "verstuurd") continue;
    if (isGeblokkeerd(r)) {
      geblokkeerd++;
      continue;
    }
    if (env.gelijk(String(r.get("code_hash") || ""), codeHash(env.sha256, String(r.get("helper")), code))) {
      r.set("pogingen", 0);
      var uit = standVoorOuder(env, r);
      uit.sessie = nieuweSessie(env, r);
      return ok(uit);
    }
    open.push(r);
  }
  var nuGeblokkeerd = false;
  for (var j = 0; j < open.length; j++) {
    var p = Number(open[j].get("pogingen") || 0) + 1;
    open[j].set("pogingen", p);
    env.app.save(open[j]);
    if (p >= MAX_POGINGEN) nuGeblokkeerd = true;
  }
  if (nuGeblokkeerd || (geblokkeerd > 0 && open.length === 0)) return antwoord(429, "geblokkeerd");
  return antwoord(400, "code");
}

// ---- geefToestemming ------------------------------------------------------------
///   invoer = { sessie, naam, iban, akkoord (true), avp (bool), ip }
function geefToestemming(env, invoer) {
  if (!binnenIpGrens(env, invoer.ip)) return antwoord(429, "teveel");
  var rij = rijVanSessie(env, invoer.sessie);
  if (!rij) return antwoord(401, "sessie");
  if (standVan(rij, env.nu()) !== "verstuurd") return antwoord(409, "status", standVoorOuder(env, rij));
  if (invoer.akkoord !== true) return antwoord(400, "akkoord");
  var naam = zonderRegeleinden(invoer.naam);
  if (naam.length < 2 || naam.length > 100) return antwoord(400, "naam");
  if (!isGeldigNlIban(invoer.iban)) return antwoord(400, "iban");

  var helper = helperVan(env, rij);
  if (!helper) return antwoord(409, "status");
  var nu = isoVan(env.nu());
  env.app.runInTransaction(function (tx) {
    rij.set("status", "gegeven");
    rij.set("gegeven_op", nu);
    rij.set("ouder_naam", naam);
    rij.set("iban", normaliseerIban(invoer.iban));
    rij.set("avp_verklaard", invoer.avp === true);
    rij.set("code_hash", "");
    tx.save(rij);
    helper.set("ouder_toestemming_op", nu);
    helper.set("ouder_iban_ok", true);
    tx.save(helper);
  });
  return ok(standVoorOuder(env, rij));
}

// ---- trekIn ---------------------------------------------------------------------
///   invoer = { token } of { sessie }, plus ip. De link blijft altijd geldig.
function trekIn(env, invoer) {
  if (!binnenIpGrens(env, invoer.ip)) return antwoord(429, "teveel");
  var rij = null;
  if (invoer.token) {
    rij = rijVanToken(env, invoer.token);
    if (!rij) return antwoord(404, "link");
  } else if (invoer.sessie) {
    rij = rijVanSessie(env, invoer.sessie);
    if (!rij) return antwoord(401, "sessie");
  } else {
    return antwoord(400, "intrekkenZonder");
  }
  if (String(rij.get("status") || "") === "ingetrokken") return ok(standVoorOuder(env, rij));

  var helper = helperVan(env, rij);
  var wasGegeven = String(rij.get("status") || "") === "gegeven";
  var nu = isoVan(env.nu());
  env.app.runInTransaction(function (tx) {
    rij.set("status", "ingetrokken");
    rij.set("ingetrokken_op", nu);
    rij.set("code_hash", "");
    rij.set("sessie_hash", "");
    rij.set("sessie_verloopt_op", "");
    tx.save(rij);
    if (helper) {
      helper.set("ouder_toestemming_op", "");
      helper.set("ouder_iban_ok", false);
      tx.save(helper);
    }
  });
  var email = String(rij.get("ouder_email") || "");
  if (wasGegeven && !isNepAdres(email)) {
    var mail = intrekMail({ voornaam: helper ? voornaam(helper.get("naam")) : "" });
    try {
      env.mail({ aan: email, onderwerp: mail.onderwerp, tekst: mail.tekst, html: mail.html });
    } catch (err) {
      // Het intrekken zelf is gelukt; de bevestiging is een extraatje.
      env.log("[hh_ouder] bevestigingsmail intrekken mislukt:", String(err));
    }
  }
  return ok(standVoorOuder(env, rij));
}

// ---- statusVoorHelper -------------------------------------------------------------
///   invoer = { helper (record), leeftijd }
function statusVoorHelper(env, invoer) {
  var helper = invoer.helper;
  var nu = env.nu();
  var nodig = invoer.leeftijd === null || invoer.leeftijd === undefined || invoer.leeftijd < VOLWASSEN;
  var rij = rijVanHelper(env, helper.id);
  var body = {
    status: rij ? standVan(rij, nu) : "geen",
    nodig: nodig,
    ouder_email: rij ? String(rij.get("ouder_email") || "") : normaliseerEmail(helper.get("ouder_email")),
    verstuurd_op: rij ? String(rij.get("laatst_verstuurd_op") || "") : "",
    code_verloopt_op: rij ? String(rij.get("code_verloopt_op") || "") : "",
    geblokkeerd: rij ? standVan(rij, nu) === "verstuurd" && isGeblokkeerd(rij) : false,
    gegeven_op: rij ? String(rij.get("gegeven_op") || "") : "",
    ingetrokken_op: rij ? String(rij.get("ingetrokken_op") || "") : "",
    nog_te_sturen: MAX_PER_DAG - verstuurdVandaag(rij, nu),
  };
  // Een coordinator kan de toestemming ook zelf hebben gezet (B2-weg).
  if (body.status !== "gegeven" && String(helper.get("ouder_toestemming_op") || "")) body.status = "gegeven";
  return ok(body);
}

// ---- de echte omgeving (JSVM) -------------------------------------------------------
/// Bouwt env uit de globals van de JSVM. De hook geeft ze mee:
///   hulp.jsvmOmgeving({ app: $app, Record, security: $security, MailerMessage })
/// Mail via $app.newMailClient() met de afzender uit de serverinstellingen
/// (K4: geen instelling wijzigen).
function jsvmOmgeving(g) {
  return {
    app: g.app,
    Record: g.Record,
    nu: function () {
      return Date.now();
    },
    willekeurig: function (lengte, alfabet) {
      return g.security.randomStringWithAlphabet(lengte, alfabet);
    },
    sha256: function (tekst) {
      return g.security.sha256(tekst);
    },
    gelijk: function (a, b) {
      return g.security.equal(a, b);
    },
    mail: function (b) {
      var meta = g.app.settings().meta;
      var bericht = new g.MailerMessage({
        from: { address: meta.senderAddress, name: meta.senderName },
        to: [{ address: b.aan }],
        subject: b.onderwerp,
        html: b.html,
        text: b.tekst,
      });
      g.app.newMailClient().send(bericht);
    },
    store: g.app.store(),
    log: function () {
      console.log.apply(console, arguments);
    },
  };
}

module.exports = {
  jsvmOmgeving: jsvmOmgeving,
  BASIS_URL: BASIS_URL,
  MAX_POGINGEN: MAX_POGINGEN,
  MAX_PER_DAG: MAX_PER_DAG,
  MAX_PER_IP_PER_UUR: MAX_PER_IP_PER_UUR,
  CIJFERS: CIJFERS,
  TEKENS: TEKENS,
  COLLECTIE: COLLECTIE,
  MELDING: MELDING,
  normaliseerEmail: normaliseerEmail,
  isGeldigEmail: isGeldigEmail,
  isNepAdres: isNepAdres,
  normaliseerIban: normaliseerIban,
  isGeldigNlIban: isGeldigNlIban,
  voornaam: voornaam,
  linkVoor: linkVoor,
  dagSleutel: dagSleutel,
  isoVan: isoVan,
  codeHash: codeHash,
  tokenHash: tokenHash,
  sessieHash: sessieHash,
  uitnodigingsMail: uitnodigingsMail,
  intrekMail: intrekMail,
  verstuur: verstuur,
  controleerCode: controleerCode,
  geefToestemming: geefToestemming,
  trekIn: trekIn,
  statusVoorHelper: statusVoorHelper,
};

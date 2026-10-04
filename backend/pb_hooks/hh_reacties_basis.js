// HeitjeHulp B5 — hh_reacties_basis.js (hulpbestand, GEEN hook)
//
// De gedeelde basis van reageren en kiezen: constanten, pure functies, lezen
// uit de database, meldingen maken en de omgeving voor de hooks. Bewust .js
// en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. Gebruikt door
// hh_reacties_hulp.js (reageren, ouder, kiezen) en hh_reacties_na.js (na een
// statuswissel, meldingen nakijken, "Ik kan nu helpen", geheime vraag,
// verrijken). Leunt niet op globals van de JSVM: alles via env (zie
// hh_reacties_hulp.js) of de app die de aanroeper meegeeft.

var COLLECTIE = "hh_reacties";
var STATUS = {
  WACHT: "wacht_op_ouder",
  OPEN: "open",
  GEKOZEN: "gekozen",
  AFGEWEZEN: "afgewezen",
  INGETROKKEN: "ingetrokken",
  VERVALLEN: "vervallen",
};
var STATUSSEN = ["wacht_op_ouder", "open", "gekozen", "afgewezen", "ingetrokken", "vervallen"];
var MAX_BERICHT = 200;
var MAX_ACTIEF_PER_HELPER = 10;
var TOKEN_LENGTE = 40;
var TEKENS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
var BESCHIKBAAR_MS = 3 * 3600 * 1000;
var STANDAARD_DUUR_MS = 2 * 3600 * 1000;
var VOLWASSEN = 18;
var OUDER_MEE_VANAF = 10;
var OUDER_MEE_TOT_EN_MET = 12;
var MAX_PER_IP_PER_UUR = 30;
var MAX_TELLEN = 500;
var MELDING_SOORT = "reactie";
var NIVEAU_NIEUW = "Nieuw"; // B9 maakt hier echte niveaus van
var BASIS_URL = "https://heitjehulp.nl"; // zelfde basis als B3
var LINK_PAD = "/#/ouder/klus?token=";
var TOELICHTING_GEKOZEN = "gekozen door de bewoner";
var TOELICHTING_GEKOZEN_MELDKAMER = "gekozen door de meldkamer";
var INSTELLING_ACCEPTEREN_DICHT = "b5_accepteren_dicht";
var INSTELLING_ALLEEN_BESCHIKBAAR = "b5_nieuwe_klus_alleen_beschikbaar";
/// Antwoord Ibrahim 5: helpers onder 18 reageren pas als de site (de
/// ouder-pagina) online is. Standaard uit = 409 "onder18".
var INSTELLING_ONDER18_OPEN = "b5_onder18_reageren_open";
/// Antwoord Ibrahim 4: "nee" op de geheime vraag is een eigen, zachtere soort
/// incident (geen "Probleem gemeld"-alarm; wel in de lijst van het paneel).
var INCIDENT_SOORT_SIGNAAL = "signaal";
var GEHEIME_VELDEN = ["alles_in_orde", "geheim_toelichting"];
var BEZET_STATUSSEN = ["geaccepteerd", "onderweg", "bezig"];

// --------------------------------------------------------------------------
// PUUR
// --------------------------------------------------------------------------

function tweeCijfers(n) {
  return n < 10 ? "0" + n : String(n);
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

function tekst(waarde) {
  return String(waarde === undefined || waarde === null ? "" : waarde).trim();
}

function voornaam(naam) {
  return tekst(naam).split(/\s+/)[0] || "";
}

function vandaagVan(ms) {
  var d = new Date(ms);
  return d.getUTCFullYear() + "-" + tweeCijfers(d.getUTCMonth() + 1) + "-" + tweeCijfers(d.getUTCDate());
}

/// Het berichtje van de helper: hooguit 200 tekens (vóór het filter), en
/// nummers, mailadressen en links worden "•••" (zelfde filter als de chat).
///   -> { ok, tekst, gefilterd }
function schoonBericht(invoer, filterTekst) {
  var ruw = tekst(invoer);
  if (ruw.length > MAX_BERICHT) return { ok: false, tekst: "", gefilterd: false };
  if (!ruw) return { ok: true, tekst: "", gefilterd: false };
  var f = filterTekst(ruw);
  return { ok: true, tekst: String(f.tekst).slice(0, MAX_BERICHT), gefilterd: f.gefilterd === true };
}

/// Voor de ouder: straat zonder huisnummer + plaats ("Kerkstraat, Tiel"), of
/// alleen de plaats. Nooit huisnummer, toevoeging of postcode.
function waarVoorOuder(klusAdres, plaatsBewoner) {
  var delen = tekst(klusAdres).split(",");
  var straat = tekst(delen[0]).replace(/\s+\d.*$/, "").replace(/\d/g, "").trim();
  var plaats = "";
  if (delen.length > 1) {
    plaats = tekst(delen[delen.length - 1]).replace(/^\d{4}\s*[A-Za-z]{2}\s*/, "").replace(/\d/g, "").trim();
  }
  if (!plaats) plaats = tekst(plaatsBewoner).replace(/\d/g, "").trim();
  if (straat && plaats) return straat + ", " + plaats;
  return straat || plaats;
}

/// Overlappen twee klussen in de tijd? { van, tot } als datumtekst; zonder
/// eindtijd telt 2 uur; zonder begintijd nooit (dan weet niemand het).
function overlapt(a, b) {
  var av = msVan(a && a.van);
  var bv = msVan(b && b.van);
  if (!av || !bv) return false;
  var at = msVan(a.tot) > av ? msVan(a.tot) : av + STANDAARD_DUUR_MS;
  var bt = msVan(b.tot) > bv ? msVan(b.tot) : bv + STANDAARD_DUUR_MS;
  return av < bt && bv < at;
}

function linkVoor(basis, token) {
  return (basis || BASIS_URL) + LINK_PAD + token;
}

function tokenHash(sha256, token) {
  return sha256("hh-ouder-klus:" + token);
}

/// Zoekt een helper op de geheime vraag (filter of sorteren)? Dan 400.
function zoektOpGeheim(filter, sort) {
  var t = (tekst(filter) + " " + tekst(sort)).toLowerCase();
  for (var i = 0; i < GEHEIME_VELDEN.length; i++) {
    if (t.indexOf(GEHEIME_VELDEN[i]) >= 0) return true;
  }
  return false;
}

function antwoord(env, status, reden, extra) {
  var body = { melding: env.dep.teksten.MELDING[reden] || "", reden: reden };
  if (extra) for (var k in extra) body[k] = extra[k];
  return { status: status, body: body };
}

function ok(body) {
  return { status: 200, body: body };
}

// --------------------------------------------------------------------------
// LEZEN (met app)
// --------------------------------------------------------------------------

function zoekId(app, collectie, id) {
  if (!id) return null;
  try {
    return app.findRecordById(collectie, String(id));
  } catch (_) {
    return null;
  }
}

function zoekAlle(app, collectie, filter, params, sort, limit) {
  try {
    return app.findRecordsByFilter(collectie, filter, sort || "", limit || 0, 0, params || {});
  } catch (_) {
    return [];
  }
}

function zoekEerste(app, collectie, filter, params, sort) {
  var lijst = zoekAlle(app, collectie, filter, params, sort, 1);
  return lijst.length ? lijst[0] : null;
}

/// Staat de instelling [sleutel] in hh_instellingen op true? Een json-veld
/// komt in de JSVM als bytes binnen; getString geeft de json-tekst.
function instellingAan(app, sleutel) {
  var rij = zoekEerste(app, "hh_instellingen", "sleutel = {:sleutel}", { sleutel: sleutel });
  if (!rij) return false;
  var w = rij.get("waarde");
  if (w === true) return true;
  if (w === false || w === null || w === undefined || typeof w === "string") return false;
  var t = "";
  try {
    t = typeof rij.getString === "function" ? rij.getString("waarde") : "";
  } catch (_) {
    t = "";
  }
  try {
    return JSON.parse(String(t)) === true;
  } catch (_) {
    return false;
  }
}

function profielVan(app, gebruikerId) {
  return zoekEerste(app, "hh_profielen", "gebruiker = {:gebruiker}", { gebruiker: gebruikerId });
}

function wijkInfo(app, id) {
  var w = zoekId(app, "hh_wijken", tekst(id));
  if (!w) return null;
  return { id: w.id, gemeente: tekst(w.get("gemeente")), regio: w.get("regio") === true };
}

/// Klussoort + "zaterdag 10 oktober om 10:00" van een klus.
function klusInfo(env, klus) {
  var type = zoekId(env.app, "hh_klustypes", tekst(klus.get("klustype")));
  return {
    klussoort: type ? tekst(type.get("naam")) : "",
    typeMin: type ? Number(type.get("min_leeftijd") || 0) : undefined,
    wanneer: env.dep.meldingen.wanneerTekst(klus.get("wanneer_van")),
  };
}

/// Hoe oud moet je zijn, als deze helper dat op de klusdag NIET is? 0 = oud
/// genoeg. Zelfde som als de accepteer-route (B4).
function leeftijdNodig(env, klus, geboortedatum, typeMin) {
  var p = env.dep.plaatsen;
  var van = tekst(klus.get("wanneer_van"));
  var tot = tekst(klus.get("wanneer_tot"));
  var min = p.minLeeftijdVoorKlus({ typeMinLeeftijd: typeMin, van: van, tot: tot });
  var grens = p.geborenUiterlijk(van || new Date(env.nu()).toISOString(), min);
  return p.isOudGenoeg(tekst(geboortedatum), grens) ? 0 : min;
}

/// Waarom mag deze helper niet (meer)? null = mag. Zelfde volgorde als de
/// accepteer-route: rol, wijk, goedgekeurd, geblokkeerd, ouder/VOG.
function helperBlokkade(env, helper) {
  if (!helper || tekst(helper.get("rol")) !== "jongere") return "rol";
  if (helper.get("geblokkeerd") === true) return "rol";
  if (!tekst(helper.get("wijk"))) return "geenwijk";
  var profiel = profielVan(env.app, helper.id);
  if (!profiel || tekst(profiel.get("verificatiestatus")) !== "goedgekeurd") return "nietgoedgekeurd";
  var b = env.dep.aanmelden.klusBlokkade({
    geboortedatum: tekst(helper.get("geboortedatum")),
    ouderToestemmingOp: tekst(helper.get("ouder_toestemming_op")),
    vogGezienOp: tekst(profiel.get("vog_gezien_op")),
    vogGeldigTot: tekst(profiel.get("vog_geldig_tot")),
    vandaag: vandaagVan(env.nu()),
  });
  return b ? b.reden : null;
}

/// De melding van klusBlokkade (ouder/vog/...) voor [reden].
function blokkadeMelding(env, helper, reden) {
  var profiel = profielVan(env.app, helper.id);
  var b = env.dep.aanmelden.klusBlokkade({
    geboortedatum: tekst(helper.get("geboortedatum")),
    ouderToestemmingOp: tekst(helper.get("ouder_toestemming_op")),
    vogGezienOp: profiel ? tekst(profiel.get("vog_gezien_op")) : "",
    vogGeldigTot: profiel ? tekst(profiel.get("vog_geldig_tot")) : "",
    vandaag: vandaagVan(env.nu()),
  });
  return b && b.reden === reden ? b.melding : "";
}

/// Waarom past deze open klus niet bij deze helper? null = past.
function klusBlokkade(env, klus, helper) {
  var status = tekst(klus.get("status"));
  if (status !== "open" || tekst(klus.get("toegewezen_jongere"))) return { status: 409, reden: "bezet" };
  var bewoner = zoekId(env.app, "hh_users", tekst(klus.get("hulpvrager")));
  if (!bewoner) return { status: 409, reden: "bezet" };
  if (!env.dep.aanmelden.wijkenPassen(wijkInfo(env.app, bewoner.get("wijk")), wijkInfo(env.app, helper.get("wijk")))) {
    return { status: 409, reden: "wijk" };
  }
  if (!tekst(klus.get("klus_goedgekeurd_op"))) return { status: 409, reden: "nietgekeurd" };
  var van = msVan(klus.get("wanneer_van"));
  if (van && van <= env.nu()) return { status: 409, reden: "begonnen" };
  var info = klusInfo(env, klus);
  var nodig = leeftijdNodig(env, klus, helper.get("geboortedatum"), info.typeMin);
  if (nodig > 0) return { status: 403, reden: "leeftijd", nodig: nodig };
  return null;
}

/// Geen eerdere (echte) klus van deze helper bij deze bewoner?
function isEersteKlusBij(app, helperId, bewonerId) {
  var eerder = zoekAlle(
    app,
    "hh_klussen",
    'hulpvrager = {:bewoner} && toegewezen_jongere = {:helper} && status != "open" && status != "concept" && status != "geannuleerd"',
    { bewoner: bewonerId, helper: helperId },
    "",
    1
  );
  return eerder.length === 0;
}

/// Het adres van de ouder: uit de gegeven toestemming (B3), anders het adres
/// dat de helper zelf invulde.
function ouderEmailVan(app, helper) {
  var rij = zoekEerste(app, "hh_ouder_toestemming", 'helper = {:helper} && status = "gegeven"', { helper: helper.id });
  var email = rij ? tekst(rij.get("ouder_email")) : "";
  if (!email) email = tekst(helper.get("ouder_email"));
  return email.toLowerCase();
}

function isNepAdres(email) {
  return /\.(invalid|test|example|localhost)$/i.test(tekst(email));
}

// --------------------------------------------------------------------------
// MELDINGEN (via env.app; idempotent op ontvanger + soort + sleutel)
// --------------------------------------------------------------------------

function maakMelding(env, m) {
  var app = env.app;
  var bestaand = zoekEerste(app, "hh_meldingen", "ontvanger = {:o} && soort = {:s} && sleutel = {:k}", {
    o: m.ontvanger, s: MELDING_SOORT, k: m.sleutel,
  });
  if (bestaand) return false;
  var r = new env.Record(app.findCollectionByNameOrId("hh_meldingen"));
  r.set("ontvanger", m.ontvanger);
  r.set("soort", MELDING_SOORT);
  if (m.klus) r.set("klus", m.klus);
  r.set("titel", String(m.titel || "").slice(0, 200));
  r.set("tekst", String(m.tekst || "").slice(0, 600));
  r.set("sleutel", m.sleutel);
  app.save(r);
  return true;
}

/// Wat een fout in een melding ook is: de reactie zelf gaat altijd door.
function veiligMelden(env, m) {
  try {
    return maakMelding(env, m);
  } catch (err) {
    env.log("[hh_reacties] melding aan " + m.ontvanger + " mislukt:", String(err));
    return false;
  }
}

/// Bewoner: "X wil je helpen", GEBUNDELD. Staat er nog een ongelezen
/// reactie-melding van deze klus, dan wordt die bijgewerkt ("Sanne en Ruud
/// willen je helpen"); anders komt er een nieuwe.
function meldBewoner(env, klus, nieuweReactieId) {
  try {
    var app = env.app;
    var bewoner = tekst(klus.get("hulpvrager"));
    if (!bewoner) return;
    var open = zoekAlle(app, COLLECTIE, "klus = {:klus} && status = {:open}", { klus: klus.id, open: STATUS.OPEN }, "-created");
    var namen = [];
    for (var i = 0; i < open.length; i++) {
      var h = zoekId(app, "hh_users", tekst(open[i].get("helper")));
      namen.push(h ? voornaam(h.get("naam")) || "Een helper" : "Een helper");
    }
    if (!namen.length) return;
    var info = klusInfo(env, klus);
    var t = env.dep.teksten.reactieBewoner(namen, info.klussoort, info.wanneer);
    var bestaand = zoekEerste(
      app,
      "hh_meldingen",
      'ontvanger = {:o} && soort = {:s} && klus = {:klus} && gelezen_op = "" && sleutel ~ {:pre}',
      { o: bewoner, s: MELDING_SOORT, klus: klus.id, pre: "reacties:" }
    );
    if (bestaand) {
      bestaand.set("titel", t.titel.slice(0, 200));
      bestaand.set("tekst", t.tekst.slice(0, 600));
      app.save(bestaand);
      return;
    }
    maakMelding(env, { ontvanger: bewoner, klus: klus.id, titel: t.titel, tekst: t.tekst, sleutel: "reacties:" + klus.id + ":" + nieuweReactieId });
  } catch (err) {
    env.log("[hh_reacties] melding aan de bewoner mislukt:", String(err));
  }
}

/// Na kiezen: de reactie-meldingen van deze klus bij de bewoner op gelezen.
function bewonerMeldingenGelezen(env, klus) {
  try {
    var lijst = zoekAlle(env.app, "hh_meldingen", 'ontvanger = {:o} && soort = {:s} && klus = {:klus} && gelezen_op = ""', {
      o: tekst(klus.get("hulpvrager")), s: MELDING_SOORT, klus: klus.id,
    });
    for (var i = 0; i < lijst.length; i++) {
      lijst[i].set("gelezen_op", isoVan(env.nu()));
      env.app.save(lijst[i]);
    }
  } catch (err) {
    env.log("[hh_reacties] meldingen op gelezen zetten mislukt:", String(err));
  }
}

// --------------------------------------------------------------------------
// DE ECHTE OMGEVING (JSVM)
// --------------------------------------------------------------------------

/// hulp.jsvmOmgeving({ app: $app, Record, security: $security, MailerMessage,
///   os: $os, dep: {...} }). Mail via de bestaande B3-weg (afzender
///   "HeitjeHulp", HH_MAIL_AFZENDER) met hh_ouder_hulp.jsvmOmgeving.
function jsvmOmgeving(g) {
  var ouder = g.dep.ouder.jsvmOmgeving({ app: g.app, Record: g.Record, security: g.security, MailerMessage: g.MailerMessage, os: g.os });
  return {
    app: g.app,
    Record: g.Record,
    nu: function () {
      return Date.now();
    },
    willekeurig: ouder.willekeurig,
    sha256: ouder.sha256,
    mail: ouder.mail,
    store: g.app.store(),
    log: function () {
      console.log.apply(console, arguments);
    },
    dep: g.dep,
  };
}

/// Voor elke handler in hh_reacties.pb.js: de omgeving met alle
/// hulpbestanden. [g.require] en [g.hooks] (= __hooks) geeft de hook mee.
function hookOmgeving(g) {
  var r = function (naam) {
    return g.require(g.hooks + "/" + naam);
  };
  return jsvmOmgeving({
    app: g.app,
    Record: g.Record,
    security: g.security,
    MailerMessage: g.MailerMessage,
    os: g.os,
    dep: {
      aanmelden: r("hh_aanmelden_hulp.js"),
      plaatsen: r("hh_klusplaatsen_hulp.js"),
      meldingen: r("hh_meldingen_hulp.js"),
      chat: r("hh_chat_hulp.js"),
      ouder: r("hh_ouder_hulp.js"),
      teksten: r("hh_reacties_teksten.js"),
    },
  });
}

module.exports = {
  COLLECTIE: COLLECTIE,
  STATUS: STATUS,
  STATUSSEN: STATUSSEN,
  MAX_BERICHT: MAX_BERICHT,
  MAX_ACTIEF_PER_HELPER: MAX_ACTIEF_PER_HELPER,
  TOKEN_LENGTE: TOKEN_LENGTE,
  TEKENS: TEKENS,
  BESCHIKBAAR_MS: BESCHIKBAAR_MS,
  STANDAARD_DUUR_MS: STANDAARD_DUUR_MS,
  VOLWASSEN: VOLWASSEN,
  OUDER_MEE_VANAF: OUDER_MEE_VANAF,
  OUDER_MEE_TOT_EN_MET: OUDER_MEE_TOT_EN_MET,
  MAX_PER_IP_PER_UUR: MAX_PER_IP_PER_UUR,
  MAX_TELLEN: MAX_TELLEN,
  MELDING_SOORT: MELDING_SOORT,
  NIVEAU_NIEUW: NIVEAU_NIEUW,
  BASIS_URL: BASIS_URL,
  LINK_PAD: LINK_PAD,
  TOELICHTING_GEKOZEN: TOELICHTING_GEKOZEN,
  TOELICHTING_GEKOZEN_MELDKAMER: TOELICHTING_GEKOZEN_MELDKAMER,
  INSTELLING_ACCEPTEREN_DICHT: INSTELLING_ACCEPTEREN_DICHT,
  INSTELLING_ALLEEN_BESCHIKBAAR: INSTELLING_ALLEEN_BESCHIKBAAR,
  INSTELLING_ONDER18_OPEN: INSTELLING_ONDER18_OPEN,
  INCIDENT_SOORT_SIGNAAL: INCIDENT_SOORT_SIGNAAL,
  GEHEIME_VELDEN: GEHEIME_VELDEN,
  BEZET_STATUSSEN: BEZET_STATUSSEN,
  tweeCijfers: tweeCijfers,
  isoVan: isoVan,
  msVan: msVan,
  tekst: tekst,
  voornaam: voornaam,
  vandaagVan: vandaagVan,
  schoonBericht: schoonBericht,
  waarVoorOuder: waarVoorOuder,
  overlapt: overlapt,
  linkVoor: linkVoor,
  tokenHash: tokenHash,
  zoektOpGeheim: zoektOpGeheim,
  antwoord: antwoord,
  ok: ok,
  zoekId: zoekId,
  zoekAlle: zoekAlle,
  zoekEerste: zoekEerste,
  instellingAan: instellingAan,
  profielVan: profielVan,
  wijkInfo: wijkInfo,
  klusInfo: klusInfo,
  leeftijdNodig: leeftijdNodig,
  helperBlokkade: helperBlokkade,
  blokkadeMelding: blokkadeMelding,
  klusBlokkade: klusBlokkade,
  isEersteKlusBij: isEersteKlusBij,
  ouderEmailVan: ouderEmailVan,
  isNepAdres: isNepAdres,
  maakMelding: maakMelding,
  veiligMelden: veiligMelden,
  meldBewoner: meldBewoner,
  bewonerMeldingenGelezen: bewonerMeldingenGelezen,
  jsvmOmgeving: jsvmOmgeving,
  hookOmgeving: hookOmgeving,
};

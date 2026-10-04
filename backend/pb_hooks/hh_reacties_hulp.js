// HeitjeHulp B5 — hh_reacties_hulp.js (hulpbestand, GEEN hook)
//
// Reageren en kiezen (match). Bewust .js en niet .pb.js: PocketBase laadt
// alleen *.pb.js als hook. hh_reacties.pb.js haalt dit bestand BINNEN de
// handler op en geeft een omgeving mee, zodat dit bestand niet op de globals
// van de JSVM leunt en backend/tests/hh_reacties_hulp.test.mjs het zonder
// server en zonder mail kan toetsen:
//   env = { app ($app of txApp), Record, nu() -> ms, willekeurig(lengte, alfabet),
//           sha256(tekst), mail({aan, onderwerp, tekst, html}) (gooit bij een
//           fout), store {get, set}, log(...),
//           dep: { aanmelden, plaatsen, meldingen, chat, teksten } }
// dep = de andere hulpbestanden (hh_aanmelden_hulp, hh_klusplaatsen_hulp,
// hh_meldingen_hulp, hh_chat_hulp, hh_reacties_teksten). Die worden alleen
// GELEZEN, niet aangepast.
//
// DE STAPPEN (zie ook backend/SCHEMA.txt sectie B5)
//   reageer        helper -> reactie op een open klus. Zelfde voorwaarden als
//                  accepteren (M5/B2/B4). Klus blijft open. <18: status
//                  wacht_op_ouder + mail aan de ouder (link met token); 18+:
//                  open + gebundelde melding aan de bewoner.
//   ouderStand / ouderBesluit  (publiek, met de token uit de mail) "Goed" ->
//                  open (bewoner ziet hem), "Liever niet" -> afgewezen.
//                  Verloopt als de klus begint of niet meer open is.
//   reactiesVoorBewoner  wat KiesHelper toont: voornaam, leeftijd, niveau,
//                  sterren, aantal, ID gecontroleerd, laatste recensie,
//                  berichtje. NOOIT achternaam, geboortedatum of adres.
//   kies           bewoner (of meldkamer) kiest in EEN transactie; precies één
//                  winnaar, ook als dezelfde helper tegelijk voor twee
//                  klussen op hetzelfde moment gekozen wordt.
//   trekIn         helper trekt zijn reactie in vóór het kiezen.
//   naKlusWissel   na elke logregel (ook koppelen/accepteren/annuleren): de
//                  reacties bijwerken.
//   nakijkenMelding  de M8-melding "toegewezen" wordt "Het is een match!";
//                  "nieuwe klus" alleen aan wie nu kan helpen (schakelaar).
//   zetBeschikbaar / telBeschikbaar  "Ik kan nu helpen" (3 uur).
//   verwerkGeheim  geheime vraag na de klus: "nee" -> incident.
//
// INDELING (bestanden max 800 regels): hh_reacties_basis.js (gedeeld),
// dit bestand (reageren, intrekken, ouder, KiesHelper, kiezen) en
// hh_reacties_na.js (na een statuswissel, meldingen nakijken, "Ik kan nu
// helpen", geheime vraag, verrijken). Dit bestand exporteert ook alles van
// de andere twee, zodat een hook maar één bestand hoeft op te halen.

var HOOKS = typeof __hooks !== "undefined" ? __hooks : "";
var basis = require(HOOKS + "/hh_reacties_basis.js");
var instellingAan = basis.instellingAan;
var INSTELLING_ONDER18_OPEN = basis.INSTELLING_ONDER18_OPEN;
var COLLECTIE = basis.COLLECTIE;
var STATUS = basis.STATUS;
var MAX_ACTIEF_PER_HELPER = basis.MAX_ACTIEF_PER_HELPER;
var TOKEN_LENGTE = basis.TOKEN_LENGTE;
var TEKENS = basis.TEKENS;
var VOLWASSEN = basis.VOLWASSEN;
var OUDER_MEE_VANAF = basis.OUDER_MEE_VANAF;
var OUDER_MEE_TOT_EN_MET = basis.OUDER_MEE_TOT_EN_MET;
var MAX_PER_IP_PER_UUR = basis.MAX_PER_IP_PER_UUR;
var MELDING_SOORT = basis.MELDING_SOORT;
var NIVEAU_NIEUW = basis.NIVEAU_NIEUW;
var BASIS_URL = basis.BASIS_URL;
var TOELICHTING_GEKOZEN = basis.TOELICHTING_GEKOZEN;
var TOELICHTING_GEKOZEN_MELDKAMER = basis.TOELICHTING_GEKOZEN_MELDKAMER;
var BEZET_STATUSSEN = basis.BEZET_STATUSSEN;
var isoVan = basis.isoVan;
var msVan = basis.msVan;
var tekst = basis.tekst;
var voornaam = basis.voornaam;
var vandaagVan = basis.vandaagVan;
var schoonBericht = basis.schoonBericht;
var waarVoorOuder = basis.waarVoorOuder;
var overlapt = basis.overlapt;
var linkVoor = basis.linkVoor;
var tokenHash = basis.tokenHash;
var antwoord = basis.antwoord;
var ok = basis.ok;
var zoekId = basis.zoekId;
var zoekAlle = basis.zoekAlle;
var zoekEerste = basis.zoekEerste;
var profielVan = basis.profielVan;
var klusInfo = basis.klusInfo;
var leeftijdNodig = basis.leeftijdNodig;
var helperBlokkade = basis.helperBlokkade;
var blokkadeMelding = basis.blokkadeMelding;
var klusBlokkade = basis.klusBlokkade;
var isEersteKlusBij = basis.isEersteKlusBij;
var ouderEmailVan = basis.ouderEmailVan;
var isNepAdres = basis.isNepAdres;
var veiligMelden = basis.veiligMelden;
var meldBewoner = basis.meldBewoner;
var bewonerMeldingenGelezen = basis.bewonerMeldingenGelezen;
var na = require(HOOKS + "/hh_reacties_na.js");

// --------------------------------------------------------------------------
// REAGEREN
// --------------------------------------------------------------------------

///   invoer = { helper (record), klusId, bericht, ouderGaatMee }
function reageer(env, invoer) {
  var app = env.app;
  var helper = invoer.helper;
  var blok = helperBlokkade(env, helper);
  if (blok === "rol" || blok === "geenwijk" || blok === "nietgoedgekeurd") return antwoord(env, 403, blok);
  if (blok) return { status: 403, body: { melding: blokkadeMelding(env, helper, blok), reden: blok } };

  var bericht = schoonBericht(invoer.bericht, env.dep.chat.filterTekst);
  if (!bericht.ok) return antwoord(env, 400, "bericht");

  var klus = zoekId(app, "hh_klussen", tekst(invoer.klusId));
  if (!klus) return antwoord(env, 404, "nietgevonden");
  var kb = klusBlokkade(env, klus, helper);
  if (kb && kb.reden === "leeftijd") {
    return { status: 403, body: { melding: "Deze klus is pas vanaf " + kb.nodig + " jaar.", reden: "leeftijd" } };
  }
  if (kb) return antwoord(env, kb.status, kb.reden);

  var bestaand = zoekEerste(app, COLLECTIE, "klus = {:klus} && helper = {:helper}", { klus: klus.id, helper: helper.id });
  if (bestaand) {
    var s = tekst(bestaand.get("status"));
    if (s === STATUS.OPEN || s === STATUS.WACHT) return antwoord(env, 409, "algereageerd");
    if (s === STATUS.GEKOZEN) return antwoord(env, 409, "bezet");
  }
  var actief = zoekAlle(app, COLLECTIE, "helper = {:helper} && (status = {:a} || status = {:b})", {
    helper: helper.id, a: STATUS.OPEN, b: STATUS.WACHT,
  });
  if (actief.length >= MAX_ACTIEF_PER_HELPER) return antwoord(env, 429, "limiet");

  var jaren = env.dep.aanmelden.leeftijd(tekst(helper.get("geboortedatum")), vandaagVan(env.nu()));
  var minderjarig = jaren === null || jaren < VOLWASSEN;
  // Antwoord Ibrahim 5: onder 18 pas als de ouder-pagina online is.
  if (minderjarig && !instellingAan(app, INSTELLING_ONDER18_OPEN)) return antwoord(env, 409, "onder18");
  var bewonerId = tekst(klus.get("hulpvrager"));
  var ouderMee = invoer.ouderGaatMee === true;
  if (jaren !== null && jaren >= OUDER_MEE_VANAF && jaren <= OUDER_MEE_TOT_EN_MET && !ouderMee &&
      isEersteKlusBij(app, helper.id, bewonerId)) {
    return antwoord(env, 400, "oudermee");
  }

  var ouderEmail = minderjarig ? ouderEmailVan(app, helper) : "";
  if (minderjarig && !ouderEmail) return antwoord(env, 409, "geenouder");

  var info = klusInfo(env, klus);
  var token = minderjarig ? env.willekeurig(TOKEN_LENGTE, TEKENS) : "";
  var rij = bestaand || new env.Record(app.findCollectionByNameOrId(COLLECTIE));
  var vorige = bestaand ? momentopname(bestaand) : null;
  rij.set("klus", klus.id);
  rij.set("helper", helper.id);
  rij.set("bericht", bericht.tekst);
  rij.set("bericht_gefilterd", bericht.gefilterd);
  rij.set("status", minderjarig ? STATUS.WACHT : STATUS.OPEN);
  rij.set("ouder_gaat_mee", ouderMee);
  rij.set("ouder_akkoord_op", "");
  rij.set("ouder_besluit", "");
  rij.set("gekozen_op", "");
  rij.set("token_hash", minderjarig ? tokenHash(env.sha256, token) : "");
  rij.set("ouder_gemaild_op", minderjarig ? isoVan(env.nu()) : "");
  rij.set("klus_samenvatting", env.dep.teksten.klusRegel(info.klussoort, info.wanneer).slice(0, 200));
  try {
    app.save(rij);
  } catch (err) {
    // Twee tikken tegelijk: de unieke index (klus, helper) houdt de tweede tegen.
    return antwoord(env, 409, "algereageerd");
  }

  if (minderjarig) {
    var bewoner = zoekId(app, "hh_users", bewonerId);
    var mail = env.dep.teksten.ouderKlusMail({
      helperVoornaam: voornaam(helper.get("naam")),
      klussoort: info.klussoort,
      omschrijving: tekst(klus.get("omschrijving")),
      waar: waarVoorOuder(klus.get("adres"), bewoner ? bewoner.get("plaats") : ""),
      wanneer: info.wanneer,
      bewonerVoornaam: bewoner ? voornaam(bewoner.get("naam")) : "",
      ouderGaatMee: ouderMee,
      link: linkVoor(BASIS_URL, token),
    });
    if (isNepAdres(ouderEmail)) {
      env.log("[hh_reacties] nep-adres, geen ouder-mail (reactie " + rij.id + ")");
    } else {
      try {
        env.mail({ aan: ouderEmail, onderwerp: mail.onderwerp, tekst: mail.tekst, html: mail.html });
      } catch (err) {
        env.log("[hh_reacties] ouder-mail mislukt (reactie " + rij.id + "):", String(err));
        herstel(app, rij, vorige);
        return antwoord(env, 502, "mail");
      }
    }
  } else {
    meldBewoner(env, klus, rij.id);
  }

  return ok({
    melding: env.dep.teksten.MELDING[minderjarig ? "verstuurdOuder" : "verstuurd"],
    reactie: rij.id,
    klus: klus.id,
    status: tekst(rij.get("status")),
  });
}

var HERSTEL_VELDEN = [
  "bericht", "bericht_gefilterd", "status", "ouder_gaat_mee", "ouder_akkoord_op", "ouder_besluit",
  "gekozen_op", "token_hash", "ouder_gemaild_op", "klus_samenvatting",
];

function momentopname(rij) {
  var m = {};
  for (var i = 0; i < HERSTEL_VELDEN.length; i++) m[HERSTEL_VELDEN[i]] = rij.get(HERSTEL_VELDEN[i]);
  return m;
}

/// Mail mislukt: een nieuwe rij weer weg, een hergebruikte rij terug.
function herstel(app, rij, vorige) {
  try {
    if (!vorige) {
      app.delete(rij);
      return;
    }
    for (var k in vorige) rij.set(k, vorige[k]);
    app.save(rij);
  } catch (_) {
    // Lukt ook dat niet: de rij staat op wacht_op_ouder zonder mail; de
    // ouder ziet hem nooit en hij vervalt als de klus begint.
  }
}

// --------------------------------------------------------------------------
// INTREKKEN
// --------------------------------------------------------------------------

///   invoer = { helperId, reactieId }
function trekIn(env, invoer) {
  var rij = zoekId(env.app, COLLECTIE, tekst(invoer.reactieId));
  if (!rij || tekst(rij.get("helper")) !== tekst(invoer.helperId)) return antwoord(env, 404, "nietvanjou");
  var s = tekst(rij.get("status"));
  if (s !== STATUS.OPEN && s !== STATUS.WACHT) return antwoord(env, 409, "status");
  rij.set("status", STATUS.INGETROKKEN);
  env.app.save(rij);
  // Was hij al zichtbaar: de gebundelde melding van de bewoner bijwerken.
  if (s === STATUS.OPEN) {
    var klus = zoekId(env.app, "hh_klussen", tekst(rij.get("klus")));
    if (klus) meldBewonerNaIntrekken(env, klus);
  }
  return ok({ melding: env.dep.teksten.MELDING.ingetrokken, reactie: rij.id, status: STATUS.INGETROKKEN });
}

/// Na intrekken alleen een ONGELEZEN bundel bijwerken (nooit een nieuwe).
function meldBewonerNaIntrekken(env, klus) {
  try {
    var app = env.app;
    var bestaand = zoekEerste(
      app,
      "hh_meldingen",
      'ontvanger = {:o} && soort = {:s} && klus = {:klus} && gelezen_op = "" && sleutel ~ {:pre}',
      { o: tekst(klus.get("hulpvrager")), s: MELDING_SOORT, klus: klus.id, pre: "reacties:" }
    );
    if (!bestaand) return;
    var open = zoekAlle(app, COLLECTIE, "klus = {:klus} && status = {:open}", { klus: klus.id, open: STATUS.OPEN }, "-created");
    if (!open.length) {
      bestaand.set("gelezen_op", isoVan(env.nu()));
      app.save(bestaand);
      return;
    }
    var namen = [];
    for (var i = 0; i < open.length; i++) {
      var h = zoekId(app, "hh_users", tekst(open[i].get("helper")));
      namen.push(h ? voornaam(h.get("naam")) : "Een helper");
    }
    var info = klusInfo(env, klus);
    var t = env.dep.teksten.reactieBewoner(namen, info.klussoort, info.wanneer);
    bestaand.set("titel", t.titel);
    bestaand.set("tekst", t.tekst);
    app.save(bestaand);
  } catch (err) {
    env.log("[hh_reacties] bundel bijwerken na intrekken mislukt:", String(err));
  }
}

// --------------------------------------------------------------------------
// OUDER (publiek, met de token uit de mail)
// --------------------------------------------------------------------------

function binnenIpGrens(env, ip) {
  var sleutel = "hh_reacties_ip:" + String(ip || "onbekend") + ":" + Math.floor(env.nu() / 3600000);
  var aantal = Number(env.store.get(sleutel) || 0);
  if (aantal >= MAX_PER_IP_PER_UUR) return false;
  env.store.set(sleutel, aantal + 1);
  return true;
}

function rijVanToken(env, token) {
  var t = tekst(token);
  if (!t || t.length < 20) return null;
  return zoekEerste(env.app, COLLECTIE, "token_hash = {:h}", { h: tokenHash(env.sha256, t) });
}

/// Is de vraag aan de ouder verlopen? (klus begonnen, niet meer open, al
/// een helper, of de reactie vervallen/ingetrokken.)
function isVerlopen(env, rij, klus) {
  if (!klus) return true;
  var s = tekst(rij.get("status"));
  if (s === STATUS.VERVALLEN || s === STATUS.INGETROKKEN) return true;
  if (s !== STATUS.WACHT) return false;
  if (tekst(klus.get("status")) !== "open" || tekst(klus.get("toegewezen_jongere"))) return true;
  var van = msVan(klus.get("wanneer_van"));
  return !!van && van <= env.nu();
}

function standVoorOuder(env, rij) {
  var app = env.app;
  var klus = zoekId(app, "hh_klussen", tekst(rij.get("klus")));
  var helper = zoekId(app, "hh_users", tekst(rij.get("helper")));
  var s = tekst(rij.get("status"));
  var besluit = tekst(rij.get("ouder_besluit"));
  var stand;
  if (besluit === "goed") stand = "goed";
  else if (besluit === "liever_niet") stand = "lieverniet";
  else if (s === STATUS.INGETROKKEN) stand = "ingetrokken";
  else if (isVerlopen(env, rij, klus)) stand = "verlopen";
  else stand = "wacht";
  var body = {
    status: stand,
    helper_voornaam: helper ? voornaam(helper.get("naam")) : "",
    ouder_gaat_mee: rij.get("ouder_gaat_mee") === true,
    klus: { wat: "", omschrijving: "", waar: "", wanneer: "", bewoner_voornaam: "" },
  };
  if (klus) {
    var info = klusInfo(env, klus);
    var bewoner = zoekId(app, "hh_users", tekst(klus.get("hulpvrager")));
    body.klus = {
      wat: env.dep.teksten.metHoofdletter(info.klussoort),
      omschrijving: tekst(klus.get("omschrijving")),
      waar: waarVoorOuder(klus.get("adres"), bewoner ? bewoner.get("plaats") : ""),
      wanneer: info.wanneer,
      bewoner_voornaam: bewoner ? voornaam(bewoner.get("naam")) : "",
    };
  }
  return body;
}

/// Verlopen = de rij gaat op vervallen (alleen een wachtende).
function vervalAls(env, rij) {
  var klus = zoekId(env.app, "hh_klussen", tekst(rij.get("klus")));
  if (tekst(rij.get("status")) === STATUS.WACHT && isVerlopen(env, rij, klus)) {
    rij.set("status", STATUS.VERVALLEN);
    env.app.save(rij);
  }
}

///   invoer = { token, ip }
function ouderStand(env, invoer) {
  if (!binnenIpGrens(env, invoer.ip)) return antwoord(env, 429, "teveel");
  var rij = rijVanToken(env, invoer.token);
  if (!rij) return antwoord(env, 404, "link");
  vervalAls(env, rij);
  return ok(standVoorOuder(env, rij));
}

///   invoer = { token, besluit: "goed" | "lieverniet", ip }
function ouderBesluit(env, invoer) {
  if (!binnenIpGrens(env, invoer.ip)) return antwoord(env, 429, "teveel");
  var besluit = tekst(invoer.besluit);
  if (besluit !== "goed" && besluit !== "lieverniet") return antwoord(env, 400, "besluit");
  var rij = rijVanToken(env, invoer.token);
  if (!rij) return antwoord(env, 404, "link");
  vervalAls(env, rij);
  var gezet = false;
  env.app.runInTransaction(function (tx) {
    var vers = zoekId(tx, COLLECTIE, rij.id);
    if (!vers || tekst(vers.get("status")) !== STATUS.WACHT || tekst(vers.get("ouder_besluit"))) return;
    if (besluit === "goed") {
      vers.set("status", STATUS.OPEN);
      vers.set("ouder_besluit", "goed");
      vers.set("ouder_akkoord_op", isoVan(env.nu()));
    } else {
      vers.set("status", STATUS.AFGEWEZEN);
      vers.set("ouder_besluit", "liever_niet");
    }
    tx.save(vers);
    rij = vers;
    gezet = true;
  });
  if (gezet) {
    var klus = zoekId(env.app, "hh_klussen", tekst(rij.get("klus")));
    if (klus) {
      var info = klusInfo(env, klus);
      var t = env.dep.teksten.ouderBesluit(besluit, info.klussoort, info.wanneer);
      veiligMelden(env, { ontvanger: tekst(rij.get("helper")), klus: klus.id, titel: t.titel, tekst: t.tekst, sleutel: "ouder:" + rij.id });
      if (besluit === "goed") meldBewoner(env, klus, rij.id);
    }
  }
  return ok(standVoorOuder(env, rij));
}

// --------------------------------------------------------------------------
// BEWONER: de reacties op zijn klus (KiesHelper)
// --------------------------------------------------------------------------

function magKiezen(kijker, klus) {
  if (!kijker || !kijker.id) return false;
  if (kijker.rol === "coordinator") return true;
  return kijker.rol === "hulpvrager" && tekst(klus.get("hulpvrager")) === kijker.id;
}

/// De laatste recensie MET tekst, één regel, hooguit 120 tekens.
function laatsteRecensie(app, helperId) {
  var lijst = zoekAlle(app, "hh_beoordelingen", 'naar_gebruiker = {:h} && tekst != ""', { h: helperId }, "-created", 1);
  if (!lijst.length) return "";
  return tekst(String(lijst[0].get("tekst")).split(/\r?\n/)[0]).slice(0, 120);
}

function helperKaart(env, rij, helper) {
  var app = env.app;
  var beoordelingen = zoekAlle(app, "hh_beoordelingen", "naar_gebruiker = {:h} && sterren > 0", { h: helper.id });
  var profiel = profielVan(app, helper.id);
  return {
    reactie: rij.id,
    helper: helper.id,
    voornaam: voornaam(helper.get("naam")),
    leeftijd: env.dep.aanmelden.leeftijd(tekst(helper.get("geboortedatum")), vandaagVan(env.nu())),
    niveau: NIVEAU_NIEUW,
    sterren: Number(helper.get("sterren_gemiddeld") || 0),
    beoordelingen: beoordelingen.length,
    id_gecontroleerd: !!(profiel && tekst(profiel.get("id_gecontroleerd_op"))),
    laatste_recensie: laatsteRecensie(app, helper.id),
    bericht: tekst(rij.get("bericht")),
    ouder_gaat_mee: rij.get("ouder_gaat_mee") === true,
    ouder_akkoord: !!tekst(rij.get("ouder_akkoord_op")),
    created: tekst(rij.get("created")),
  };
}

///   invoer = { kijker: {id, rol}, klusId }
function reactiesVoorBewoner(env, invoer) {
  var klus = zoekId(env.app, "hh_klussen", tekst(invoer.klusId));
  if (!klus) return antwoord(env, 404, "nietgevonden");
  if (!magKiezen(invoer.kijker, klus)) return antwoord(env, 403, "geenbewoner");
  var rijen = zoekAlle(env.app, COLLECTIE, "klus = {:klus} && status = {:open}", { klus: klus.id, open: STATUS.OPEN }, "created");
  var kaarten = [];
  for (var i = 0; i < rijen.length; i++) {
    var helper = zoekId(env.app, "hh_users", tekst(rijen[i].get("helper")));
    // Een helper die intussen niet meer mag (geblokkeerd, ouder trok in)
    // laat de bewoner niet zien.
    if (!helper || helperBlokkade(env, helper)) continue;
    kaarten.push(helperKaart(env, rijen[i], helper));
  }
  return ok({ klus: klus.id, status: tekst(klus.get("status")), reacties: kaarten });
}

// --------------------------------------------------------------------------
// KIEZEN (de match)
// --------------------------------------------------------------------------

///   invoer = { kijker: {id, rol}, klusId, reactieId }
/// Fouten van binnen runInTransaction verliezen hun statuscode; daarom zet
/// de transactie alleen een uitkomst en gooit niets.
function kies(env, invoer) {
  var app = env.app;
  var reactieId = tekst(invoer.reactieId);
  if (!reactieId) return antwoord(env, 400, "geenreactie");
  var klus = zoekId(app, "hh_klussen", tekst(invoer.klusId));
  if (!klus) return antwoord(env, 404, "nietgevonden");
  if (!magKiezen(invoer.kijker, klus)) return antwoord(env, 403, "geenbewoner");
  var rij = zoekId(app, COLLECTIE, reactieId);
  if (!rij || tekst(rij.get("klus")) !== klus.id) return antwoord(env, 409, "reactieweg");
  var helper = zoekId(app, "hh_users", tekst(rij.get("helper")));

  // Mag deze helper nog (blokkade, leeftijd)? Lezen vóór de transactie.
  var magNiet = !helper || !!helperBlokkade(env, helper);
  if (!magNiet) {
    var info0 = klusInfo(env, klus);
    magNiet = leeftijdNodig(env, klus, helper.get("geboortedatum"), info0.typeMin) > 0;
  }
  if (magNiet) {
    if (tekst(rij.get("status")) === STATUS.OPEN) {
      rij.set("status", STATUS.VERVALLEN);
      app.save(rij);
    }
    return antwoord(env, 409, "reactieweg");
  }

  var uitkomst = "";
  var anderen = [];
  var door = invoer.kijker.id;
  var toelichting = invoer.kijker.rol === "coordinator" ? TOELICHTING_GEKOZEN_MELDKAMER : TOELICHTING_GEKOZEN;
  app.runInTransaction(function (tx) {
    var k = zoekId(tx, "hh_klussen", klus.id);
    if (!k || tekst(k.get("status")) !== "open" || tekst(k.get("toegewezen_jongere"))) {
      uitkomst = "klusbezet";
      return;
    }
    var r = zoekId(tx, COLLECTIE, reactieId);
    if (!r || tekst(r.get("status")) !== STATUS.OPEN) {
      uitkomst = "reactieweg";
      return;
    }
    // Dezelfde helper niet twee keer op hetzelfde moment (race "2 klussen
    // tegelijk"): de transactie ziet de andere keuze al.
    var lopend = zoekAlle(tx, "hh_klussen", "toegewezen_jongere = {:h}", { h: helper.id });
    for (var i = 0; i < lopend.length; i++) {
      if (BEZET_STATUSSEN.indexOf(tekst(lopend[i].get("status"))) === -1) continue;
      if (overlapt(
        { van: tekst(k.get("wanneer_van")), tot: tekst(k.get("wanneer_tot")) },
        { van: tekst(lopend[i].get("wanneer_van")), tot: tekst(lopend[i].get("wanneer_tot")) }
      )) {
        uitkomst = "helperbezet";
        return;
      }
    }
    k.set("toegewezen_jongere", helper.id);
    k.set("status", "geaccepteerd");
    tx.save(k);
    r.set("status", STATUS.GEKOZEN);
    r.set("gekozen_op", isoVan(env.nu()));
    tx.save(r);
    var rest = zoekAlle(tx, COLLECTIE, "klus = {:klus} && (status = {:a} || status = {:b})", {
      klus: k.id, a: STATUS.OPEN, b: STATUS.WACHT,
    });
    for (var j = 0; j < rest.length; j++) {
      if (rest[j].id === r.id) continue;
      var was = tekst(rest[j].get("status"));
      rest[j].set("status", was === STATUS.OPEN ? STATUS.AFGEWEZEN : STATUS.VERVALLEN);
      tx.save(rest[j]);
      if (was === STATUS.OPEN) anderen.push({ reactie: rest[j].id, helper: tekst(rest[j].get("helper")) });
    }
    var log = new env.Record(tx.findCollectionByNameOrId("hh_klus_status"));
    log.set("klus", k.id);
    log.set("door", door);
    log.set("van", "open");
    log.set("naar", "geaccepteerd");
    log.set("toelichting", toelichting);
    tx.save(log);
    uitkomst = "ok";
  });

  if (uitkomst !== "ok") return antwoord(env, 409, uitkomst || "klusbezet");

  var info = klusInfo(env, klus);
  var t = env.dep.teksten.nietGekozen(info.klussoort, info.wanneer);
  for (var a = 0; a < anderen.length; a++) {
    veiligMelden(env, { ontvanger: anderen[a].helper, klus: klus.id, titel: t.titel, tekst: t.tekst, sleutel: "afgewezen:" + anderen[a].reactie });
  }
  bewonerMeldingenGelezen(env, klus);
  return ok({
    melding: env.dep.teksten.MELDING.match,
    klus: klus.id,
    status: "geaccepteerd",
    toegewezen_jongere: helper.id,
    reactie: reactieId,
    helper_voornaam: voornaam(helper.get("naam")),
  });
}

var uit = {};
var k;
for (k in basis) uit[k] = basis[k];
for (k in na) uit[k] = na[k];
uit.reageer = reageer;
uit.trekIn = trekIn;
uit.ouderStand = ouderStand;
uit.ouderBesluit = ouderBesluit;
uit.reactiesVoorBewoner = reactiesVoorBewoner;
uit.kies = kies;
module.exports = uit;

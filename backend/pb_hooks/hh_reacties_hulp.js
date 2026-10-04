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
  var bewonerId = tekst(klus.get("hulpvrager"));
  var ouderMee = invoer.ouderGaatMee === true;
  if (jaren !== null && jaren >= OUDER_MEE_VANAF && jaren <= OUDER_MEE_TOT_EN_MET && !ouderMee &&
      isEersteKlusBij(app, helper.id, bewonerId)) {
    return antwoord(env, 400, "oudermee");
  }

  var minderjarig = jaren === null || jaren < VOLWASSEN;
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

// --------------------------------------------------------------------------
// NA EEN STATUSWISSEL (elke logregel, ook van koppelen/accepteren/annuleren)
// --------------------------------------------------------------------------

/// Geeft het aantal bijgewerkte reacties terug.
function naKlusWissel(env, log) {
  var app = env.app;
  var klusId = tekst(log.get("klus"));
  var van = tekst(log.get("van"));
  var naar = tekst(log.get("naar"));
  var klus = zoekId(app, "hh_klussen", klusId);
  if (!klus) return 0;
  var aantal = 0;
  var info = null;
  var meld = function (rij, t, voorvoegsel) {
    veiligMelden(env, { ontvanger: tekst(rij.get("helper")), klus: klusId, titel: t.titel, tekst: t.tekst, sleutel: voorvoegsel + rij.id });
  };

  if (naar === "geaccepteerd" || naar === "geannuleerd") {
    var actief = zoekAlle(app, COLLECTIE, "klus = {:klus} && (status = {:a} || status = {:b})", {
      klus: klusId, a: STATUS.OPEN, b: STATUS.WACHT,
    });
    for (var i = 0; i < actief.length; i++) {
      var rij = actief[i];
      var was = tekst(rij.get("status"));
      // De gekozen helper zelf (accepteren/koppelen van precies hem).
      if (naar === "geaccepteerd" && tekst(rij.get("helper")) === tekst(klus.get("toegewezen_jongere"))) {
        rij.set("status", STATUS.GEKOZEN);
        rij.set("gekozen_op", isoVan(env.nu()));
        app.save(rij);
        aantal++;
        continue;
      }
      var wordt = naar === "geaccepteerd" && was === STATUS.OPEN ? STATUS.AFGEWEZEN : STATUS.VERVALLEN;
      rij.set("status", wordt);
      app.save(rij);
      aantal++;
      if (was !== STATUS.OPEN) continue; // wie nog op de ouder wachtte: stil
      info = info || klusInfo(env, klus);
      if (naar === "geaccepteerd") meld(rij, env.dep.teksten.nietGekozen(info.klussoort, info.wanneer), "afgewezen:");
      else meld(rij, env.dep.teksten.klusGaatNietDoor(info.klussoort, info.wanneer), "vervallen:");
    }
  } else if (naar === "open" && (van === "geaccepteerd" || van === "onderweg")) {
    // De helper gaf hem terug (of de meldkamer/ouder haalde hem eraf).
    var gekozen = zoekAlle(app, COLLECTIE, "klus = {:klus} && status = {:g}", { klus: klusId, g: STATUS.GEKOZEN });
    for (var g = 0; g < gekozen.length; g++) {
      gekozen[g].set("status", STATUS.INGETROKKEN);
      app.save(gekozen[g]);
      aantal++;
    }
  }
  return aantal;
}

/// Cron (elke 10 minuten) en voor de zekerheid: reacties die op de ouder
/// wachten van een klus die al begonnen is, vervallen.
function vervalVerlopen(env) {
  var lijst = zoekAlle(
    env.app,
    COLLECTIE,
    'status = {:w} && klus.wanneer_van != "" && klus.wanneer_van <= {:nu}',
    { w: STATUS.WACHT, nu: isoVan(env.nu()) },
    "",
    200
  );
  for (var i = 0; i < lijst.length; i++) {
    lijst[i].set("status", STATUS.VERVALLEN);
    env.app.save(lijst[i]);
  }
  return lijst.length;
}

// --------------------------------------------------------------------------
// MELDINGEN NAKIJKEN (onRecordCreate hh_meldingen, model-hook)
// --------------------------------------------------------------------------

/// -> { opslaan } of { opslaan, titel, tekst }
function nakijkenMelding(env, melding) {
  var app = env.app;
  var soort = tekst(melding.get("soort"));
  var ontvanger = tekst(melding.get("ontvanger"));

  if (soort === "nieuwe_klus") {
    if (!instellingAan(app, INSTELLING_ALLEEN_BESCHIKBAAR)) return { opslaan: true };
    var profiel = profielVan(app, ontvanger);
    var tot = profiel ? msVan(profiel.get("beschikbaar_tot")) : 0;
    return { opslaan: tot > env.nu() };
  }

  if (soort === "toegewezen") {
    var sleutel = tekst(melding.get("sleutel"));
    if (sleutel.indexOf("klusstatus:") !== 0) return { opslaan: true };
    var log = zoekId(app, "hh_klus_status", sleutel.slice("klusstatus:".length));
    if (!log || tekst(log.get("toelichting")).indexOf("gekozen door") !== 0) return { opslaan: true };
    if (ontvanger === tekst(log.get("door"))) return { opslaan: false };
    var klus = zoekId(app, "hh_klussen", tekst(log.get("klus")));
    if (!klus || ontvanger !== tekst(klus.get("toegewezen_jongere"))) return { opslaan: true };
    var bewoner = zoekId(app, "hh_users", tekst(klus.get("hulpvrager")));
    var info = klusInfo(env, klus);
    var t = env.dep.teksten.match(bewoner ? voornaam(bewoner.get("naam")) : "", info.klussoort, info.wanneer);
    return { opslaan: true, titel: t.titel, tekst: t.tekst };
  }
  return { opslaan: true };
}

// --------------------------------------------------------------------------
// IK KAN NU HELPEN (punt 12)
// --------------------------------------------------------------------------

///   invoer = { helper (record), aan (bool) }
function zetBeschikbaar(env, invoer) {
  var helper = invoer.helper;
  if (!helper || tekst(helper.get("rol")) !== "jongere") return antwoord(env, 403, "beschikbaarRol");
  var profiel = profielVan(env.app, helper.id);
  if (!profiel) return antwoord(env, 409, "geenprofiel");
  var tot = invoer.aan === true ? isoVan(env.nu() + BESCHIKBAAR_MS) : "";
  profiel.set("beschikbaar_tot", tot);
  env.app.save(profiel);
  return ok({ beschikbaar_tot: tot, aan: !!tot });
}

///   invoer = { kijker: {id, rol, wijk}, klustypeId, van, tot }
/// Alleen het AANTAL (geen namen): helpers die nu kunnen, binnen het
/// werkgebied van de bewoner, oud genoeg voor deze categorie en tijd.
function telBeschikbaar(env, invoer) {
  var kijker = invoer.kijker || {};
  if (kijker.rol !== "hulpvrager" && kijker.rol !== "coordinator") return antwoord(env, 403, "telRol");
  var app = env.app;
  var type = zoekId(app, "hh_klustypes", tekst(invoer.klustypeId));
  var p = env.dep.plaatsen;
  var van = tekst(invoer.van);
  var min = p.minLeeftijdVoorKlus({
    typeMinLeeftijd: type ? Number(type.get("min_leeftijd") || 0) : undefined,
    van: van,
    tot: tekst(invoer.tot),
  });
  var grens = p.geborenUiterlijk(van || new Date(env.nu()).toISOString(), min);
  var bewonerWijk = wijkInfo(app, kijker.wijk);
  var profielen = zoekAlle(
    app,
    "hh_profielen",
    'beschikbaar_tot > {:nu} && verificatiestatus = "goedgekeurd"',
    { nu: isoVan(env.nu()) },
    "",
    MAX_TELLEN
  );
  var aantal = 0;
  for (var i = 0; i < profielen.length; i++) {
    var helper = zoekId(app, "hh_users", tekst(profielen[i].get("gebruiker")));
    if (!helper || helperBlokkade(env, helper)) continue;
    if (kijker.rol !== "coordinator" && !env.dep.aanmelden.wijkenPassen(bewonerWijk, wijkInfo(app, helper.get("wijk")))) continue;
    if (!p.isOudGenoeg(tekst(helper.get("geboortedatum")), grens)) continue;
    aantal++;
  }
  return ok({ aantal: aantal });
}

// --------------------------------------------------------------------------
// GEHEIME VRAAG (punt 11)
// --------------------------------------------------------------------------

/// "nee" -> één incident (soort probleem) voor de meldkamer, met de klus en
/// de gever als melder. De M8-hook stuurt elke coordinator een melding.
/// Geeft true als er een incident is gemaakt.
function verwerkGeheim(env, beoordeling) {
  if (tekst(beoordeling.get("alles_in_orde")) !== "nee") return false;
  var app = env.app;
  var klusId = tekst(beoordeling.get("klus"));
  var melder = tekst(beoordeling.get("van_gebruiker"));
  if (!melder) return false;
  var bestaand = zoekEerste(app, "hh_incidenten", "klus = {:klus} && melder = {:m} && omschrijving ~ {:merk}", {
    klus: klusId, m: melder, merk: env.dep.teksten.MERK_GEHEIM,
  });
  if (bestaand) return false;
  var gever = zoekId(app, "hh_users", melder);
  var rol = gever ? tekst(gever.get("rol")) : "hulpvrager";
  var r = new env.Record(app.findCollectionByNameOrId("hh_incidenten"));
  if (klusId) r.set("klus", klusId);
  r.set("melder", melder);
  r.set("soort", "probleem");
  r.set("omschrijving", env.dep.teksten.geheimIncident(rol, beoordeling.get("geheim_toelichting")));
  app.save(r);
  return true;
}

// --------------------------------------------------------------------------
// VERRIJKEN (onRecordEnrich hh_klussen)
// --------------------------------------------------------------------------

///   invoer = { kijker: {id, rol}, klus } -> velden erbij, of null
function verrijkKlus(env, invoer) {
  var kijker = invoer.kijker || {};
  var klus = invoer.klus;
  if (kijker.rol === "jongere" && tekst(klus.get("toegewezen_jongere")) !== kijker.id) {
    var actief = zoekAlle(env.app, COLLECTIE, "klus = {:klus} && (status = {:a} || status = {:b})", {
      klus: klus.id, a: STATUS.OPEN, b: STATUS.WACHT,
    });
    var mijn = zoekEerste(env.app, COLLECTIE, "klus = {:klus} && helper = {:h}", { klus: klus.id, h: kijker.id });
    return { reacties_aantal: actief.length, mijn_reactie: mijn ? tekst(mijn.get("status")) : "" };
  }
  if (kijker.rol === "hulpvrager" && tekst(klus.get("hulpvrager")) === kijker.id) {
    var open = zoekAlle(env.app, COLLECTIE, "klus = {:klus} && status = {:o}", { klus: klus.id, o: STATUS.OPEN });
    return { reacties_aantal: open.length };
  }
  return null;
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
  hookOmgeving: hookOmgeving,
  COLLECTIE: COLLECTIE,
  STATUS: STATUS,
  STATUSSEN: STATUSSEN,
  MAX_BERICHT: MAX_BERICHT,
  MAX_ACTIEF_PER_HELPER: MAX_ACTIEF_PER_HELPER,
  BESCHIKBAAR_MS: BESCHIKBAAR_MS,
  MELDING_SOORT: MELDING_SOORT,
  BASIS_URL: BASIS_URL,
  LINK_PAD: LINK_PAD,
  TOELICHTING_GEKOZEN: TOELICHTING_GEKOZEN,
  TOELICHTING_GEKOZEN_MELDKAMER: TOELICHTING_GEKOZEN_MELDKAMER,
  INSTELLING_ACCEPTEREN_DICHT: INSTELLING_ACCEPTEREN_DICHT,
  INSTELLING_ALLEEN_BESCHIKBAAR: INSTELLING_ALLEEN_BESCHIKBAAR,
  GEHEIME_VELDEN: GEHEIME_VELDEN,
  isoVan: isoVan,
  schoonBericht: schoonBericht,
  waarVoorOuder: waarVoorOuder,
  overlapt: overlapt,
  linkVoor: linkVoor,
  tokenHash: tokenHash,
  zoektOpGeheim: zoektOpGeheim,
  instellingAan: instellingAan,
  reageer: reageer,
  trekIn: trekIn,
  ouderStand: ouderStand,
  ouderBesluit: ouderBesluit,
  reactiesVoorBewoner: reactiesVoorBewoner,
  kies: kies,
  naKlusWissel: naKlusWissel,
  vervalVerlopen: vervalVerlopen,
  nakijkenMelding: nakijkenMelding,
  zetBeschikbaar: zetBeschikbaar,
  telBeschikbaar: telBeschikbaar,
  verwerkGeheim: verwerkGeheim,
  verrijkKlus: verrijkKlus,
  jsvmOmgeving: jsvmOmgeving,
};

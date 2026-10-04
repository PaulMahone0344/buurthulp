// HeitjeHulp B5 — hh_reacties_na.js (hulpbestand, GEEN hook)
//
// Wat er rond reageren en kiezen gebeurt BUITEN de routes van de helper en
// de bewoner: na elke statuswissel de reacties bijwerken (ook bij koppelen,
// accepteren, annuleren), wachtende reacties laten vervallen (cron), de
// M8-meldingen nakijken (match-tekst, "nieuwe klus" alleen aan wie nu kan),
// "Ik kan nu helpen", de geheime vraag na de klus en het verrijken van een
// klus met het aantal reacties. Gebruikt hh_reacties_basis.js; wordt via
// hh_reacties_hulp.js geexporteerd.

var HOOKS = typeof __hooks !== "undefined" ? __hooks : "";
var basis = require(HOOKS + "/hh_reacties_basis.js");
var COLLECTIE = basis.COLLECTIE;
var STATUS = basis.STATUS;
var BESCHIKBAAR_MS = basis.BESCHIKBAAR_MS;
var MAX_TELLEN = basis.MAX_TELLEN;
var INSTELLING_ALLEEN_BESCHIKBAAR = basis.INSTELLING_ALLEEN_BESCHIKBAAR;
var isoVan = basis.isoVan;
var msVan = basis.msVan;
var tekst = basis.tekst;
var voornaam = basis.voornaam;
var antwoord = basis.antwoord;
var ok = basis.ok;
var zoekId = basis.zoekId;
var zoekAlle = basis.zoekAlle;
var zoekEerste = basis.zoekEerste;
var instellingAan = basis.instellingAan;
var profielVan = basis.profielVan;
var wijkInfo = basis.wijkInfo;
var klusInfo = basis.klusInfo;
var helperBlokkade = basis.helperBlokkade;
var veiligMelden = basis.veiligMelden;

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

module.exports = {
  naKlusWissel: naKlusWissel,
  vervalVerlopen: vervalVerlopen,
  nakijkenMelding: nakijkenMelding,
  zetBeschikbaar: zetBeschikbaar,
  telBeschikbaar: telBeschikbaar,
  verwerkGeheim: verwerkGeheim,
  verrijkKlus: verrijkKlus,
};

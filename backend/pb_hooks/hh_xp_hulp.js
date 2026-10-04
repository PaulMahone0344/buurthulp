// HeitjeHulp B9 — hh_xp_hulp.js (hulpbestand, GEEN hook)
//
// Leest en schrijft voor B9. De rekenregels zelf staan in hh_xp_regels.js;
// dit bestand haalt de rijen op, boekt het verschil in hh_xp, zet XP-totaal
// en niveau op hh_profielen, bewaart nieuwe badges in hh_badges, maakt de
// beloningsmelding, het overzicht voor de app, de "Verklaring van inzet" en
// verbergt een recensie (meldkamer).
//
// env = { app, Record, nu: () => ms, willekeurig: (lengte) => tekst }
//   app         $app of een txApp (in tests de nep-app)
//   Record      de Record-constructor van de JSVM (in tests NepRecord)
//   willekeurig $security.randomStringWithAlphabet(lengte, CODE_TEKENS)
// Getest zonder server in backend/tests/hh_xp_hulp.test.mjs; de echte rules
// en PocketBase bewijst scripts/142-b9check.mjs.
//
// HOE XP GEBOEKT WORDT (herleidbaar, nooit wissen)
//   Elke bron ("klaar:<klus>", "herboeking:<klus>", "eerste",
//   "beoordeling:<id>") heeft een gewenst aantal punten (regels.gewensteXp).
//   werkXpBij telt wat er al per bron in hh_xp staat en boekt ALLEEN het
//   verschil: positief met de soort van de bron, negatief als
//   "tegenboeking". (helper, sleutel) met sleutel = bron + "#" + volgnummer
//   is uniek in de database: twee hooks tegelijk boeken dus nooit dubbel (de tweede krijgt
//   UNIQUE en slaat over; de volgende aanroep zet het recht). Zo kan
//   werkXpBij zo vaak draaien als je wilt (ook script 144: naberekenen).
//
// Gotchas (memory reference_pb_jsvm_hooks): $app en niet e.app, record.get()
// eerst naar String/Number, filters met {:naam}-parameters, limit 0 = alles.

var CODE_TEKENS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // geen 0/O, 1/I
var CODE_LENGTE = 10;
var RECENSIES_MAX = 20;
var BOEKINGEN_MAX = 10;
var VERKLARING_HERGEBRUIK_MS = 24 * 3600 * 1000;

// In de JSVM bestaat __hooks; in de tests zet de nep-lader require() om.
var HOOKS = typeof __hooks !== "undefined" ? __hooks : "";
var REGELS = require(HOOKS + "/hh_xp_regels.js");

function regels() {
  return REGELS;
}

function tekst(v) {
  return v === undefined || v === null ? "" : String(v).trim();
}

function zoekAlle(app, collectie, filter, params, sort, limit) {
  try {
    return app.findRecordsByFilter(collectie, filter, sort || "", limit || 0, 0, params || {});
  } catch (_) {
    return [];
  }
}

function zoekEerste(app, collectie, filter, params) {
  var lijst = zoekAlle(app, collectie, filter, params, "", 1);
  return lijst.length ? lijst[0] : null;
}

function zoekId(app, collectie, id) {
  if (!id) return null;
  try {
    return app.findRecordById(collectie, id);
  } catch (_) {
    return null;
  }
}

function voornaam(naam) {
  return tekst(naam).split(/\s+/)[0] || "";
}

function datumNu(env) {
  return new Date(env.nu()).toISOString().replace("T", " ");
}

// --------------------------------------------------------------------------
// Rijen ophalen als gewone objecten (voor hh_xp_regels.js)
// --------------------------------------------------------------------------

function klusObject(k) {
  return {
    id: k.id,
    hulpvrager: tekst(k.get("hulpvrager")),
    wanneer_van: tekst(k.get("wanneer_van")),
    wanneer_tot: tekst(k.get("wanneer_tot")),
    created: tekst(k.get("created")),
    updated: tekst(k.get("updated")),
    vergoeding_jongere: Number(k.get("vergoeding_jongere") || 0),
    bedrag_bruto: Number(k.get("bedrag_bruto") || 0),
  };
}

function afgerondeKlussen(app, helperId) {
  return zoekAlle(app, "hh_klussen", 'status = "afgerond" && toegewezen_jongere = {:h}', { h: helperId }).map(klusObject);
}

/// Beoordelingen NAAR de helper, alleen van klussen die nu afgerond zijn.
function beoordelingenVan(app, helperId, klusIds) {
  var mag = {};
  for (var i = 0; i < klusIds.length; i++) mag[klusIds[i]] = true;
  return zoekAlle(app, "hh_beoordelingen", "naar_gebruiker = {:h}", { h: helperId })
    .filter(function (b) {
      return mag[tekst(b.get("klus"))];
    })
    .map(function (b) {
      return {
        id: b.id,
        klus: tekst(b.get("klus")),
        sterren: Number(b.get("sterren") || 0),
        tekst: tekst(b.get("tekst")),
        van: tekst(b.get("van_gebruiker")),
        verborgen_op: tekst(b.get("verborgen_op")),
        created: tekst(b.get("created")),
      };
    });
}

function profielVan(app, helperId) {
  return zoekEerste(app, "hh_profielen", "gebruiker = {:h}", { h: helperId });
}

// --------------------------------------------------------------------------
// XP boeken
// --------------------------------------------------------------------------

/// Rekent de XP van [helperId] opnieuw uit, boekt het verschil, zet totaal +
/// niveau op het profiel en bewaart nieuwe badges. opties.droog = alleen
/// zeggen wat er zou gebeuren (script 144). Geeft null zonder helper, anders
///   { helper, totaal, niveau, vorig_niveau, xp_erbij, boekingen: [...],
///     nieuwe_badges: [code], eerste_boeking: id }
/// Gooit niet bij één mislukte boeking (UNIQUE = een andere hook was eerder).
function werkXpBij(env, helperId, opties) {
  var app = env.app;
  var r = regels();
  var droog = !!(opties && opties.droog);
  var helper = zoekId(app, "hh_users", tekst(helperId));
  if (!helper || tekst(helper.get("rol")) !== "jongere") return null;

  var klussen = afgerondeKlussen(app, helper.id);
  var beoordelingen = beoordelingenVan(app, helper.id, klussen.map(function (k) { return k.id; }));
  var gewenst = r.gewensteXp(klussen, beoordelingen);

  var rijen = zoekAlle(app, "hh_xp", "helper = {:h}", { h: helper.id });
  var huidig = {};
  var aantalPerBron = {};
  var totaal = 0;
  for (var i = 0; i < rijen.length; i++) {
    var bron = tekst(rijen[i].get("bron"));
    var punten = Number(rijen[i].get("punten") || 0);
    huidig[bron] = (huidig[bron] || 0) + punten;
    aantalPerBron[bron] = (aantalPerBron[bron] || 0) + 1;
    totaal += punten;
  }

  var boekingen = r.teBoeken(huidig, gewenst);
  var geboekt = [];
  var xpErbij = 0;
  var eersteBoeking = "";
  for (var j = 0; j < boekingen.length; j++) {
    var b = boekingen[j];
    var volgnummer = (aantalPerBron[b.bron] || 0) + 1;
    var sleutel = b.bron + "#" + volgnummer;
    if (!droog) {
      try {
        var rij = new env.Record(app.findCollectionByNameOrId("hh_xp"));
        rij.set("helper", helper.id);
        if (b.klus && zoekId(app, "hh_klussen", b.klus)) rij.set("klus", b.klus);
        if (b.beoordeling) rij.set("beoordeling", b.beoordeling);
        rij.set("bron", b.bron);
        rij.set("soort", b.soort);
        rij.set("punten", b.punten);
        rij.set("sleutel", sleutel);
        app.save(rij);
        if (!eersteBoeking) eersteBoeking = rij.id;
      } catch (err) {
        console.log("[hh_xp] boeking " + sleutel + " overgeslagen:", String(err));
        continue;
      }
    }
    aantalPerBron[b.bron] = volgnummer;
    totaal += b.punten;
    if (b.punten > 0) xpErbij += b.punten;
    geboekt.push({ bron: b.bron, soort: b.soort, punten: b.punten, sleutel: sleutel });
  }

  var profiel = profielVan(app, helper.id);
  var vorigNiveau = profiel ? tekst(profiel.get("niveau")) || "nieuw" : "nieuw";
  var niveau = r.niveauVoor({
    xp: totaal,
    klussen: klussen.length,
    sterren: Number((profiel ? profiel.get("sterren_gemiddeld") : helper.get("sterren_gemiddeld")) || 0),
    idin: profiel ? tekst(profiel.get("idin_geverifieerd_op")) : "",
  });
  if (profiel && !droog) {
    if (Number(profiel.get("xp_totaal") || 0) !== totaal || tekst(profiel.get("niveau")) !== niveau) {
      profiel.set("xp_totaal", totaal);
      profiel.set("niveau", niveau);
      app.save(profiel);
    }
  }

  var nieuweBadges = bewaarBadges(env, helper.id, r.badgesVoor(klussen, beoordelingen), droog);

  return {
    helper: helper.id,
    totaal: totaal,
    niveau: niveau,
    vorig_niveau: vorigNiveau,
    xp_erbij: xpErbij,
    boekingen: geboekt,
    nieuwe_badges: nieuweBadges,
    eerste_boeking: eersteBoeking,
  };
}

/// Bewaart badges die er nog niet zijn (nooit weghalen: behaald is behaald).
/// (helper, code) is uniek in de database.
/// Geeft de codes van de nieuwe terug.
function bewaarBadges(env, helperId, verdiend, droog) {
  var app = env.app;
  var heeft = {};
  var rijen = zoekAlle(app, "hh_badges", "helper = {:h}", { h: helperId });
  for (var i = 0; i < rijen.length; i++) heeft[tekst(rijen[i].get("code"))] = true;
  var nieuw = [];
  for (var j = 0; j < verdiend.length; j++) {
    var b = verdiend[j];
    if (heeft[b.code]) continue;
    if (!droog) {
      try {
        var rij = new env.Record(app.findCollectionByNameOrId("hh_badges"));
        rij.set("helper", helperId);
        rij.set("code", b.code);
        rij.set("behaald_op", b.behaald_op || datumNu(env));
        app.save(rij);
      } catch (err) {
        console.log("[hh_xp] badge " + b.code + " overgeslagen:", String(err));
        continue;
      }
    }
    nieuw.push(b.code);
  }
  return nieuw;
}

/// Wat de app na "Klaar" laat zien (HBeloning), uit de uitkomst van werkXpBij.
function beloning(uitkomst) {
  var r = regels();
  if (!uitkomst) return null;
  var omhoog = r.NIVEAUS.map(function (n) { return n.code; });
  return {
    xp_erbij: uitkomst.xp_erbij,
    totaal: uitkomst.totaal,
    niveau: { code: uitkomst.niveau, naam: r.niveauNaam(uitkomst.niveau) },
    niveau_omhoog: omhoog.indexOf(uitkomst.niveau) > omhoog.indexOf(uitkomst.vorig_niveau),
    nieuwe_badges: uitkomst.nieuwe_badges.map(function (code) {
      var info = r.badgeInfo(code) || { naam: code, uitleg: "", icoon: "" };
      return { code: code, naam: info.naam, uitleg: info.uitleg, icoon: info.icoon };
    }),
  };
}

/// Eén gebundelde melding "+N XP" / "Nieuwe badge" / "Je bent nu Ervaren".
/// Niets erbij = geen melding. Geeft true als er een melding is gemaakt.
function beloningMelden(env, uitkomst, klusId) {
  var b = beloning(uitkomst);
  if (!b) return false;
  if (b.xp_erbij <= 0 && !b.nieuwe_badges.length && !b.niveau_omhoog) return false;
  var delen = [];
  if (b.xp_erbij > 0) delen.push("+" + b.xp_erbij + " XP");
  for (var i = 0; i < b.nieuwe_badges.length; i++) delen.push("Nieuwe badge: " + b.nieuwe_badges[i].naam);
  if (b.niveau_omhoog) delen.push("Je bent nu " + b.niveau.naam + "!");
  var titel = b.niveau_omhoog ? "Nieuw niveau: " + b.niveau.naam : b.nieuwe_badges.length ? "Nieuwe badge!" : "Goed gedaan!";
  var sleutel = "xp:" + (uitkomst.eerste_boeking || uitkomst.helper + ":" + uitkomst.nieuwe_badges.join(","));
  try {
    var app = env.app;
    if (zoekEerste(app, "hh_meldingen", "ontvanger = {:o} && soort = \"beloning\" && sleutel = {:s}", { o: uitkomst.helper, s: sleutel })) return false;
    var m = new env.Record(app.findCollectionByNameOrId("hh_meldingen"));
    m.set("ontvanger", uitkomst.helper);
    m.set("soort", "beloning");
    if (klusId && zoekId(app, "hh_klussen", klusId)) m.set("klus", klusId);
    m.set("titel", titel);
    m.set("tekst", delen.join(" · "));
    m.set("sleutel", sleutel);
    app.save(m);
    return true;
  } catch (err) {
    console.log("[hh_xp] beloningsmelding mislukt:", String(err));
    return false;
  }
}

// --------------------------------------------------------------------------
// Overzicht voor de app (GET /api/hh/xp/mijn)
// --------------------------------------------------------------------------

function recensiesVan(app, helperId, beoordelingen) {
  return beoordelingen
    .filter(function (b) {
      return !b.verborgen_op && b.tekst && b.sterren > 0;
    })
    .sort(function (a, b) {
      return a.created < b.created ? 1 : a.created > b.created ? -1 : 0;
    })
    .slice(0, RECENSIES_MAX)
    .map(function (b) {
      var van = zoekId(app, "hh_users", b.van);
      return { sterren: b.sterren, tekst: b.tekst, datum: b.created, voornaam: van ? voornaam(van.get("naam")) : "" };
    });
}

/// Alles voor HProfiel, Start-blok en "Mijn verdiensten". Leest alleen.
function overzicht(env, helperId) {
  var app = env.app;
  var r = regels();
  var helper = zoekId(app, "hh_users", tekst(helperId));
  if (!helper) return null;
  var profiel = profielVan(app, helper.id);
  var klussen = afgerondeKlussen(app, helper.id);
  var beoordelingen = beoordelingenVan(app, helper.id, klussen.map(function (k) { return k.id; }));
  var totaal = profiel ? Number(profiel.get("xp_totaal") || 0) : 0;
  var sterren = Number((profiel ? profiel.get("sterren_gemiddeld") : helper.get("sterren_gemiddeld")) || 0);
  var idin = profiel ? tekst(profiel.get("idin_geverifieerd_op")) : "";
  var stand = { xp: totaal, klussen: klussen.length, sterren: sterren, idin: idin };
  var niveau = (profiel && tekst(profiel.get("niveau"))) || r.niveauVoor(stand);

  var behaald = {};
  var rijen = zoekAlle(app, "hh_badges", "helper = {:h}", { h: helper.id });
  for (var i = 0; i < rijen.length; i++) behaald[tekst(rijen[i].get("code"))] = tekst(rijen[i].get("behaald_op"));

  var boekingen = zoekAlle(app, "hh_xp", "helper = {:h}", { h: helper.id }, "-created", BOEKINGEN_MAX).map(function (x) {
    return { soort: tekst(x.get("soort")), punten: Number(x.get("punten") || 0), datum: tekst(x.get("created")) };
  });

  return {
    xp_totaal: totaal,
    niveau: { code: niveau, naam: r.niveauNaam(niveau) },
    volgend: r.volgendNiveau(stand),
    klussen_aantal: klussen.length,
    sterren: sterren,
    beoordelingen_aantal: beoordelingen.filter(function (b) { return !b.verborgen_op && b.sterren > 0; }).length,
    badges: r.BADGES.map(function (b) {
      return { code: b.code, naam: b.naam, uitleg: b.uitleg, icoon: b.icoon, behaald_op: behaald[b.code] || "" };
    }),
    vertrouwen: r.vertrouwensBadges(
      { ouder_toestemming_op: tekst(helper.get("ouder_toestemming_op")) },
      profiel
        ? {
            vog_gezien_op: tekst(profiel.get("vog_gezien_op")),
            vog_geldig_tot: tekst(profiel.get("vog_geldig_tot")),
            id_gecontroleerd_op: tekst(profiel.get("id_gecontroleerd_op")),
            idin_geverifieerd_op: idin,
          }
        : {},
      env.nu()
    ),
    verdiensten: r.verdiensten(klussen),
    recensies: recensiesVan(app, helper.id, beoordelingen),
    boekingen: boekingen,
  };
}

/// Wat KiesHelper (B5) van B9 nodig heeft: echt niveau, "Nieuw in de buurt"
/// (0 afgeronde klussen) en de recensie-telling zonder verborgen.
function kaartInfo(env, helperId) {
  var app = env.app;
  var r = regels();
  var profiel = profielVan(app, helperId);
  var code = (profiel && tekst(profiel.get("niveau"))) || "nieuw";
  // Eén afgeronde klus is genoeg om niet meer "nieuw in de buurt" te zijn.
  // (Geen countRecords: dat neemt in de JSVM dbx-expressies, geen filter.)
  var een = zoekAlle(app, "hh_klussen", 'status = "afgerond" && toegewezen_jongere = {:h}', { h: helperId }, "", 1);
  return { niveau: r.niveauNaam(code), niveau_code: code, nieuw_in_de_buurt: een.length === 0 };
}

// --------------------------------------------------------------------------
// Verklaring van inzet (punt 19)
// --------------------------------------------------------------------------

/// JSON met gesorteerde sleutels: PocketBase (Go) bewaart een json-veld met
/// de sleutels op alfabet, dus een gewone JSON.stringify vergelijkt verkeerd.
function stabiel(waarde) {
  if (Array.isArray(waarde)) return "[" + waarde.map(stabiel).join(",") + "]";
  if (waarde && typeof waarde === "object") {
    return "{" + Object.keys(waarde).sort().map(function (k) { return JSON.stringify(k) + ":" + stabiel(waarde[k]); }).join(",") + "}";
  }
  return JSON.stringify(waarde === undefined ? null : waarde);
}

/// Een json-veld als object (JSVM: via getString; nep-app: al een object).
function leesJson(record, veld) {
  var w = record.get(veld);
  if (w && typeof w === "object" && !Array.isArray(w) && typeof w.length !== "number") {
    try {
      return JSON.parse(JSON.stringify(w));
    } catch (_) {
      // val terug op getString
    }
  }
  try {
    return JSON.parse(record.getString(veld));
  } catch (_) {
    return typeof w === "string" ? (function () { try { return JSON.parse(w); } catch (e) { return {}; } })() : {};
  }
}

function codeOpmaak(ruw) {
  var t = tekst(ruw).toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (t.length !== CODE_LENGTE) return "";
  return t.slice(0, 5) + "-" + t.slice(5);
}

/// Wat er op de verklaring staat (snapshot, zodat de code later precies
/// laat zien wat er toen is uitgegeven).
function verklaringGegevens(env, helper, data) {
  var r = regels();
  var momenten = [];
  var uren = 0;
  var klussen = afgerondeKlussen(env.app, helper.id);
  for (var i = 0; i < klussen.length; i++) {
    var m = Date.parse((klussen[i].wanneer_van || klussen[i].updated).replace(" ", "T"));
    if (!isNaN(m)) momenten.push(m);
    uren += r.klusUren(klussen[i]);
  }
  momenten.sort();
  var dag = function (m) {
    return m ? new Date(m).toISOString().slice(0, 10) : "";
  };
  return {
    voornaam: voornaam(helper.get("naam")),
    klussen: data.klussen_aantal,
    uren: Math.round(uren * 4) / 4,
    periode_van: dag(momenten[0]),
    periode_tot: dag(momenten[momenten.length - 1]),
    niveau: data.niveau.naam,
    sterren: data.sterren,
    badges: data.badges
      .filter(function (b) { return b.behaald_op; })
      .map(function (b) { return { naam: b.naam, datum: b.behaald_op.slice(0, 10) }; }),
    vertrouwen: data.vertrouwen
      .filter(function (v) { return !v.verlopen; })
      .map(function (v) { return { naam: v.naam, datum: v.datum.slice(0, 10) }; }),
  };
}

/// Maakt een verklaring (of geeft de laatste terug als die minder dan een
/// dag oud is en er sindsdien niets veranderde). Geeft
///   { code, uitgegeven_op, gegevens } of null zonder helper.
function verklaringMaken(env, helperId) {
  var app = env.app;
  var helper = zoekId(app, "hh_users", tekst(helperId));
  if (!helper || tekst(helper.get("rol")) !== "jongere") return null;
  var data = overzicht(env, helper.id);
  var gegevens = verklaringGegevens(env, helper, data);

  var laatste = zoekAlle(app, "hh_verklaringen", "helper = {:h}", { h: helper.id }, "-created", 1)[0];
  if (laatste) {
    var oud = Date.parse(tekst(laatste.get("created")).replace(" ", "T"));
    var zelfde = stabiel(leesJson(laatste, "gegevens")) === stabiel(gegevens);
    if (!isNaN(oud) && env.nu() - oud < VERKLARING_HERGEBRUIK_MS && zelfde) {
      return { code: tekst(laatste.get("code")), uitgegeven_op: tekst(laatste.get("created")), gegevens: gegevens };
    }
  }

  for (var poging = 0; poging < 5; poging++) {
    var code = codeOpmaak(env.willekeurig(CODE_LENGTE));
    if (!code) continue;
    try {
      var rij = new env.Record(app.findCollectionByNameOrId("hh_verklaringen"));
      rij.set("helper", helper.id);
      rij.set("code", code);
      rij.set("gegevens", gegevens);
      app.save(rij);
      return { code: code, uitgegeven_op: tekst(rij.get("created")) || datumNu(env), gegevens: gegevens };
    } catch (err) {
      console.log("[hh_xp] verklaring-code bezet, opnieuw:", String(err));
    }
  }
  throw new Error("geen vrije verklaring-code");
}

/// Opzoeken met de controlecode (publiek: wie de code heeft, mag de
/// verklaring zien; er staat alleen de voornaam op). null = onbekend.
function verklaringOpzoeken(env, ruweCode) {
  var code = codeOpmaak(ruweCode);
  if (!code) return null;
  var rij = zoekEerste(env.app, "hh_verklaringen", "code = {:c}", { c: code });
  if (!rij) return null;
  return { code: code, uitgegeven_op: tekst(rij.get("created")), gegevens: leesJson(rij, "gegevens") };
}

// --------------------------------------------------------------------------
// Recensie verbergen (meldkamer)
// --------------------------------------------------------------------------

/// kijker = { id, rol }. Geeft { status, body } voor de route. Verbergen
/// haalt de beoordeling uit sterren, XP, badges-reeks en recensies; de rij
/// blijft bestaan (terugzetten kan). De aanroeper rekent daarna reputatie +
/// XP opnieuw uit (zie hh_xp.pb.js), omdat die een eigen require nodig heeft.
function recensieVerbergen(env, kijker, beoordelingId, verbergen, reden) {
  var app = env.app;
  if (!kijker || kijker.rol !== "coordinator") {
    return { status: 403, body: { melding: "Alleen de meldkamer kan een recensie verbergen.", reden: "geenmeldkamer" } };
  }
  var b = zoekId(app, "hh_beoordelingen", tekst(beoordelingId));
  if (!b) return { status: 404, body: { melding: "Deze beoordeling bestaat niet meer.", reden: "nietgevonden" } };
  if (verbergen) {
    b.set("verborgen_op", datumNu(env));
    b.set("verborgen_door", kijker.id);
    b.set("verborgen_reden", tekst(reden).slice(0, 300));
  } else {
    b.set("verborgen_op", "");
    b.set("verborgen_door", "");
    b.set("verborgen_reden", "");
  }
  app.save(b);
  return {
    status: 200,
    body: { beoordeling: b.id, verborgen: !!verbergen, naar_gebruiker: tekst(b.get("naar_gebruiker")) },
  };
}

// --------------------------------------------------------------------------
// Naberekenen (script 144): alle helpers met een afgeronde klus of XP
// --------------------------------------------------------------------------

function naberekenen(env, opties) {
  var app = env.app;
  var ids = {};
  var klussen = zoekAlle(app, "hh_klussen", 'status = "afgerond" && toegewezen_jongere != ""', {});
  for (var i = 0; i < klussen.length; i++) ids[tekst(klussen[i].get("toegewezen_jongere"))] = true;
  var xp = zoekAlle(app, "hh_xp", "", {});
  for (var j = 0; j < xp.length; j++) ids[tekst(xp[j].get("helper"))] = true;
  var uit = [];
  var namen = Object.keys(ids).sort();
  for (var k = 0; k < namen.length; k++) {
    var u = werkXpBij(env, namen[k], opties);
    if (u && (u.boekingen.length || u.nieuwe_badges.length || u.niveau !== u.vorig_niveau)) {
      uit.push({ helper: u.helper, totaal: u.totaal, niveau: u.niveau, boekingen: u.boekingen, nieuwe_badges: u.nieuwe_badges });
    }
  }
  return uit;
}

module.exports = {
  CODE_TEKENS: CODE_TEKENS,
  CODE_LENGTE: CODE_LENGTE,
  werkXpBij: werkXpBij,
  beloning: beloning,
  beloningMelden: beloningMelden,
  overzicht: overzicht,
  kaartInfo: kaartInfo,
  codeOpmaak: codeOpmaak,
  verklaringMaken: verklaringMaken,
  verklaringOpzoeken: verklaringOpzoeken,
  recensieVerbergen: recensieVerbergen,
  naberekenen: naberekenen,
};

// HeitjeHulp B9 — hh_xp_regels.js (hulpbestand, GEEN hook)
//
// De rekenregels van B9 op één plek, ZONDER database: XP per bron, niveaus,
// badges, vertrouwensbadges met datum en verdiensten per maand/jaar. Alles
// krijgt gewone objecten binnen (klussen, beoordelingen, profiel) en geeft
// gewone objecten terug, zodat backend/tests/hh_xp_regels.test.mjs het zonder
// server toetst. hh_xp_hulp.js haalt de rijen op en schrijft het resultaat.
//
// DE GETALLEN STAAN BOVENAAN (XP, NIVEAUS, BADGES, VOG_JAREN): wil Ibrahim
// iets anders, dan verandert alleen dit bestand (+ de test die het getal
// noemt). De app rekent hier NOOIT zelf iets van na; hij toont wat de server
// geeft (route GET /api/hh/xp/mijn).
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. Elke
// handler haalt dit bestand BINNEN de handler op met
//   var regels = require(`${__hooks}/hh_xp_regels.js`);
// (de pool-runtime deelt geen scope tussen handlers).

// --------------------------------------------------------------------------
// XP per bron (punt 18: herboeking = de meeste XP). Een afgeronde klus bij
// een bewoner die je al eerder hielp levert klaar + herboeking = 125.
// --------------------------------------------------------------------------
var XP = {
  klus_klaar: 50, // elke afgeronde klus
  eerste_klus: 25, // eenmalig, bij je allereerste afgeronde klus
  herboeking: 75, // dezelfde bewoner koos je opnieuw (2e, 3e, ... klus bij hem)
  beoordeling: { 5: 30, 4: 15 }, // sterren van de bewoner; 1-3 sterren: 0
};

// Niveaus van laag naar hoog. Een niveau haal je als ALLE drempels kloppen.
// "geverifieerd" komt alleen met iDIN (idin_geverifieerd_op) bovenop Top en
// wordt NOOIT automatisch toegekend: iDIN bestaat nog niet (B9-prompt).
var NIVEAUS = [
  { code: "nieuw", naam: "Nieuw", min_xp: 0, min_klussen: 0, min_sterren: 0 },
  { code: "ervaren", naam: "Ervaren", min_xp: 300, min_klussen: 5, min_sterren: 0 },
  { code: "top", naam: "Top", min_xp: 1000, min_klussen: 15, min_sterren: 4.5 },
  { code: "geverifieerd", naam: "Geverifieerd", min_xp: 1000, min_klussen: 15, min_sterren: 4.5, idin: true },
];

// Prestatie-badges (GEEN "Held van de week"). icoon = naam van een Material-
// icoon in de app; alleen voorwerpen en vormen, geen mensen of dieren.
var BADGES = [
  { code: "eerste_klus", naam: "Eerste klus", uitleg: "Je eerste klus is klaar.", icoon: "flag" },
  { code: "vijf_klussen", naam: "5 klussen", uitleg: "Vijf klussen gedaan.", icoon: "handyman" },
  { code: "tien_klussen", naam: "10 klussen", uitleg: "Tien klussen gedaan.", icoon: "construction" },
  { code: "vijfentwintig_klussen", naam: "25 klussen", uitleg: "Vijfentwintig klussen gedaan.", icoon: "workspace_premium" },
  { code: "vijf_sterren_reeks", naam: "5 keer 5 sterren", uitleg: "Vijf keer achter elkaar 5 sterren.", icoon: "star" },
  { code: "herboekt", naam: "Weer gevraagd", uitleg: "Een bewoner koos je nog een keer.", icoon: "repeat" },
  { code: "drie_buren", naam: "3 buren geholpen", uitleg: "Je hielp drie verschillende bewoners.", icoon: "home" },
];

var KLUSSEN_DREMPELS = { vijf_klussen: 5, tien_klussen: 10, vijfentwintig_klussen: 25 };
var REEKS_LENGTE = 5;
var BUREN_AANTAL = 3;

// Vertrouwensbadges (punt 19): komen uit wat de meldkamer en de ouder al
// vastlegden, met datum. Een VOG zonder vog_geldig_tot verloopt VOG_JAREN
// na vog_gezien_op (OPEN-PUNTEN-B9 vraag 3).
var VOG_JAREN = 3;
var VERTROUWEN = [
  { code: "ouder_toestemming", naam: "Toestemming ouder", icoon: "verified_user" },
  { code: "vog", naam: "VOG gezien", icoon: "shield" },
  { code: "id_gecontroleerd", naam: "ID gecontroleerd", icoon: "badge" },
  { code: "idin", naam: "iDIN", icoon: "lock" },
];

// --------------------------------------------------------------------------
// Kleine hulpjes
// --------------------------------------------------------------------------

function tekst(v) {
  return v === undefined || v === null ? "" : String(v).trim();
}

/// PocketBase "2026-10-10 08:00:00.000Z" -> ms, of NaN.
function ms(waarde) {
  var t = tekst(waarde);
  if (!t) return NaN;
  return Date.parse(t.replace(" ", "T"));
}

/// Het moment waarop een klus telt: begin, anders laatst bijgewerkt.
function klusMoment(klus) {
  var m = ms(klus.wanneer_van);
  if (isNaN(m)) m = ms(klus.updated);
  if (isNaN(m)) m = ms(klus.created);
  return isNaN(m) ? 0 : m;
}

function opMoment(a, b) {
  var x = klusMoment(a);
  var y = klusMoment(b);
  if (x !== y) return x - y;
  return tekst(a.id) < tekst(b.id) ? -1 : tekst(a.id) > tekst(b.id) ? 1 : 0;
}

function datumVan(m) {
  return m ? new Date(m).toISOString().replace("T", " ") : "";
}

/// Telt een beoordeling mee? Verborgen (meldkamer) of zonder sterren: nee.
function telt(beoordeling) {
  return !tekst(beoordeling.verborgen_op) && Number(beoordeling.sterren || 0) > 0;
}

// --------------------------------------------------------------------------
// XP
// --------------------------------------------------------------------------

/// Hoeveel XP elke BRON hoort op te leveren, voor één helper.
///   klussen       = zijn afgeronde klussen {id, hulpvrager, wanneer_van, ...}
///   beoordelingen = beoordelingen NAAR hem {id, klus, sterren, verborgen_op}
///                   (alleen van klussen die nog afgerond zijn)
/// Geeft { "<bron>": {soort, punten, klus?, beoordeling?} } terug. Een bron
/// die niet (meer) in de lijst staat hoort 0 op te leveren; hh_xp_hulp.js
/// boekt het verschil (ook terug) en wist nooit iets.
function gewensteXp(klussen, beoordelingen) {
  var uit = {};
  var gesorteerd = (klussen || []).slice().sort(opMoment);
  var eerderBij = {};
  for (var i = 0; i < gesorteerd.length; i++) {
    var k = gesorteerd[i];
    uit["klaar:" + k.id] = { soort: "klus_klaar", punten: XP.klus_klaar, klus: k.id };
    var bewoner = tekst(k.hulpvrager);
    if (bewoner && eerderBij[bewoner]) {
      uit["herboeking:" + k.id] = { soort: "herboeking", punten: XP.herboeking, klus: k.id };
    }
    if (bewoner) eerderBij[bewoner] = true;
  }
  if (gesorteerd.length) {
    uit.eerste = { soort: "eerste_klus", punten: XP.eerste_klus, klus: gesorteerd[0].id };
  }
  var lijst = beoordelingen || [];
  for (var j = 0; j < lijst.length; j++) {
    var b = lijst[j];
    var punten = telt(b) ? XP.beoordeling[Number(b.sterren)] || 0 : 0;
    if (punten) {
      uit["beoordeling:" + b.id] = { soort: "beoordeling", punten: punten, klus: tekst(b.klus), beoordeling: b.id };
    }
  }
  return uit;
}

/// Wat er geboekt moet worden om van [huidig] ({bron: som}) naar [gewenst]
/// (uitkomst van gewensteXp) te gaan. Een positief verschil krijgt de soort
/// van de bron, een negatief "tegenboeking". Geeft een lijst boekingen.
function teBoeken(huidig, gewenst) {
  var bronnen = {};
  var k;
  for (k in huidig) bronnen[k] = true;
  for (k in gewenst) bronnen[k] = true;
  var uit = [];
  var namen = Object.keys(bronnen).sort();
  for (var i = 0; i < namen.length; i++) {
    var bron = namen[i];
    var wil = gewenst[bron] ? gewenst[bron].punten : 0;
    var heeft = Number(huidig[bron] || 0);
    var verschil = wil - heeft;
    if (!verschil) continue;
    var g = gewenst[bron] || {};
    uit.push({
      bron: bron,
      soort: verschil > 0 ? g.soort : "tegenboeking",
      punten: verschil,
      klus: g.klus || "",
      beoordeling: g.beoordeling || "",
    });
  }
  return uit;
}

// --------------------------------------------------------------------------
// Niveaus
// --------------------------------------------------------------------------

function haalt(niveau, stand) {
  if (Number(stand.xp || 0) < niveau.min_xp) return false;
  if (Number(stand.klussen || 0) < niveau.min_klussen) return false;
  if (niveau.min_sterren && Number(stand.sterren || 0) < niveau.min_sterren) return false;
  if (niveau.idin && !tekst(stand.idin)) return false;
  return true;
}

/// stand = { xp, klussen, sterren, idin } -> niveau-code.
function niveauVoor(stand) {
  var code = NIVEAUS[0].code;
  for (var i = 0; i < NIVEAUS.length; i++) {
    if (haalt(NIVEAUS[i], stand)) code = NIVEAUS[i].code;
  }
  return code;
}

function niveauNaam(code) {
  for (var i = 0; i < NIVEAUS.length; i++) if (NIVEAUS[i].code === code) return NIVEAUS[i].naam;
  return NIVEAUS[0].naam;
}

/// Wat er nog nodig is voor het volgende niveau (zonder iDIN: dat kun je
/// niet verdienen). Geeft null op Top/Geverifieerd.
///   { code, naam, xp_nodig, klussen_nodig, sterren_nodig, xp_vanaf, xp_tot }
/// xp_vanaf/xp_tot zijn de grenzen voor de XP-balk in de app.
function volgendNiveau(stand) {
  var nu = niveauVoor(stand);
  var index = 0;
  for (var i = 0; i < NIVEAUS.length; i++) if (NIVEAUS[i].code === nu) index = i;
  var volgende = NIVEAUS[index + 1];
  if (!volgende || volgende.idin) return null;
  var xp = Number(stand.xp || 0);
  var klussen = Number(stand.klussen || 0);
  var sterren = Number(stand.sterren || 0);
  return {
    code: volgende.code,
    naam: volgende.naam,
    xp_nodig: Math.max(0, volgende.min_xp - xp),
    klussen_nodig: Math.max(0, volgende.min_klussen - klussen),
    sterren_nodig: volgende.min_sterren && sterren < volgende.min_sterren ? volgende.min_sterren : 0,
    xp_vanaf: NIVEAUS[index].min_xp,
    xp_tot: volgende.min_xp,
  };
}

// --------------------------------------------------------------------------
// Badges
// --------------------------------------------------------------------------

/// Welke prestatie-badges horen erbij en sinds wanneer.
///   klussen       = afgeronde klussen van de helper
///   beoordelingen = beoordelingen naar hem
/// -> [{ code, behaald_op }] in de volgorde van BADGES.
function badgesVoor(klussen, beoordelingen) {
  var gesorteerd = (klussen || []).slice().sort(opMoment);
  var behaald = {};
  var bewoners = {};
  var aantalBewoners = 0;
  for (var i = 0; i < gesorteerd.length; i++) {
    var k = gesorteerd[i];
    var moment = datumVan(klusMoment(k));
    var n = i + 1;
    if (n === 1) behaald.eerste_klus = moment;
    for (var code in KLUSSEN_DREMPELS) {
      if (n === KLUSSEN_DREMPELS[code]) behaald[code] = moment;
    }
    var bewoner = tekst(k.hulpvrager);
    if (bewoner) {
      if (bewoners[bewoner] && !behaald.herboekt) behaald.herboekt = moment;
      if (!bewoners[bewoner]) {
        bewoners[bewoner] = true;
        aantalBewoners++;
        if (aantalBewoners === BUREN_AANTAL) behaald.drie_buren = moment;
      }
    }
  }
  var lijst = (beoordelingen || []).filter(telt).sort(function (a, b) {
    var x = tekst(a.created);
    var y = tekst(b.created);
    return x < y ? -1 : x > y ? 1 : 0;
  });
  var reeks = 0;
  for (var j = 0; j < lijst.length && !behaald.vijf_sterren_reeks; j++) {
    reeks = Number(lijst[j].sterren) === 5 ? reeks + 1 : 0;
    if (reeks === REEKS_LENGTE) behaald.vijf_sterren_reeks = tekst(lijst[j].created);
  }
  var uit = [];
  for (var b = 0; b < BADGES.length; b++) {
    if (behaald[BADGES[b].code] !== undefined) uit.push({ code: BADGES[b].code, behaald_op: behaald[BADGES[b].code] });
  }
  return uit;
}

function badgeInfo(code) {
  for (var i = 0; i < BADGES.length; i++) if (BADGES[i].code === code) return BADGES[i];
  return null;
}

/// De vertrouwensbadges met datum. [nu] in ms.
///   gebruiker = { ouder_toestemming_op }   (hh_users)
///   profiel   = { vog_gezien_op, vog_geldig_tot, id_gecontroleerd_op,
///                 idin_geverifieerd_op }   (hh_profielen)
/// -> [{ code, naam, icoon, datum, geldig_tot, verlopen }] alleen wat er is.
function vertrouwensBadges(gebruiker, profiel, nu) {
  var g = gebruiker || {};
  var p = profiel || {};
  var uit = [];
  var voeg = function (code, datum, geldigTot) {
    var info = null;
    for (var i = 0; i < VERTROUWEN.length; i++) if (VERTROUWEN[i].code === code) info = VERTROUWEN[i];
    var tot = geldigTot || "";
    uit.push({
      code: code,
      naam: info.naam,
      icoon: info.icoon,
      datum: datum,
      geldig_tot: tot,
      verlopen: !!tot && ms(tot) < nu,
    });
  };
  if (tekst(g.ouder_toestemming_op)) voeg("ouder_toestemming", tekst(g.ouder_toestemming_op), "");
  if (tekst(p.vog_gezien_op)) {
    var tot = tekst(p.vog_geldig_tot);
    if (!tot) {
      var d = new Date(ms(p.vog_gezien_op));
      d.setUTCFullYear(d.getUTCFullYear() + VOG_JAREN);
      tot = datumVan(d.getTime());
    }
    voeg("vog", tekst(p.vog_gezien_op), tot);
  }
  if (tekst(p.id_gecontroleerd_op)) voeg("id_gecontroleerd", tekst(p.id_gecontroleerd_op), "");
  if (tekst(p.idin_geverifieerd_op)) voeg("idin", tekst(p.idin_geverifieerd_op), "");
  return uit;
}

// --------------------------------------------------------------------------
// Verdiensten (verwacht: echt geld komt met B7/B8)
// --------------------------------------------------------------------------

/// Laatste zondag van [maand] (0-11) om 01:00 UTC (EU-zomertijdwissel).
function laatsteZondag(jaar, maand) {
  var laatste = new Date(Date.UTC(jaar, maand + 1, 0));
  return Date.UTC(jaar, maand, laatste.getUTCDate() - laatste.getUTCDay(), 1, 0, 0);
}

/// "2026-10" in Nederlandse tijd (de server draait op UTC).
function nlMaand(m) {
  var jaar = new Date(m).getUTCFullYear();
  var zomer = m >= laatsteZondag(jaar, 2) && m < laatsteZondag(jaar, 9);
  var lokaal = new Date(m + (zomer ? 2 : 1) * 3600 * 1000);
  var mm = lokaal.getUTCMonth() + 1;
  return lokaal.getUTCFullYear() + "-" + (mm < 10 ? "0" : "") + mm;
}

/// Bedrag van één klus voor de helper: vergoeding_jongere, anders
/// bedrag_bruto (pilot: gelijk, commissie 0), anders 0. Op centen.
function klusBedrag(klus) {
  var v = Number(klus.vergoeding_jongere || 0);
  if (!v) v = Number(klus.bedrag_bruto || 0);
  return Math.round(v * 100) / 100;
}

/// Uren van een klus (alleen als begin én eind bekend zijn), op 0,25 uur.
function klusUren(klus) {
  var van = ms(klus.wanneer_van);
  var tot = ms(klus.wanneer_tot);
  if (isNaN(van) || isNaN(tot) || tot <= van) return 0;
  return Math.round(((tot - van) / 3600000) * 4) / 4;
}

/// -> { maanden: [{maand:"2026-10", bedrag, klussen}], jaren: [{jaar:"2026",
///      bedrag, klussen}], totaal } nieuwste eerst; alleen afgeronde klussen.
function verdiensten(klussen) {
  var perMaand = {};
  var perJaar = {};
  var totaal = 0;
  var lijst = klussen || [];
  for (var i = 0; i < lijst.length; i++) {
    var m = klusMoment(lijst[i]);
    if (!m) continue;
    var maand = nlMaand(m);
    var jaar = maand.slice(0, 4);
    var bedrag = klusBedrag(lijst[i]);
    perMaand[maand] = perMaand[maand] || { maand: maand, bedrag: 0, klussen: 0 };
    perJaar[jaar] = perJaar[jaar] || { jaar: jaar, bedrag: 0, klussen: 0 };
    perMaand[maand].bedrag = Math.round((perMaand[maand].bedrag + bedrag) * 100) / 100;
    perMaand[maand].klussen++;
    perJaar[jaar].bedrag = Math.round((perJaar[jaar].bedrag + bedrag) * 100) / 100;
    perJaar[jaar].klussen++;
    totaal = Math.round((totaal + bedrag) * 100) / 100;
  }
  var nieuwsteEerst = function (veld) {
    return function (a, b) {
      return a[veld] < b[veld] ? 1 : a[veld] > b[veld] ? -1 : 0;
    };
  };
  return {
    maanden: Object.keys(perMaand).map(function (k) { return perMaand[k]; }).sort(nieuwsteEerst("maand")),
    jaren: Object.keys(perJaar).map(function (k) { return perJaar[k]; }).sort(nieuwsteEerst("jaar")),
    totaal: totaal,
  };
}

module.exports = {
  XP: XP,
  NIVEAUS: NIVEAUS,
  BADGES: BADGES,
  VERTROUWEN: VERTROUWEN,
  VOG_JAREN: VOG_JAREN,
  gewensteXp: gewensteXp,
  teBoeken: teBoeken,
  niveauVoor: niveauVoor,
  niveauNaam: niveauNaam,
  volgendNiveau: volgendNiveau,
  badgesVoor: badgesVoor,
  badgeInfo: badgeInfo,
  vertrouwensBadges: vertrouwensBadges,
  nlMaand: nlMaand,
  klusBedrag: klusBedrag,
  klusUren: klusUren,
  verdiensten: verdiensten,
};

// HeitjeHulp B4 — hh_klusplaatsen_hulp.js (hulpbestand, GEEN hook)
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. De
// handlers in hh_klusplaatsen.pb.js en hh_klussen.pb.js halen dit bestand
// BINNEN de handler op met require(`${__hooks}/hh_klusplaatsen_hulp.js`).
// Puur rekenwerk (geen $app), zodat backend/tests/hh_klusplaatsen_hulp.test.mjs
// het zonder server kan testen. Datums komen binnen als PocketBase-tekst
// ("2026-10-05 12:00:00.000Z") of ISO ("2026-10-05T12:00:00.000Z").
//
// Besluiten Ibrahim 3 okt (onderzoek buitenland), exacte grenzen volgen van
// de jurist; daarom staan ze hier als constanten:
//   punt 6  minimumleeftijd per categorie (KLUS_CATEGORIEEN)
//   punt 7  een klus die vóór 07:00 begint, na 19:00 eindigt, zonder
//           eindtijd na 17:00 begint of langer dan 2 uur duurt: alleen 18+
//   punt 8  automatisch voorfilter op de tekst (markeert, blokkeert niet)

/// Absolute ondergrens voor een helper (zelfde als B2).
var MIN_LEEFTIJD_HELPER = 10;
var VOLWASSEN = 18;

/// Tijdvenster voor helpers onder de 18, in minuten na middernacht (NL-tijd).
var VROEGSTE_START_MIN = 7 * 60;
var LAATSTE_EIND_MIN = 19 * 60;
var LAATSTE_START_ZONDER_EIND_MIN = 17 * 60;
var MAX_DUUR_MIN = 2 * 60;

var OMSCHRIJVING_MIN = 5;
var OMSCHRIJVING_MAX = 300;
/// Klokverschil tussen toestel en server: zoveel mag "nu" in het verleden liggen.
var SPELING_VERLEDEN_MS = 5 * 60 * 1000;

/// De 13 categorieën uit de mockup KlusPlaatsen, in die volgorde. icoon =
/// naam die de app vertaalt (app/lib/features/hulpvrager/domein/klustype_icoon.dart).
/// Geen icoon van een mens of dier (alleen voorwerpen; "pets" is een pootafdruk).
var KLUS_CATEGORIEEN = [
  { naam: "Tuin", icoon: "yard", min_leeftijd: 13 },
  { naam: "Auto & fiets", icoon: "pedal_bike", min_leeftijd: 13 },
  { naam: "Schoonmaak", icoon: "cleaning_services", min_leeftijd: 16 },
  { naam: "Opruimen", icoon: "inventory_2", min_leeftijd: 13 },
  { naam: "Boodschappen", icoon: "shopping_cart", min_leeftijd: 10 },
  { naam: "Dieren", icoon: "pets", min_leeftijd: 10 },
  { naam: "Computer", icoon: "computer", min_leeftijd: 13 },
  { naam: "Rondom huis", icoon: "fence", min_leeftijd: 10 },
  { naam: "Helpende hand", icoon: "favorite_border", min_leeftijd: 10 },
  { naam: "Creatief", icoon: "brush", min_leeftijd: 13 },
  { naam: "Kleine klusjes", icoon: "handyman", min_leeftijd: 10 },
  { naam: "Hulp & kennis", icoon: "lightbulb", min_leeftijd: 13 },
  { naam: "Overig", icoon: "more_horiz", min_leeftijd: 13 },
].map(function (c, i) {
  return { naam: c.naam, icoon: c.icoon, min_leeftijd: c.min_leeftijd, volgorde: i + 1 };
});

/// De oude klustypes (seed M1) blijven bestaan voor de klussen die ernaar
/// verwijzen, maar zijn niet meer te kiezen (actief = nee). Zo tellen ze mee
/// in de leeftijdsregel. Bij twijfel de strengste: "klusje in huis" is
/// binnen in huis (16), vervoer is autorijden (18).
var OUDE_KLUSTYPES_MIN_LEEFTIJD = {
  boodschappen: 10,
  tuin: 13,
  "klusje in huis": 16,
  "telefoon/tablet-hulp": 13,
  "wandelen/gezelschap": 10,
  vervoer: 18,
};

/// Woorden uit de nee-lijst (besluit punt 5). Alleen hele woorden, klein.
var NEE_LIJST_WOORDEN = [
  "bier", "wijn", "alcohol", "drank", "jenever", "wodka", "whisky",
  "sigaret", "sigaretten", "sigaar", "sigaren", "tabak", "shag", "vape",
  "ladder", "dakgoot", "kettingzaag", "motorzaag", "bosmaaier", "slijptol",
  "medicijn", "medicijnen", "pillen", "douchen", "oppassen", "babysit", "babysitten",
];

var MELDING_FOTO = "Voeg een foto van de klus toe. Zie je geen fotoknop? Werk de app dan bij.";
var MELDING_OMSCHRIJVING =
  "Vertel in een paar woorden wat er moet gebeuren (5 tot 300 tekens).";
var MELDING_NEE_LIJST =
  "Vink aan dat je klus niet op de lijst staat van dingen die niet via HeitjeHulp kunnen.";
var MELDING_WANNEER = "Kies wanneer de klus is.";
var MELDING_VERLEDEN = "Deze tijd is al voorbij. Kies een later moment.";
var MELDING_TOT = "De eindtijd moet na de begintijd liggen.";

// ---------------------------------------------------------------- tijd

function alsMs(waarde) {
  var tekst = String(waarde || "").trim();
  if (!tekst) return null;
  var ms = Date.parse(tekst.replace(" ", "T"));
  return isFinite(ms) ? ms : null;
}

/// De laatste zondag van [maand] (0-11) in [jaar], 01:00 UTC: de EU-wissel
/// van zomer- en wintertijd. Zelfde regel als hh_meldingen_hulp.js; hier een
/// eigen kopie zodat B4 dat bestand niet raakt.
function laatsteZondagEenUur(jaar, maand) {
  var laatsteDag = new Date(Date.UTC(jaar, maand + 1, 0));
  return Date.UTC(jaar, maand, laatsteDag.getUTCDate() - laatsteDag.getUTCDay(), 1, 0, 0);
}

function tweeCijfers(n) {
  return n < 10 ? "0" + n : String(n);
}

/// UTC-moment -> Nederlandse wandklok { datum: "YYYY-MM-DD", minuten }.
/// De JSVM heeft geen tijdzonedatabase; de server draait UTC.
function nlTijd(waarde) {
  var ms = alsMs(waarde);
  if (ms === null) return null;
  var jaar = new Date(ms).getUTCFullYear();
  var zomer = ms >= laatsteZondagEenUur(jaar, 2) && ms < laatsteZondagEenUur(jaar, 9);
  var lokaal = new Date(ms + (zomer ? 2 : 1) * 3600 * 1000);
  return {
    datum:
      lokaal.getUTCFullYear() + "-" + tweeCijfers(lokaal.getUTCMonth() + 1) + "-" +
      tweeCijfers(lokaal.getUTCDate()),
    minuten: lokaal.getUTCHours() * 60 + lokaal.getUTCMinutes(),
  };
}

/// Punt 7: valt deze klus buiten het venster voor helpers onder de 18?
/// { van, tot } als datumtekst; tot mag leeg zijn. Zonder begintijd geen
/// tijdregel (de categorie telt dan alleen).
function isAlleen18Plus(k) {
  var van = alsMs(k && k.van);
  if (van === null) return false;
  var tot = alsMs(k && k.tot);
  if (tot !== null && tot <= van) tot = null;
  var start = nlTijd(k.van);
  if (start.minuten < VROEGSTE_START_MIN) return true;
  if (tot === null) return start.minuten > LAATSTE_START_ZONDER_EIND_MIN;
  if ((tot - van) / 60000 > MAX_DUUR_MIN) return true;
  var eind = nlTijd(k.tot);
  if (eind.datum !== start.datum) return true;
  return eind.minuten > LAATSTE_EIND_MIN;
}

/// De minimumleeftijd van een klus: de categorie, of 18 door de tijdregel.
/// Een categorie zonder (geldige) minimumleeftijd telt veilig als 18.
function minLeeftijdVoorKlus(k) {
  var type = Number(k && k.typeMinLeeftijd);
  var basis = isFinite(type) && type > 0 ? type : VOLWASSEN;
  if (isAlleen18Plus(k || {})) basis = Math.max(basis, VOLWASSEN);
  return Math.max(basis, MIN_LEEFTIJD_HELPER);
}

function isSchrikkeljaar(jaar) {
  return (jaar % 4 === 0 && jaar % 100 !== 0) || jaar % 400 === 0;
}

/// Wie op de (Nederlandse) klusdag [jaren] oud is, is uiterlijk op deze dag
/// geboren. PocketBase-datum aan het eind van die dag, zodat een geboortedatum
/// van die dag (00:00) er in een rule ("<=") onder valt. "" zonder moment.
function geborenUiterlijk(moment, jaren) {
  var dag = nlTijd(moment);
  if (!dag) return "";
  var delen = dag.datum.split("-").map(Number);
  var jaar = delen[0] - Number(jaren);
  var maand = delen[1];
  var d = delen[2];
  if (maand === 2 && d === 29 && !isSchrikkeljaar(jaar)) d = 28;
  return jaar + "-" + tweeCijfers(maand) + "-" + tweeCijfers(d) + " 23:59:59.999Z";
}

/// Is iemand met [geboortedatum] oud genoeg voor een klus met deze grens?
/// Zelfde vergelijking als de rule: geboortedatum <= geboren_uiterlijk.
function isOudGenoeg(geboortedatum, grens) {
  var g = String(geboortedatum || "").trim().slice(0, 10);
  var u = String(grens || "").trim().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(g) || !/^\d{4}-\d{2}-\d{2}$/.test(u)) return false;
  return g <= u;
}

// ---------------------------------------------------------------- tekst

/// Punt 8: wat de meldkamer extra moet bekijken. Lijst van telefoon, email,
/// link, neelijst (in die volgorde, elk hooguit één keer). Blokkeert niets.
function voorfilter(tekst) {
  var t = String(tekst || "");
  var uit = [];
  var reeksen = t.match(/[+(]?\d[\d\s\-().]{7,}\d/g) || [];
  for (var i = 0; i < reeksen.length; i++) {
    if (reeksen[i].replace(/\D/g, "").length >= 9) {
      uit.push("telefoon");
      break;
    }
  }
  if (/[^\s@]+@[^\s@]+\.[a-z]{2,}/i.test(t)) uit.push("email");
  if (/https?:\/\/|www\.|\b[a-z0-9-]+\.(nl|com|net|org|eu|be|de|info|io)\b/i.test(t)) {
    if (uit.indexOf("email") === -1 || /https?:\/\/|www\./i.test(t)) uit.push("link");
  }
  var woorden = t.toLowerCase().split(/[^a-z0-9à-ÿ]+/);
  for (var j = 0; j < woorden.length; j++) {
    if (NEE_LIJST_WOORDEN.indexOf(woorden[j]) !== -1) {
      uit.push("neelijst");
      break;
    }
  }
  return uit;
}

// ---------------------------------------------------------------- invoer

/// Klopt een nieuwe klus van een bewoner? null = goed, anders
/// { reden, melding }. { omschrijving, heeftFoto, neeLijstAkkoord, van, tot,
/// nu (ms) }.
function controleerNieuweKlus(k) {
  var omschrijving = String(k.omschrijving || "").trim();
  if (omschrijving.length < OMSCHRIJVING_MIN || omschrijving.length > OMSCHRIJVING_MAX) {
    return { reden: "omschrijving", melding: MELDING_OMSCHRIJVING };
  }
  if (!k.heeftFoto) return { reden: "foto", melding: MELDING_FOTO };
  var van = alsMs(k.van);
  if (van === null) return { reden: "wanneer", melding: MELDING_WANNEER };
  var nu = Number(k.nu);
  if (isFinite(nu) && van < nu - SPELING_VERLEDEN_MS) {
    return { reden: "verleden", melding: MELDING_VERLEDEN };
  }
  var tot = alsMs(k.tot);
  if (tot !== null && tot <= van) return { reden: "tot", melding: MELDING_TOT };
  if (k.neeLijstAkkoord !== true) return { reden: "neelijst", melding: MELDING_NEE_LIJST };
  return null;
}

/// De melding die de bewoner krijgt als de meldkamer zijn klus afkeurt.
function afkeurTekst(reden) {
  return {
    titel: "Je klus is afgekeurd",
    tekst:
      "De meldkamer heeft je klus afgekeurd: " + String(reden || "").trim() +
      " Je kunt een nieuwe klus plaatsen of de meldkamer bellen.",
  };
}

/// Mag deze helper een melding "nieuwe klus" krijgen? Pas na goedkeuring en
/// alleen als hij oud genoeg is (zelfde grens als de lijst-rule).
function magNieuweKlusMelding(m) {
  if (!String(m.goedgekeurdOp || "").trim()) return false;
  return isOudGenoeg(m.geboortedatum, m.geborenUiterlijk);
}

module.exports = {
  MIN_LEEFTIJD_HELPER: MIN_LEEFTIJD_HELPER,
  VOLWASSEN: VOLWASSEN,
  VROEGSTE_START_MIN: VROEGSTE_START_MIN,
  LAATSTE_EIND_MIN: LAATSTE_EIND_MIN,
  LAATSTE_START_ZONDER_EIND_MIN: LAATSTE_START_ZONDER_EIND_MIN,
  MAX_DUUR_MIN: MAX_DUUR_MIN,
  OMSCHRIJVING_MAX: OMSCHRIJVING_MAX,
  KLUS_CATEGORIEEN: KLUS_CATEGORIEEN,
  OUDE_KLUSTYPES_MIN_LEEFTIJD: OUDE_KLUSTYPES_MIN_LEEFTIJD,
  NEE_LIJST_WOORDEN: NEE_LIJST_WOORDEN,
  nlTijd: nlTijd,
  isAlleen18Plus: isAlleen18Plus,
  minLeeftijdVoorKlus: minLeeftijdVoorKlus,
  geborenUiterlijk: geborenUiterlijk,
  isOudGenoeg: isOudGenoeg,
  voorfilter: voorfilter,
  controleerNieuweKlus: controleerNieuweKlus,
  afkeurTekst: afkeurTekst,
  magNieuweKlusMelding: magNieuweKlusMelding,
};

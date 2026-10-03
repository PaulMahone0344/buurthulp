// HeitjeHulp B2 — hh_aanmelden_hulp.js (hulpbestand, GEEN hook)
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. De
// handlers in hh_aanmelden.pb.js en hh_klussen.pb.js halen dit bestand
// BINNEN de handler op met require(`${__hooks}/hh_aanmelden_hulp.js`).
// Puur rekenwerk (geen $app), zodat backend/tests/hh_aanmelden_hulp.test.mjs
// het zonder server kan testen. Datums komen binnen als tekst
// ("2008-05-14 00:00:00.000Z" of "2008-05-14"); vandaag als "YYYY-MM-DD"
// (UTC, de server draait UTC).

/// Een helper (rol jongere) is minstens 10 jaar (besluit koers B).
var MIN_LEEFTIJD_HELPER = 10;
/// Vanaf 18: VOG verplicht, geen ouder-toestemming meer nodig.
var VOLWASSEN = 18;

var MELDING_TE_JONG = "Je moet minstens 10 jaar zijn om helper te worden.";
var MELDING_GEEN_GEBOORTEDATUM =
  "Je geboortedatum ontbreekt. Neem contact op met de meldkamer.";
var MELDING_OUDER =
  "Je ouder moet eerst toestemming geven. Daarna kun je klussen aannemen.";
var MELDING_VOG =
  "De meldkamer heeft je VOG nog niet gezien. Daarna kun je klussen aannemen.";
var MELDING_VOG_VERLOPEN =
  "Je VOG is verlopen. Vraag de meldkamer naar een nieuwe VOG; tot die tijd kun je geen klussen aannemen.";

/// Velden van een helper die alleen de helper zelf en de coordinator zien.
/// Een bewoner (of een ander) krijgt ze niet in het antwoord (onRecordEnrich).
var VERBORGEN_VOOR_ANDEREN = [
  "email",
  "geboortedatum",
  "adres",
  "huisnummer",
  "postcode",
  "plaats",
  "telefoon",
  "contact_naam",
  "contact_telefoon",
  "ouder_email",
  "ouder_telefoon",
  "ouder_toestemming_op",
  "ouder_iban_ok",
  "werkgebied_status",
];

/// "2008-05-14 00:00:00.000Z" -> [2008, 5, 14], of null.
function datumDelen(tekst) {
  var m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(tekst || "").trim());
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

/// Leeftijd in hele jaren op [vandaag] ("YYYY-MM-DD"), of null als de
/// geboortedatum leeg of onleesbaar is. Een verjaardag telt op de dag zelf;
/// 29 februari telt in een gewoon jaar op 1 maart.
function leeftijd(geboortedatum, vandaag) {
  var g = datumDelen(geboortedatum);
  var v = datumDelen(vandaag);
  if (!g || !v) return null;
  var jaren = v[0] - g[0];
  if (v[1] < g[1] || (v[1] === g[1] && v[2] < g[2])) jaren--;
  return jaren;
}

/// Weigert de server dit account? Alleen een helper (rol jongere) met een
/// ingevulde geboortedatum onder de 10 (een datum in de toekomst ook).
function isTeJong(rol, geboortedatum, vandaag) {
  if (String(rol || "") !== "jongere") return false;
  var jaren = leeftijd(geboortedatum, vandaag);
  return jaren !== null && jaren < MIN_LEEFTIJD_HELPER;
}

function isGevuld(waarde) {
  return String(waarde || "").trim() !== "";
}

/// Waarom mag deze (goedgekeurde) helper nog geen klus aannemen? null = mag.
///   { geboortedatum, ouderToestemmingOp, vogGezienOp, vogGeldigTot, vandaag }
/// Volgorde: geen geboortedatum -> onder 18 zonder ouder-toestemming ->
/// 18+ zonder vog_gezien_op -> een verlopen vog_geldig_tot (oude data, M14).
function klusBlokkade(g) {
  var jaren = leeftijd(g.geboortedatum, g.vandaag);
  if (jaren === null) return { reden: "geboortedatum", melding: MELDING_GEEN_GEBOORTEDATUM };
  if (jaren < VOLWASSEN) {
    if (!isGevuld(g.ouderToestemmingOp)) return { reden: "ouder", melding: MELDING_OUDER };
  } else if (!isGevuld(g.vogGezienOp)) {
    return { reden: "vog", melding: MELDING_VOG };
  }
  var tot = String(g.vogGeldigTot || "").slice(0, 10);
  if (tot && tot < String(g.vandaag || "").slice(0, 10)) {
    return { reden: "vogverlopen", melding: MELDING_VOG_VERLOPEN };
  }
  return null;
}

// ---------------------------------------------------------------- werkgebied
// B2 (besluit Ibrahim 3 okt): het werkgebied is Tiel en alle dorpen binnen
// 20 km. Wie daar woont, krijgt bij aanmelden de wijk "Tiel en omstreken"
// (hh_wijken, regio = ja). Een tweede stad = een regel erbij.

/// Werkgebieden: middelpunt + straal. [wijk]/[gemeente] = het hh_wijken-
/// record dat iemand binnen de straal krijgt (aangemaakt door 81).
var WERKGEBIEDEN = [
  { gemeente: "Tiel", wijk: "Tiel en omstreken", lat: 51.8865, lon: 5.4300, straalKm: 20 },
];

var NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
var USER_AGENT = "HeitjeHulp/0.1 (info@heitjehulp.nl)";
/// Nominatim-gebruiksregel: hooguit 1 verzoek per seconde.
var MIN_TUSSENTIJD_MS = 1000;
var STORE_SLEUTEL = "hh_nominatim_laatst";

/// Afstand in km tussen twee punten {lat, lon} (haversine).
function afstandKm(a, b) {
  var r = 6371;
  var rad = Math.PI / 180;
  var dLat = (b.lat - a.lat) * rad;
  var dLon = (b.lon - a.lon) * rad;
  var h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 2 * r * Math.asin(Math.min(1, Math.sqrt(h)));
}

/// Het eerste werkgebied waar [punt] binnen de straal ligt, of null.
function werkgebiedVoorPunt(punt) {
  for (var i = 0; i < WERKGEBIEDEN.length; i++) {
    var g = WERKGEBIEDEN[i];
    if (afstandKm({ lat: g.lat, lon: g.lon }, punt) <= g.straalKm) return g;
  }
  return null;
}

/// Gestructureerd zoeken op postcode. Met huisnummer erbij (vrije tekst)
/// geeft Nominatim voor NL vaak niets; het middelpunt van de 6-tekens-
/// postcode is voor een straal van 20 km ruim precies genoeg.
function nominatimUrl(basis, postcode) {
  return basis + "?format=json&limit=1&countrycodes=nl&postalcode=" + encodeURIComponent(postcode);
}

/// Het eerste punt uit een Nominatim-antwoord, of null.
function leesPunt(res) {
  if (!res || res.statusCode !== 200) return null;
  var lijst = res.json;
  if (!Array.isArray(lijst)) {
    try {
      lijst = JSON.parse(String(res.raw || ""));
    } catch (_) {
      lijst = [];
    }
  }
  if (!Array.isArray(lijst) || lijst.length === 0) return null;
  var lat = parseFloat(lijst[0].lat);
  var lon = parseFloat(lijst[0].lon);
  if (!isFinite(lat) || !isFinite(lon)) return null;
  return { lat: lat, lon: lon };
}

/// Waar woont iemand met deze postcode? { status, werkgebied }:
///   binnen   -> werkgebied = de regel uit WERKGEBIEDEN
///   buiten   -> gevonden, maar verder dan elke straal
///   onbekend -> ongeldige postcode, geen resultaat, fout of geen internet
///               (aanmelden gaat door; de meldkamer ziet de markering)
/// [env] = { url, http(req) -> res, nu() -> ms, sleep(ms), store{get,set}, log }.
/// Wacht zo nodig tot er 1 seconde sinds het vorige verzoek voorbij is.
function bepaalWerkgebied(env, postcode) {
  var m = /^([1-9]\d{3})\s*([A-Za-z]{2})$/.exec(String(postcode || "").trim());
  if (!m) return { status: "onbekend", werkgebied: null };
  var netjes = m[1] + " " + m[2].toUpperCase();

  var vorige = Number(env.store.get(STORE_SLEUTEL) || 0);
  var wacht = vorige + MIN_TUSSENTIJD_MS - env.nu();
  if (vorige && wacht > 0) env.sleep(wacht);
  env.store.set(STORE_SLEUTEL, env.nu());

  var res;
  try {
    res = env.http({
      url: nominatimUrl(env.url || NOMINATIM_URL, netjes),
      method: "GET",
      headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
      timeout: 5,
    });
  } catch (err) {
    env.log("[hh_aanmelden] geocoding mislukt (verzoek):", String(err));
    return { status: "onbekend", werkgebied: null };
  }
  var punt = leesPunt(res);
  if (!punt) {
    env.log("[hh_aanmelden] geocoding: geen bruikbaar resultaat, status", res ? res.statusCode : "geen");
    return { status: "onbekend", werkgebied: null };
  }
  var gebied = werkgebiedVoorPunt(punt);
  return gebied ? { status: "binnen", werkgebied: gebied } : { status: "buiten", werkgebied: null };
}

/// De id van de actieve hh_wijken-rij van [gebied], of "" (dan bestaat hij
/// nog niet: 81 niet gedraaid).
function wijkIdVoor(app, gebied) {
  try {
    var rijen = app.findRecordsByFilter(
      "hh_wijken",
      "actief = true && gemeente = {:gemeente} && wijk = {:wijk}",
      "",
      1,
      0,
      { gemeente: gebied.gemeente, wijk: gebied.wijk }
    );
    return rijen.length ? String(rijen[0].id) : "";
  } catch (err) {
    console.log("[hh_aanmelden] werkgebied-wijk zoeken mislukt:", String(err));
    return "";
  }
}

/// Mag een helper uit wijk [a] een klus van een bewoner uit wijk [b] (of
/// andersom)? Zelfde wijk, of dezelfde gemeente als een van de twee een
/// regio-wijk is ("Tiel en omstreken" past bij Tiel-West en Passewaaij).
/// Twee oude wijken blijven elk apart (oud gedrag, geen datamigratie).
/// [a]/[b] = { id, gemeente, regio } of null.
function wijkenPassen(a, b) {
  if (!a || !b || !a.id || !b.id) return false;
  if (String(a.id) === String(b.id)) return true;
  return String(a.gemeente) === String(b.gemeente) && (a.regio === true || b.regio === true);
}

/// Alleen het eerste woord: een bewoner ziet nooit de achternaam.
function voornaam(naam) {
  return String(naam || "").trim().split(/\s+/)[0] || "";
}

/// Mag deze kijker alle velden van helper [helperId] zien? Alleen de helper
/// zelf of een coordinator.
function magAllesZien(kijkerId, kijkerRol, helperId) {
  if (!kijkerId) return false;
  return String(kijkerId) === String(helperId) || String(kijkerRol || "") === "coordinator";
}

module.exports = {
  MIN_LEEFTIJD_HELPER: MIN_LEEFTIJD_HELPER,
  VOLWASSEN: VOLWASSEN,
  MELDING_TE_JONG: MELDING_TE_JONG,
  VERBORGEN_VOOR_ANDEREN: VERBORGEN_VOOR_ANDEREN,
  leeftijd: leeftijd,
  isTeJong: isTeJong,
  klusBlokkade: klusBlokkade,
  WERKGEBIEDEN: WERKGEBIEDEN,
  afstandKm: afstandKm,
  werkgebiedVoorPunt: werkgebiedVoorPunt,
  nominatimUrl: nominatimUrl,
  bepaalWerkgebied: bepaalWerkgebied,
  wijkIdVoor: wijkIdVoor,
  wijkenPassen: wijkenPassen,
  voornaam: voornaam,
  magAllesZien: magAllesZien,
};

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

/// "4003 AB" -> "4003". Alleen een Nederlandse postcode (eerste cijfer niet
/// 0, letters mogen ontbreken); anders "".
function postcodeCijfers(postcode) {
  var m = /^([1-9]\d{3})\s*([A-Za-z]{2})?$/.exec(String(postcode || "").trim());
  return m ? m[1] : "";
}

/// De id van de ACTIEVE wijk waar deze postcode bij hoort, of "".
/// [wijken] = [{ id, postcodes: ["4003", ...], actief }].
function wijkVoorPostcode(postcode, wijken) {
  var cijfers = postcodeCijfers(postcode);
  if (!cijfers) return "";
  for (var i = 0; i < (wijken || []).length; i++) {
    var w = wijken[i];
    if (!w.actief) continue;
    var lijst = w.postcodes || [];
    for (var j = 0; j < lijst.length; j++) {
      if (String(lijst[j]).trim() === cijfers) return String(w.id);
    }
  }
  return "";
}

/// wijkVoorPostcode met de actieve wijken uit de database. [app] is $app,
/// [decodeer] de JSVM-functie toString (json-velden komen als byte-array).
/// Lukt het lezen niet, dan "" (geen wijk); aanmelden gaat altijd door.
function wijkUitDatabase(app, decodeer, postcode) {
  try {
    var rijen = app.findRecordsByFilter("hh_wijken", "actief = true", "", 200, 0);
    var wijken = [];
    for (var i = 0; i < rijen.length; i++) {
      var tekst = decodeer(rijen[i].get("postcodes"));
      wijken.push({
        id: rijen[i].id,
        actief: !!rijen[i].getBool("actief"),
        postcodes: tekst ? JSON.parse(tekst) : [],
      });
    }
    return wijkVoorPostcode(postcode, wijken);
  } catch (err) {
    console.log("[hh_aanmelden] wijk zoeken mislukt:", String(err));
    return "";
  }
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
  postcodeCijfers: postcodeCijfers,
  wijkVoorPostcode: wijkVoorPostcode,
  wijkUitDatabase: wijkUitDatabase,
  voornaam: voornaam,
  magAllesZien: magAllesZien,
};

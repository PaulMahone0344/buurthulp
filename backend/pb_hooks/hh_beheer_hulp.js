// HeitjeHulp M14 — hulpfuncties voor hh_beheer.pb.js. Gewoon .js (GEEN hook):
// de hook haalt dit BINNEN elke handler op met require(`${__hooks}/...`),
// omdat de pool-runtime geen scope deelt tussen handlers. Puur rekenwerk,
// zodat backend/tests/hh_beheer_hulp.test.mjs het zonder server kan testen.

/// Op deze collecties logt de hook elke handeling van een coordinator.
var AUDIT_COLLECTIES = [
  "hh_wijken",
  "hh_klustypes",
  "hh_users",
  "hh_profielen",
  "hh_instellingen",
  "hh_incidenten",
];

/// Velden waarvan de WAARDE nooit in het auditlog komt (alleen de naam).
var GEHEIM = [
  "password",
  "passwordConfirm",
  "tokenKey",
  "document_foto",
  "selfie",
  "iban",
];

/// Velden die geen beheerhandeling zijn (automatisch of systeem).
var OVERSLAAN = ["id", "created", "updated", "collectionId", "collectionName", "expand"];

var MAX_TEKST = 200;

var MELDING_GEBLOKKEERD = "Dit account is geblokkeerd. Neem contact op met de meldkamer.";

/// Paden waarop een geblokkeerde gebruiker niets meer mag: de eigen
/// hh-routes, de record-API van elke hh_-collectie en realtime.
function isHhPad(pad) {
  var p = String(pad || "");
  return (
    p.indexOf("/api/hh/") === 0 ||
    p.indexOf("/api/collections/hh_") === 0 ||
    p === "/api/realtime" ||
    p.indexOf("/api/realtime/") === 0
  );
}

/// Is deze auth een coordinator uit hh_users? collectieNaam en rol komen van
/// de hook (auth.collection().name en auth.get("rol")).
function isCoordinator(collectieNaam, rol) {
  return String(collectieNaam || "") === "hh_users" && String(rol || "") === "coordinator";
}

/// Een waarde klein en leesbaar maken voor het log.
function kort(waarde) {
  if (waarde === null || waarde === undefined) return "";
  if (typeof waarde === "boolean" || typeof waarde === "number") return waarde;
  if (Array.isArray(waarde)) {
    var lijst = [];
    for (var i = 0; i < waarde.length && i < 50; i++) lijst.push(kort(waarde[i]));
    return lijst;
  }
  if (typeof waarde === "object") {
    var tekst = JSON.stringify(waarde);
    return tekst.length > MAX_TEKST ? tekst.substring(0, MAX_TEKST) + "…" : tekst;
  }
  var s = String(waarde);
  return s.length > MAX_TEKST ? s.substring(0, MAX_TEKST) + "…" : s;
}

function gelijk(a, b) {
  return JSON.stringify(a === undefined ? "" : a) === JSON.stringify(b === undefined ? "" : b);
}

function isLeeg(waarde) {
  return (
    waarde === null ||
    waarde === undefined ||
    waarde === "" ||
    (Array.isArray(waarde) && waarde.length === 0)
  );
}

/// detail voor het auditlog.
///   aanmaken:     { velden: [...], waarden: {...} }   (alleen gevulde velden)
///   wijzigen:     { velden: [...], van: {...}, naar: {...} } (alleen wat veranderde)
///   verwijderen:  { waarden: {...} }                  (wat er stond)
/// Geheime velden staan wel in "velden", nooit in waarden/van/naar.
function auditDetail(actie, voor, na) {
  voor = voor || {};
  na = na || {};
  var namen = {};
  var k;
  for (k in voor) namen[k] = true;
  for (k in na) namen[k] = true;

  var velden = [];
  var van = {};
  var naar = {};
  var waarden = {};
  for (k in namen) {
    if (OVERSLAAN.indexOf(k) !== -1) continue;
    var geheim = GEHEIM.indexOf(k) !== -1;
    if (actie === "wijzigen") {
      if (gelijk(voor[k], na[k])) continue;
      velden.push(k);
      if (!geheim) {
        van[k] = kort(voor[k]);
        naar[k] = kort(na[k]);
      }
    } else {
      var bron = actie === "verwijderen" ? voor : na;
      if (isLeeg(bron[k])) continue;
      velden.push(k);
      if (!geheim) waarden[k] = kort(bron[k]);
    }
  }
  velden.sort();
  if (actie === "wijzigen") return { velden: velden, van: van, naar: naar };
  if (actie === "verwijderen") return { velden: velden, waarden: waarden };
  return { velden: velden, waarden: waarden };
}

/// Een record als plat object. [decodeer] maakt van een json-veld (komt in de
/// JSVM binnen als byte-array) weer een waarde; de hook geeft toString mee.
function plat(record, decodeer) {
  var uit = {};
  if (!record) return uit;
  var velden = record.collection().fields;
  for (var i = 0; i < velden.length; i++) {
    var veld = velden[i];
    var naam = String(veld.getName());
    var soort = String(veld.type());
    if (soort === "password" || OVERSLAAN.indexOf(naam) !== -1) continue;
    var waarde = record.get(naam);
    if (soort === "json") {
      try {
        var tekst = decodeer(waarde);
        waarde = tekst ? JSON.parse(tekst) : null;
      } catch (_) {
        waarde = null;
      }
    } else if (soort === "bool") {
      waarde = !!waarde;
    } else if (soort === "number") {
      waarde = Number(waarde || 0);
    } else if (soort === "relation" || soort === "select" || soort === "file") {
      // Meerkeuze komt als Go-slice; een enkele als tekst.
      if (waarde && typeof waarde === "object" && typeof waarde.length === "number") {
        var lijst = [];
        for (var j = 0; j < waarde.length; j++) lijst.push(String(waarde[j]));
        waarde = lijst;
      } else {
        waarde = String(waarde || "");
      }
    } else {
      waarde = String(waarde || "");
    }
    uit[naam] = waarde;
  }
  return uit;
}

/// B1: is dit de overgang naar "goedgekeurd"? Alleen dan wist de hook het
/// ID-document en zet hij id_gecontroleerd_op/_door. Nogmaals goedgekeurd
/// opslaan (al goedgekeurd) telt niet: dan is er niets nieuw gecontroleerd.
function isGoedkeuring(oudeStatus, nieuweStatus) {
  return String(nieuweStatus || "") === "goedgekeurd" && String(oudeStatus || "") !== "goedgekeurd";
}

module.exports = {
  AUDIT_COLLECTIES: AUDIT_COLLECTIES,
  GEHEIM: GEHEIM,
  MELDING_GEBLOKKEERD: MELDING_GEBLOKKEERD,
  isHhPad: isHhPad,
  isCoordinator: isCoordinator,
  isGoedkeuring: isGoedkeuring,
  auditDetail: auditDetail,
  plat: plat,
  kort: kort,
};

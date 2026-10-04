// HeitjeHulp ADRES — hh_adres_hulp.js (hulpbestand, GEEN hook)
//
// Strengere adresregels + adres-suggestie zoals bol.com (besluit Ibrahim
// 4 okt): postcode + huisnummer (+ toevoeging) -> straat en plaats van de
// PDOK Locatieserver (BAG, overheid, gratis, geen sleutel). Gebruikt door:
//   hh_adres.pb.js     GET /api/hh/adres (de suggestie in app en paneel)
//   hh_aanmelden.pb.js hh_users aanmaken/bijwerken (de server is de waarheid)
//   hh_klussen.pb.js   klus op het adres van de bewoner -> zijn PDOK-punt
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. De
// handlers halen dit bestand BINNEN de handler op met require(). Geen $app:
// alles wat de buitenwereld raakt komt via [env] binnen, zodat
// backend/tests/hh_adres_hulp.test.mjs het zonder server en zonder echte
// PDOK kan testen.
//
// [env] = { url, http(req) -> res, nu() -> ms, store{get,set,remove}, log,
//           binnen(punt) -> bool }

var PDOK_URL = "https://api.pdok.nl/bzk/locatieserver/search/v3_1/free";
var PDOK_VELDEN =
  "weergavenaam,straatnaam,huisnummer,huisletter,huisnummertoevoeging,postcode,woonplaatsnaam,gemeentenaam,centroide_ll";
/// Een flat kan veel toevoegingen hebben; 50 is ruim (PDOK staat 100 toe).
var PDOK_RIJEN = 50;
var TIMEOUT_S = 5;
var USER_AGENT = "HeitjeHulp/0.1 (info@heitjehulp.nl)";

/// Hetzelfde adres binnen 10 minuten nog eens (opzoeken in de app, daarna
/// aanmelden) vraagt PDOK niet opnieuw.
var CACHE_MS = 10 * 60 * 1000;
var CACHE_SLEUTEL = "hh_pdok:";
var LIMIET_SLEUTEL = "hh_adres_ip:";

/// Opzoekingen per IP per uur. Typen met debounce kost een paar verzoeken
/// per adres; 60 is ruim voor een gezin achter één IP.
var MAX_ANONIEM_PER_UUR = 60;
var MAX_INGELOGD_PER_UUR = 120;

/// Wie moet een geldig adres hebben (bewoner en helper).
var ROLLEN_MET_ADRES = ["hulpvrager", "jongere"];

/// Velden op hh_users die alleen de server (of coordinator/superuser) zet.
var SERVERVELDEN = ["lat", "lon", "adres_bron"];
/// Velden die samen "het adres" zijn: verandert er een, dan opnieuw toetsen.
var ADRESVELDEN = ["adres", "postcode", "huisnummer", "toevoeging", "plaats"];

var MELDING = {
  verplicht: "Vul je postcode en huisnummer in.",
  postcode: "Een postcode is 4 cijfers en 2 letters, bijvoorbeeld 4001 MA.",
  huisnummer:
    "Vul je huisnummer in, alleen cijfers. Een letter of toevoeging zet je in het vakje Toevoeging.",
  toevoeging: "Deze toevoeging kennen we niet op dit huisnummer. Kies er een uit de lijst.",
  toevoegingVorm: "Een toevoeging is hooguit 6 letters of cijfers, bijvoorbeeld A of 2.",
  kiestoevoeging: "Op dit huisnummer zijn meerdere adressen. Kies je toevoeging.",
  nietgevonden: "We vinden dit adres niet. Klopt de postcode en het huisnummer?",
  dienst: "We kunnen je adres nu niet controleren. Probeer het zo nog eens.",
  limiet: "Je hebt veel adressen opgezocht. Probeer het over een uur opnieuw.",
  servervelden: "De coördinaten en de bron van je adres vult de server zelf in.",
};

// ---------------------------------------------------------------- invoer

/// "4001ma" / " 4001 MA " -> "4001 MA"; anders null. 4 cijfers, niet 0
/// vooraan, dan 2 letters.
function normaliseerPostcode(tekst) {
  var schoon = String(tekst == null ? "" : tekst).replace(/\s+/g, "");
  var m = /^([1-9]\d{3})([A-Za-z]{2})$/.exec(schoon);
  return m ? m[1] + " " + m[2].toUpperCase() : null;
}

/// Alleen cijfers (1-5), niet 0; voorloopnullen weg. Anders null.
function normaliseerHuisnummer(tekst) {
  var schoon = String(tekst == null ? "" : tekst).trim();
  if (!/^\d{1,5}$/.test(schoon)) return null;
  var getal = parseInt(schoon, 10);
  return getal > 0 ? String(getal) : null;
}

/// Leeg mag (""). Anders letters/cijfers met hooguit een streepje of spatie
/// ertussen, samen max 6 tekens; een streepje vooraan valt weg ("-2" = "2").
function normaliseerToevoeging(tekst) {
  var schoon = String(tekst == null ? "" : tekst).trim().replace(/^-+/, "").trim();
  if (schoon === "") return "";
  if (schoon.length > 6) return null;
  return /^[A-Za-z0-9](?:[A-Za-z0-9 -]*[A-Za-z0-9])?$/.test(schoon) ? schoon : null;
}

/// De oude app (en mensen) zetten "12a" of "12-2" in het huisnummer:
/// dan nummer + toevoeging. null als het niet met een cijfer begint.
function splitsHuisnummer(tekst) {
  var schoon = String(tekst == null ? "" : tekst).trim();
  var m = /^(\d{1,5})\s*-?\s*(.*)$/.exec(schoon);
  if (!m) return null;
  return { huisnummer: m[1], toevoeging: m[2].trim() };
}

/// Voor vergelijken: "A-01", "a01" en "a 01" zijn dezelfde toevoeging.
function toevoegingSleutel(tekst) {
  return String(tekst == null ? "" : tekst).toLowerCase().replace(/[^a-z0-9]/g, "");
}

// ---------------------------------------------------------------- PDOK

function pdokUrl(basis, postcode, huisnummer) {
  var q = "postcode:" + String(postcode).replace(/\s+/g, "") + " and huisnummer:" + huisnummer;
  return (
    (basis || PDOK_URL) +
    "?q=" + encodeURIComponent(q) +
    "&fq=" + encodeURIComponent("type:adres") +
    "&rows=" + PDOK_RIJEN +
    "&fl=" + encodeURIComponent(PDOK_VELDEN)
  );
}

/// "POINT(5.43597055 51.88761538)" (lon lat) -> { lat, lon } of null.
function leesPunt(tekst) {
  var m = /^POINT\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s*\)$/.exec(String(tekst || "").trim());
  if (!m) return null;
  var lon = parseFloat(m[1]);
  var lat = parseFloat(m[2]);
  return isFinite(lat) && isFinite(lon) ? { lat: lat, lon: lon } : null;
}

/// Eén PDOK-document -> ons adres, of null als er iets wezenlijks mist.
///   toevoeging = huisletter + ("-" + huisnummertoevoeging), zoals BAG:
///   "a", "a-01", "2" (alleen toevoeging). adres = de regel voor hh_users.adres
///   ("Kerkstraat 1a-01"), weergave = de regel op het kaartje.
function leesAdres(doc) {
  if (!doc || typeof doc !== "object") return null;
  var straat = String(doc.straatnaam || "").trim();
  var nummer = normaliseerHuisnummer(doc.huisnummer);
  var postcode = normaliseerPostcode(doc.postcode);
  var plaats = String(doc.woonplaatsnaam || "").trim();
  var punt = leesPunt(doc.centroide_ll);
  if (!straat || !nummer || !postcode || !plaats || !punt) return null;
  var letter = String(doc.huisletter || "").trim();
  var toev = String(doc.huisnummertoevoeging || "").trim();
  var toevoeging = letter + (toev ? (letter ? "-" : "") + toev : "");
  var adres = straat + " " + nummer + letter + (toev ? "-" + toev : "");
  return {
    straat: straat,
    huisnummer: nummer,
    toevoeging: toevoeging,
    postcode: postcode,
    plaats: plaats,
    gemeente: String(doc.gemeentenaam || "").trim(),
    lat: punt.lat,
    lon: punt.lon,
    adres: adres,
    weergave: adres + ", " + postcode + " " + plaats,
  };
}

/// Zonder toevoeging eerst, dan "natuurlijk" (2 voor 10). Zelf geschreven:
/// de JSVM (goja) kent geen Intl-opties voor localeCompare.
function vergelijk(a, b) {
  if (!a.toevoeging && b.toevoeging) return -1;
  if (a.toevoeging && !b.toevoeging) return 1;
  var x = String(a.toevoeging).toLowerCase().match(/\d+|\D+/g) || [];
  var y = String(b.toevoeging).toLowerCase().match(/\d+|\D+/g) || [];
  for (var i = 0; i < Math.min(x.length, y.length); i++) {
    if (x[i] === y[i]) continue;
    var getallen = /^\d/.test(x[i]) && /^\d/.test(y[i]);
    if (getallen && Number(x[i]) !== Number(y[i])) return Number(x[i]) - Number(y[i]);
    return x[i] < y[i] ? -1 : 1;
  }
  return x.length - y.length;
}

/// PDOK-antwoord -> { ok, adressen }. ok = false: geen (bruikbaar) antwoord.
function leesAntwoord(res) {
  if (!res || res.statusCode !== 200) return { ok: false, adressen: [] };
  var data = res.json;
  if (!data || typeof data !== "object") {
    try {
      data = JSON.parse(String(res.raw || ""));
    } catch (_) {
      return { ok: false, adressen: [] };
    }
  }
  if (!data || !data.response || !Array.isArray(data.response.docs)) return { ok: false, adressen: [] };
  var adressen = [];
  for (var i = 0; i < data.response.docs.length; i++) {
    var a = leesAdres(data.response.docs[i]);
    if (a) adressen.push(a);
  }
  adressen.sort(vergelijk);
  return { ok: true, adressen: adressen };
}

/// Alle adressen op postcode + huisnummer (geldig, genormaliseerd), uit de
/// cache of van PDOK. { ok: false } = PDOK onbereikbaar (niet onthouden).
function zoek(env, postcode, huisnummer) {
  var sleutel = CACHE_SLEUTEL + postcode.replace(/\s+/g, "") + ":" + huisnummer;
  var bewaard = env.store.get(sleutel);
  if (bewaard) {
    try {
      var c = JSON.parse(String(bewaard));
      if (env.nu() - Number(c.t) < CACHE_MS && Array.isArray(c.adressen)) return { ok: true, adressen: c.adressen };
    } catch (_) {
      // kapotte cache: gewoon opnieuw vragen
    }
    env.store.remove(sleutel);
  }
  var res;
  try {
    res = env.http({
      url: pdokUrl(env.url, postcode, huisnummer),
      method: "GET",
      headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
      timeout: TIMEOUT_S,
    });
  } catch (err) {
    env.log("[hh_adres] PDOK onbereikbaar:", String(err));
    return { ok: false, adressen: [] };
  }
  var uit = leesAntwoord(res);
  if (!uit.ok) {
    env.log("[hh_adres] PDOK gaf geen bruikbaar antwoord, status", res ? res.statusCode : "geen");
    return uit;
  }
  env.store.set(sleutel, JSON.stringify({ t: env.nu(), adressen: uit.adressen }));
  return uit;
}

/// Alleen de adressen met deze toevoeging (leeg = alle).
function filterToevoeging(adressen, toevoeging) {
  if (!toevoeging) return adressen;
  var s = toevoegingSleutel(toevoeging);
  return adressen.filter(function (a) {
    return toevoegingSleutel(a.toevoeging) === s;
  });
}

/// Wat de route teruggeeft per adres (snake_case zoals de rest van de API).
function voorAntwoord(env, a) {
  return {
    straat: a.straat,
    huisnummer: a.huisnummer,
    toevoeging: a.toevoeging,
    postcode: a.postcode,
    plaats: a.plaats,
    gemeente: a.gemeente,
    lat: a.lat,
    lon: a.lon,
    adres: a.adres,
    weergave: a.weergave,
    binnen_werkgebied: !!(env.binnen && env.binnen({ lat: a.lat, lon: a.lon })),
  };
}

function ongeldig(reden, melding) {
  return { status: 400, body: { gevonden: false, reden: reden, melding: melding } };
}

/// GET /api/hh/adres. { status, body }:
///   400 { gevonden:false, reden: postcode|huisnummer|toevoeging, melding }
///   200 { gevonden:true, adressen:[...] }
///   200 { gevonden:false, reden: nietgevonden|toevoeging|dienst, melding, adressen? }
function zoekAdres(env, invoer) {
  var postcode = normaliseerPostcode(invoer.postcode);
  if (!postcode) return ongeldig("postcode", MELDING.postcode);
  var huisnummer = normaliseerHuisnummer(invoer.huisnummer);
  if (!huisnummer) return ongeldig("huisnummer", MELDING.huisnummer);
  var toevoeging = normaliseerToevoeging(invoer.toevoeging);
  if (toevoeging === null) return ongeldig("toevoeging", MELDING.toevoegingVorm);

  var uit = zoek(env, postcode, huisnummer);
  if (!uit.ok) return { status: 200, body: { gevonden: false, reden: "dienst", melding: MELDING.dienst } };
  if (uit.adressen.length === 0) {
    return { status: 200, body: { gevonden: false, reden: "nietgevonden", melding: MELDING.nietgevonden } };
  }
  var passend = filterToevoeging(uit.adressen, toevoeging);
  if (passend.length === 0) {
    return {
      status: 200,
      body: {
        gevonden: false,
        reden: "toevoeging",
        melding: MELDING.toevoeging,
        adressen: uit.adressen.map(function (a) {
          return voorAntwoord(env, a);
        }),
      },
    };
  }
  return {
    status: 200,
    body: {
      gevonden: true,
      adressen: passend.map(function (a) {
        return voorAntwoord(env, a);
      }),
    },
  };
}

// ---------------------------------------------------------------- rate-limit

/// 0 = geen grens.
function limietVoor(wie) {
  if (wie === "coordinator" || wie === "superuser") return 0;
  return wie === "gebruiker" ? MAX_INGELOGD_PER_UUR : MAX_ANONIEM_PER_UUR;
}

/// Telt dit verzoek mee; false = boven [max] dit uur. Zoals B3: per uur een
/// eigen teller in $app.store (een herstart zet hem terug).
function magZoeken(env, ip, max) {
  if (!max) return true;
  var sleutel = LIMIET_SLEUTEL + String(ip || "onbekend") + ":" + Math.floor(env.nu() / 3600000);
  var aantal = Number(env.store.get(sleutel) || 0);
  if (aantal >= max) return false;
  env.store.set(sleutel, aantal + 1);
  return true;
}

// ---------------------------------------------------------------- hh_users

function weiger(reden) {
  return { actie: "weiger", reden: reden, melding: MELDING[reden] };
}

/// Wat moet de hh_users-hook met het adres? [g]:
///   wie         anoniem | gebruiker | coordinator | superuser
///   rol         rol van het account
///   nieuw       aanmaken (true) of bijwerken
///   aangeraakt  bij bijwerken: een van ADRESVELDEN is anders
///   servervelden  lat/lon/adres_bron zit in het verzoek
///   adresBron   wat er in adres_bron gestuurd is ("handmatig" = uitzondering)
///   postcode, huisnummer, toevoeging  zoals ze nu op het record staan
/// Uitkomst { actie }:
///   niets      niets met het adres doen
///   weiger     400 { reden, melding }
///   pdok       { adres }: straat, plaats, punt enz. van PDOK zetten
///   terugval   PDOK onbereikbaar: aanmelden gaat door (ongecontroleerd)
///              met { postcode, huisnummer, toevoeging } netjes
///   handmatig  coordinator/superuser: uitzondering zonder PDOK
///   oud        superuser zonder (vindbaar) adres: de B2-weg (Nominatim)
function beoordeel(env, g) {
  var beheer = g.wie === "coordinator" || g.wie === "superuser";
  if (g.servervelden && !beheer) return weiger("servervelden");
  if (beheer && String(g.adresBron || "") === "handmatig") return { actie: "handmatig" };
  if (!g.nieuw && !g.aangeraakt) return { actie: "niets" };

  var streng = ROLLEN_MET_ADRES.indexOf(String(g.rol || "")) >= 0 && g.wie !== "superuser";
  var ruwPostcode = String(g.postcode || "").trim();
  var ruwNummer = String(g.huisnummer || "").trim();
  var ruwToev = String(g.toevoeging || "").trim();
  if (!streng) {
    // Superuser (seed, scripts), familie, coordinator-accounts: geen eis.
    if (g.wie !== "superuser" || !ruwPostcode) return { actie: "niets" };
  }
  if (streng && !ruwPostcode && !ruwNummer) return weiger("verplicht");

  // Oude app: "12a" in het huisnummer en geen toevoeging.
  if (!ruwToev && ruwNummer) {
    var delen = splitsHuisnummer(ruwNummer);
    if (delen) {
      ruwNummer = delen.huisnummer;
      ruwToev = delen.toevoeging;
    }
  }
  var postcode = normaliseerPostcode(ruwPostcode);
  var huisnummer = normaliseerHuisnummer(ruwNummer);
  var toevoeging = normaliseerToevoeging(ruwToev);
  if (!streng) {
    if (!postcode || !huisnummer || toevoeging === null) return { actie: "oud" };
  } else {
    if (!postcode) return weiger("postcode");
    if (!huisnummer) return weiger("huisnummer");
    if (toevoeging === null) {
      var w = weiger("toevoeging");
      w.melding = MELDING.toevoegingVorm;
      return w;
    }
  }

  var uit = zoek(env, postcode, huisnummer);
  if (!uit.ok) {
    if (!streng) return { actie: "oud" };
    return { actie: "terugval", postcode: postcode, huisnummer: huisnummer, toevoeging: toevoeging };
  }
  var keuze = kies(uit.adressen, toevoeging);
  if (keuze.adres) return { actie: "pdok", adres: keuze.adres };
  return streng ? weiger(keuze.reden) : { actie: "oud" };
}

/// Precies één adres uit de lijst, of { reden }.
function kies(adressen, toevoeging) {
  if (adressen.length === 0) return { reden: "nietgevonden" };
  if (toevoeging) {
    var passend = filterToevoeging(adressen, toevoeging);
    return passend.length ? { adres: passend[0] } : { reden: "toevoeging" };
  }
  var kaal = adressen.filter(function (a) {
    return !a.toevoeging;
  });
  if (kaal.length) return { adres: kaal[0] };
  return adressen.length === 1 ? { adres: adressen[0] } : { reden: "kiestoevoeging" };
}

/// Wie doet het verzoek? [auth] = e.auth (of null).
function wieIs(auth) {
  if (!auth) return "anoniem";
  var collectie = String(auth.collection().name || "");
  if (collectie === "_superusers") return "superuser";
  if (collectie === "hh_users" && String(auth.get("rol") || "") === "coordinator") return "coordinator";
  return "gebruiker";
}

/// Zit lat, lon of adres_bron in de body (ook leeg = meegestuurd)?
function serverveldenGestuurd(body) {
  if (!body) return false;
  for (var i = 0; i < SERVERVELDEN.length; i++) {
    if (body[SERVERVELDEN[i]] !== undefined) return true;
  }
  return false;
}

/// Is een van de adresvelden anders dan wat er stond?
function isAdresAangeraakt(record, origineel) {
  for (var i = 0; i < ADRESVELDEN.length; i++) {
    var v = ADRESVELDEN[i];
    if (String(record.get(v) || "") !== String(origineel.get(v) || "")) return true;
  }
  return false;
}

/// Het hele adres van PDOK op het record: vrije invoer van straat/plaats
/// wordt overschreven.
function zetPdokAdres(record, a) {
  record.set("adres", a.adres);
  record.set("plaats", a.plaats);
  record.set("postcode", a.postcode);
  record.set("huisnummer", a.huisnummer);
  record.set("toevoeging", a.toevoeging);
  record.set("lat", a.lat);
  record.set("lon", a.lon);
  record.set("adres_bron", "pdok");
}

/// PDOK onbereikbaar: wat er is, netjes; geen punt; de meldkamer (en 121)
/// ziet "ongecontroleerd".
function zetOngecontroleerd(record, n) {
  record.set("postcode", n.postcode);
  record.set("huisnummer", n.huisnummer);
  record.set("toevoeging", n.toevoeging);
  record.set("lat", 0);
  record.set("lon", 0);
  record.set("adres_bron", "ongecontroleerd");
}

// ---------------------------------------------------------------- klussen

function vergelijkSleutel(tekst) {
  return String(tekst == null ? "" : tekst).toLowerCase().replace(/[\s,]+/g, "");
}

/// Ligt de klus op het adres van de bewoner, en is dat adres door PDOK
/// bevestigd (met punt)? Dan zijn punt; anders null (dan Nominatim zoals M5).
/// [bewoner] = { adres, postcode, plaats, lat, lon, adres_bron }.
function puntVoorKlus(klusAdres, bewoner) {
  if (!bewoner || String(bewoner.adres_bron || "") !== "pdok") return null;
  var lat = Number(bewoner.lat || 0);
  var lon = Number(bewoner.lon || 0);
  if (!lat || !lon || !isFinite(lat) || !isFinite(lon)) return null;
  var klus = vergelijkSleutel(klusAdres);
  if (!klus) return null;
  var straat = String(bewoner.adres || "");
  var varianten = [
    straat + ", " + bewoner.postcode + " " + bewoner.plaats,
    straat,
    straat + ", " + bewoner.plaats,
    straat + " " + bewoner.plaats,
  ];
  for (var i = 0; i < varianten.length; i++) {
    if (vergelijkSleutel(varianten[i]) === klus) return { lat: lat, lon: lon };
  }
  return null;
}

// ---------------------------------------------------------------- vaag vóór de match
// Antwoord Ibrahim (4 okt, vraag 3): een helper ziet een klus VÓÓR de match
// vaag: het punt ~200 m verschoven (stabiel per klus, afgeleid van het
// klus-id), de afstand wel van het echte punt maar afgerond op 100 m. Het
// exacte punt en het adres pas na de match. De server doet dit (hh_klussen.pb.js,
// onRecordEnrich), de app niet.

var VAAG_METER = 200;
var AFSTAND_STAP_METER = 100;
/// Velden waarop een helper niet mag filteren of sorteren (anders kan hij
/// het echte punt of adres "raden" met een reeks filters).
var LOCATIE_VELDEN = ["lat", "lon", "adres", "postcode", "huisnummer", "toevoeging"];

/// FNV-1a (32 bit), alleen met verschuivingen: in de JSVM even exact als in node.
function hash32(tekst) {
  var h = 0x811c9dc5;
  var t = String(tekst);
  for (var i = 0; i < t.length; i++) {
    h ^= t.charCodeAt(i) & 0xff;
    h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) >>> 0;
  }
  return h >>> 0;
}

function heeftPunt(p) {
  return !!p && isFinite(Number(p.lat)) && isFinite(Number(p.lon)) && (Number(p.lat) !== 0 || Number(p.lon) !== 0);
}

/// Het echte punt [punt] VAAG_METER verschoven in een richting die alleen van
/// het klus-id (en eventueel een geheim [zout] uit de omgeving) afhangt. null
/// zonder punt.
function vaagPunt(klusId, punt, zout) {
  if (!heeftPunt(punt)) return null;
  var hoek = ((hash32(String(zout || "") + ":" + String(klusId)) % 3600) / 10) * (Math.PI / 180);
  var lat = Number(punt.lat);
  var lon = Number(punt.lon);
  var dLat = (VAAG_METER * Math.cos(hoek)) / 111320;
  var dLon = (VAAG_METER * Math.sin(hoek)) / (111320 * Math.cos((lat * Math.PI) / 180));
  return { lat: Math.round((lat + dLat) * 1e6) / 1e6, lon: Math.round((lon + dLon) * 1e6) / 1e6 };
}

/// Afstand in meters tussen twee echte punten, afgerond op 100 m (minstens
/// 100). null als een van de twee geen punt heeft.
function afstandAfgerond(a, b) {
  if (!heeftPunt(a) || !heeftPunt(b)) return null;
  var r = 6371000;
  var rad = Math.PI / 180;
  var dLat = (b.lat - a.lat) * rad;
  var dLon = (b.lon - a.lon) * rad;
  var h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  var meter = 2 * r * Math.asin(Math.min(1, Math.sqrt(h)));
  return Math.max(AFSTAND_STAP_METER, Math.round(meter / AFSTAND_STAP_METER) * AFSTAND_STAP_METER);
}

/// Ziet deze kijker de klus "vóór de match"? Alleen een helper (rol jongere)
/// die niet de toegewezen helper is. [kijker] = { id, collectie, rol } of null.
function isVoorDeMatch(kijker, toegewezenJongere) {
  if (!kijker || kijker.collectie !== "hh_users" || kijker.rol !== "jongere") return false;
  return String(toegewezenJongere || "") !== String(kijker.id);
}

/// Noemt een filter of sort een locatieveld (ook via een relatie, zoals
/// hulpvrager.postcode of klus.lat)?
function zoektOpLocatie(filter, sort) {
  var tekst = String(filter || "") + " " + String(sort || "");
  var re = new RegExp("(^|[^A-Za-z0-9_])(" + LOCATIE_VELDEN.join("|") + ")(?![A-Za-z0-9_])");
  return re.test(tekst);
}

module.exports = {
  VAAG_METER: VAAG_METER,
  vaagPunt: vaagPunt,
  afstandAfgerond: afstandAfgerond,
  isVoorDeMatch: isVoorDeMatch,
  zoektOpLocatie: zoektOpLocatie,
  PDOK_URL: PDOK_URL,
  CACHE_MS: CACHE_MS,
  MAX_ANONIEM_PER_UUR: MAX_ANONIEM_PER_UUR,
  MAX_INGELOGD_PER_UUR: MAX_INGELOGD_PER_UUR,
  SERVERVELDEN: SERVERVELDEN,
  ADRESVELDEN: ADRESVELDEN,
  MELDING: MELDING,
  normaliseerPostcode: normaliseerPostcode,
  normaliseerHuisnummer: normaliseerHuisnummer,
  normaliseerToevoeging: normaliseerToevoeging,
  splitsHuisnummer: splitsHuisnummer,
  pdokUrl: pdokUrl,
  leesAdres: leesAdres,
  leesAntwoord: leesAntwoord,
  zoek: zoek,
  zoekAdres: zoekAdres,
  limietVoor: limietVoor,
  magZoeken: magZoeken,
  beoordeel: beoordeel,
  puntVoorKlus: puntVoorKlus,
  wieIs: wieIs,
  serverveldenGestuurd: serverveldenGestuurd,
  isAdresAangeraakt: isAdresAangeraakt,
  zetPdokAdres: zetPdokAdres,
  zetOngecontroleerd: zetOngecontroleerd,
};

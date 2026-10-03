// HeitjeHulp B6 — hh_chat_hulp.js (hulpbestand, GEEN hook)
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. De
// handlers in hh_chat.pb.js halen dit bestand BINNEN de handler op met
//   const hulp = require(`${__hooks}/hh_chat_hulp.js`);
// (de pool-runtime deelt geen scope tussen handlers).
//
// Twee soorten functies:
//   - PUUR (geen $app): het filter (nummers, mail, links -> "•••"), de
//     markering contactverzoek, wanneer de chat open of dicht is, wie de
//     ontvanger is en de tekst van de melding. Getest zonder server:
//     backend/tests/hh_chat_hulp.test.mjs.
//   - MET app: het sluitmoment uit hh_klus_status lezen en de melding bij
//     een nieuw bericht maken. De aanroeper geeft { app: $app, Record }
//     mee, zodat dit bestand niet op de globals van de JSVM leunt.
//
// Geen lookbehind, geen u-vlag en geen benoemde groepen in de reguliere
// expressies: de JSVM (goja) kent ze niet allemaal.
//
// DEPLOY: samen met hh_chat.pb.js (scripts/113-hook-deploy.sh).

// --------------------------------------------------------------------------
// CONSTANTEN (uitleg in SCHEMA.txt, sectie B6)
// --------------------------------------------------------------------------

/// Na afgerond of geannuleerd blijft de chat nog zo lang open om te
/// schrijven (vergeten spullen, een bedankje). Daarna alleen lezen.
const CHAT_DICHT_NA_UREN = 72;

/// Hooguit één melding per chat per ontvanger binnen dit aantal minuten:
/// tien berichten achter elkaar geven één melding, geen tien.
const MELDING_INTERVAL_MINUTEN = 10;

/// Gelijk aan de max van hh_berichten.tekst (script 110).
const MAX_TEKST = 500;

/// Wat er overblijft van een nummer, mailadres of link.
const VERVANGING = "•••";

/// Statussen waarin de klus een helper heeft en loopt: chat open.
const STATUS_LOOPT = ["geaccepteerd", "onderweg", "bezig", "probleem"];

/// Statussen na afloop: chat nog CHAT_DICHT_NA_UREN open, daarna dicht.
const STATUS_AFGELOPEN = ["afgerond", "geannuleerd"];

const MELDING_DICHT = "Deze chat is gesloten.";

// --------------------------------------------------------------------------
// INTEGRATIE (antwoorden Ibrahim 4 okt): gesprek verwijderen en AVG
// --------------------------------------------------------------------------

/// Wat een gewist bericht wordt (account verwijderd): tekst leeg + markering;
/// de app toont "Bericht verwijderd". Geen filter-sporen meer.
const GEWIST = { tekst: "", gewist: true, gefilterd: false, contactverzoek: false, wissen_na_incident: false };

const MELDING_INCIDENT =
  "Er loopt een melding over deze klus. Je kunt het gesprek verwijderen zodra de meldkamer die heeft afgehandeld.";
const MELDING_GEEN_DEELNEMER = "Dit gesprek is niet van jou.";
const MELDING_LEEG = "Typ eerst een bericht.";

// --------------------------------------------------------------------------
// PUUR: filter
// --------------------------------------------------------------------------

// Een cijferreeks: cijfers met hooguit twee scheidingstekens ertussen
// (spatie, streepje, punt, slash, haakjes), eventueel met + of ( vooraan.
const CIJFERREEKS = /[+(]?\d(?:[ \t\-.\/()]{0,2}\d)*/g;

// Een datum (met tijd) is geen telefoonnummer: 12-10-2026 of 12-10-2026 14.30.
const DATUM = /^\d{1,2}[-\/.]\d{1,2}[-\/.](?:\d{4}|\d{2})(?:[ ]{1,2}\d{1,2}[.]\d{2})?$/;

/// Vanaf zoveel cijfers is een reeks een telefoonnummer (06 + 8 = 10,
/// een vast nummer 10, gesplitst ontwijken "6 1234 5678" = 9).
const MIN_CIJFERS_NUMMER = 9;

const TLD_MAIL = "nl|com|net|org|be|eu|de|fr|uk|io|me|info|live|nu";
// Zonder "de", "nu" en "to": "Ik ben er.De poort" is geen link.
const TLD_LINK = "nl|com|net|org|be|eu|io|me|app|info|ly|gg|tv|co|uk|fr|link|site|online|shop|xyz|chat";

const AT = "(?:\\s*@\\s*|\\s*[(\\[{]\\s*at\\s*[)\\]}]\\s*|\\s+at\\s+)";
const PUNT = "(?:\\s*\\.\\s*|\\s*[(\\[{]\\s*(?:dot|punt)\\s*[)\\]}]\\s*|\\s+(?:dot|punt)\\s+)";

const MAIL_ECHT = /[a-z0-9._%+\-]+\s*@\s*[a-z0-9\-]+(?:\.[a-z0-9\-]+)*\.[a-z]{2,}/gi;
const MAIL_VERSTOPT = new RegExp(
  "[a-z0-9._%+\\-]+" + AT + "[a-z0-9\\-]+(?:" + PUNT + "[a-z0-9\\-]+)*" + PUNT + "(?:" + TLD_MAIL + ")\\b",
  "gi"
);
const URL_ECHT = /(?:https?:\/\/|www\.)[^\s]+/gi;
const DOMEIN = new RegExp(
  "\\b[a-z0-9][a-z0-9\\-]*(?:\\.[a-z0-9\\-]+)*\\.(?:" + TLD_LINK + ")\\b(?:\\/[^\\s]*)?",
  "gi"
);

/// Woorden die op "laten we buiten de app verder praten" wijzen. Getoetst op
/// de genormaliseerde tekst (kleine letters, alles wat geen letter of cijfer
/// is wordt een spatie). Alleen MARKEREN, nooit blokkeren.
const VERZOEK_WOORDEN = [
  /\b(?:whats ?app|whatsap|wats ?app|watsap|wazzap|wapp)\b/,
  /\bapp (?:me|mij|ons)\b/,
  /\bapp je (?:me|mij)\b/,
  /\b(?:appen|appje)\b/,
  /\bsnap ?chat\b/,
  /\b(?:op|mijn|je|jouw|via) snap\b/,
  /\bsnap (?:me|mij)\b/,
  /\b(?:insta|instagram|insta gram)\b/,
  /\btik ?tok\b/,
  /\b(?:telegram|signal|discord|facebook|messenger)\b/,
  /\b(?:mijn|je|jouw|uw|jullie) (?:telefoon ?)?(?:nummer|nr)\b/,
  /\btelefoon ?(?:nummer|nr)\b/,
  /\b06 ?(?:nummer|nr)\b/,
  /\b(?:e ?mail|email|e ?mailadres|mailadres|mailen)\b/,
  /\bmail (?:me|mij)\b/,
];

/// Ontwijken met spaties of punten tussen de letters ("w h a t s a p p"):
/// gezocht in de tekst met alleen letters.
const VERZOEK_AANEEN = ["whatsapp", "watsapp", "snapchat", "instagram", "telegram", "tiktok"];

function normaal(tekst) {
  return " " + String(tekst || "").toLowerCase().replace(/[^a-z0-9]+/g, " ") + " ";
}

/// Wijst de tekst op een verzoek om buiten de app contact te hebben?
function isContactverzoek(tekst) {
  const n = normaal(tekst);
  for (let i = 0; i < VERZOEK_WOORDEN.length; i++) {
    if (VERZOEK_WOORDEN[i].test(n)) return true;
  }
  const aaneen = n.replace(/[^a-z]/g, "");
  for (let i = 0; i < VERZOEK_AANEEN.length; i++) {
    if (aaneen.indexOf(VERZOEK_AANEEN[i]) !== -1) return true;
  }
  return false;
}

function telCijfers(reeks) {
  const m = reeks.match(/\d/g);
  return m ? m.length : 0;
}

/// Vervangt telefoonnummers, e-mailadressen en links door VERVANGING.
/// Geeft { tekst, gefilterd, contactverzoek }; de markering contactverzoek
/// kijkt naar de ORIGINELE tekst. Gooit nooit.
function filterTekst(invoer) {
  const origineel = String(invoer == null ? "" : invoer).trim();
  let gefilterd = false;
  const vervang = (patroon, tekst, alleenAls) =>
    tekst.replace(patroon, (stuk) => {
      if (alleenAls && !alleenAls(stuk)) return stuk;
      gefilterd = true;
      return VERVANGING;
    });

  let tekst = origineel;
  tekst = vervang(MAIL_ECHT, tekst);
  tekst = vervang(MAIL_VERSTOPT, tekst);
  tekst = vervang(URL_ECHT, tekst);
  tekst = vervang(DOMEIN, tekst);
  tekst = vervang(CIJFERREEKS, tekst, (stuk) => {
    const kaal = stuk.replace(/^[(]/, "");
    return telCijfers(stuk) >= MIN_CIJFERS_NUMMER && !DATUM.test(kaal);
  });

  return {
    tekst: tekst,
    gefilterd: gefilterd,
    contactverzoek: origineel ? isContactverzoek(origineel) : false,
  };
}

// --------------------------------------------------------------------------
// PUUR: open of dicht, ontvanger, melding
// --------------------------------------------------------------------------

/// "2026-10-04 12:00:00.000Z" (PocketBase) -> ms sinds 1970, of NaN.
function momentVan(waarde) {
  const tekst = String(waarde || "").trim();
  if (!tekst) return NaN;
  return Date.parse(tekst.replace(" ", "T"));
}

/// ms -> "2026-10-04 12:00:00.000Z" (voor een PocketBase-filter).
function pbDatum(ms) {
  return new Date(ms).toISOString().replace("T", " ");
}

/// De stand van de chat bij een klus:
///   "open"        schrijven mag
///   "dicht"       afgerond/geannuleerd en langer dan CHAT_DICHT_NA_UREN
///                 geleden (of onbekend wanneer: liever dicht dan open)
///   "geenhelper"  er is (nog) geen helper, of de klus staat op concept/open
/// [sluitMoment] = ms van de stap naar afgerond/geannuleerd.
function chatStand(status, helperId, sluitMoment, nu) {
  if (!helperId) return "geenhelper";
  if (STATUS_LOOPT.indexOf(status) !== -1) return "open";
  if (STATUS_AFGELOPEN.indexOf(status) !== -1) {
    const sinds = Number(sluitMoment);
    if (sluitMoment == null || !isFinite(sinds)) return "dicht";
    return nu - sinds <= CHAT_DICHT_NA_UREN * 3600 * 1000 ? "open" : "dicht";
  }
  return "geenhelper";
}

/// Wie krijgt een melding van dit bericht? De andere deelnemer van DEZE chat.
/// Hoort het bericht bij een vorige helper (helperVanBericht is niet meer de
/// toegewezen helper), dan niemand.
function ontvangerVan(afzender, helperVanBericht, klus) {
  const bewoner = String(klus.hulpvrager || "");
  const helper = String(klus.toegewezen_jongere || "");
  if (!helper || helperVanBericht !== helper) return "";
  if (afzender === bewoner) return helper;
  if (afzender === helper) return bewoner;
  return "";
}

function magMelden(laatsteMelding, nu) {
  const laatste = Number(laatsteMelding);
  if (laatsteMelding == null || !isFinite(laatste)) return true;
  return nu - laatste >= MELDING_INTERVAL_MINUTEN * 60 * 1000;
}

function voornaam(naam) {
  const delen = String(naam || "").trim().split(/\s+/);
  return delen[0] || "";
}

function metHoofdletter(tekst) {
  const t = String(tekst || "").trim();
  return t ? t.charAt(0).toUpperCase() + t.slice(1) : "";
}

/// Titel en tekst van de melding. Nooit de inhoud van het bericht (die kan
/// later op een vergrendelscherm staan, laag 2).
function meldingTekst(afzenderNaam, klussoort) {
  const wie = voornaam(afzenderNaam);
  const klus = metHoofdletter(klussoort);
  return {
    titel: wie ? `Nieuw bericht van ${wie}` : "Nieuw bericht",
    tekst: klus ? `Over je klus: ${klus}. Open de chat om te lezen.` : "Open de chat om te lezen.",
  };
}

/// Wie ben ik in het gesprek van deze klus? "bewoner", "helper" (alleen de
/// HUIDIGE helper; een vorige helper leest al niets meer) of "".
function rolInGesprek(ik, klus) {
  const id = String(ik || "");
  if (!id) return "";
  if (id === String(klus.hulpvrager || "")) return "bewoner";
  if (id === String(klus.toegewezen_jongere || "")) return "helper";
  return "";
}

/// Het veld dat het gesprek voor deze kant verbergt.
function verbergVeld(rol) {
  if (rol === "bewoner") return "verborgen_bewoner";
  if (rol === "helper") return "verborgen_helper";
  return "";
}

// --------------------------------------------------------------------------
// MET app
// --------------------------------------------------------------------------

function zoekId(app, collectie, id) {
  if (!id) return null;
  try {
    return app.findRecordById(collectie, id);
  } catch (_) {
    return null;
  }
}

function eersteVan(app, collectie, filter, sort, params) {
  try {
    const rijen = app.findRecordsByFilter(collectie, filter, sort, 1, 0, params);
    return rijen.length ? rijen[0] : null;
  } catch (_) {
    return null;
  }
}

/// Wanneer kwam de klus op zijn huidige (afgelopen) status? Uit de laatste
/// logregel in hh_klus_status; zonder logregel (oude data) "updated".
function sluitMomentVan(app, klus) {
  const status = String(klus.get("status") || "");
  const regel = eersteVan(app, "hh_klus_status", "klus = {:klus} && naar = {:naar}", "-created", {
    klus: klus.id,
    naar: status,
  });
  if (regel) return momentVan(String(regel.get("created")));
  return momentVan(String(klus.get("updated")));
}

/// chatStand voor een hh_klussen-record.
function standVoorKlus(app, klus, nu) {
  const status = String(klus.get("status") || "");
  const helper = String(klus.get("toegewezen_jongere") || "");
  const sluit = STATUS_AFGELOPEN.indexOf(status) !== -1 ? sluitMomentVan(app, klus) : NaN;
  return chatStand(status, helper, sluit, nu);
}

/// Een melding (soort "bericht") voor de ontvanger van een nieuw bericht,
/// hooguit één per MELDING_INTERVAL_MINUTEN per chat. Idempotent op
/// (ontvanger, soort, sleutel) met sleutel "bericht:<id>". Geeft true als
/// er een melding is gemaakt.
function verwerkNieuwBericht(env, bericht, nu) {
  const app = env.app;
  const klus = zoekId(app, "hh_klussen", String(bericht.get("klus") || ""));
  if (!klus) return false;
  const ontvanger = ontvangerVan(
    String(bericht.get("afzender") || ""),
    String(bericht.get("helper") || ""),
    { hulpvrager: klus.get("hulpvrager"), toegewezen_jongere: klus.get("toegewezen_jongere") }
  );
  if (!ontvanger) return false;

  const vorige = eersteVan(app, "hh_meldingen", "ontvanger = {:o} && soort = 'bericht' && klus = {:k}", "-created", {
    o: ontvanger,
    k: klus.id,
  });
  if (vorige && !magMelden(momentVan(String(vorige.get("created"))), nu)) return false;

  const sleutel = "bericht:" + bericht.id;
  if (eersteVan(app, "hh_meldingen", "ontvanger = {:o} && soort = 'bericht' && sleutel = {:s}", "", { o: ontvanger, s: sleutel })) {
    return false;
  }
  const afzender = zoekId(app, "hh_users", String(bericht.get("afzender") || ""));
  const type = zoekId(app, "hh_klustypes", String(klus.get("klustype") || ""));
  const t = meldingTekst(afzender ? afzender.get("naam") : "", type ? type.get("naam") : "");

  const record = new env.Record(app.findCollectionByNameOrId("hh_meldingen"));
  record.set("ontvanger", ontvanger);
  record.set("soort", "bericht");
  record.set("klus", klus.id);
  record.set("titel", t.titel);
  record.set("tekst", t.tekst);
  record.set("sleutel", sleutel);
  app.save(record);
  return true;
}

/// Loopt er een incident (zonder afhandeling) op deze klus?
function heeftOpenIncident(app, klusId) {
  if (!klusId) return false;
  const rijen = app.findRecordsByFilter("hh_incidenten", "klus = {:klus} && afhandeling = ''", "", 1, 0, { klus: klusId });
  return rijen.length > 0;
}

/// "Gesprek verwijderen": verbergt het gesprek ALLEEN voor mij (de ander
/// houdt zijn kopie). Bewoner: alle berichten van de klus; helper: de
/// berichten van zijn gesprek. Een nieuw bericht daarna is weer zichtbaar.
/// Loopt er een incident, dan niets (409): de meldkamer moet alles kunnen
/// lezen tot ze het afhandelt. Geeft { status, body } voor de route.
function verbergGesprek(app, klus, ik) {
  const rol = rolInGesprek(ik, { hulpvrager: klus.get("hulpvrager"), toegewezen_jongere: klus.get("toegewezen_jongere") });
  const veld = verbergVeld(rol);
  if (!veld) return { status: 403, body: { melding: MELDING_GEEN_DEELNEMER, reden: "geendeelnemer" } };
  if (heeftOpenIncident(app, klus.id)) return { status: 409, body: { melding: MELDING_INCIDENT, reden: "incident" } };
  const rijen =
    rol === "bewoner"
      ? app.findRecordsByFilter("hh_berichten", "klus = {:klus}", "", 0, 0, { klus: klus.id })
      : app.findRecordsByFilter("hh_berichten", "klus = {:klus} && helper = {:helper}", "", 0, 0, { klus: klus.id, helper: ik });
  let aantal = 0;
  for (let i = 0; i < rijen.length; i++) {
    if (rijen[i].get(veld) === true) continue;
    rijen[i].set(veld, true);
    app.save(rijen[i]);
    aantal++;
  }
  return { status: 200, body: { verborgen: aantal } };
}

/// De ids van alle berichten die [afzender] schreef (vóór het verwijderen
/// van het account: daarna maakt PocketBase de relatie leeg).
function berichtenVan(app, afzender) {
  if (!afzender) return [];
  const rijen = app.findRecordsByFilter("hh_berichten", "afzender = {:afzender}", "", 0, 0, { afzender: afzender });
  const uit = [];
  for (let i = 0; i < rijen.length; i++) uit.push(rijen[i].id);
  return uit;
}

function zetGewist(record) {
  const velden = Object.keys(GEWIST);
  for (let i = 0; i < velden.length; i++) record.set(velden[i], GEWIST[velden[i]]);
}

/// Na het verwijderen van een account: zijn berichten gewist (tekst leeg +
/// markering). Loopt er een incident op die klus, dan UITGESTELD
/// (wissen_na_incident = ja; tekst blijft voor de meldkamer) tot het
/// incident is afgehandeld (wisNaIncident). Geeft { gewist, uitgesteld }.
function wisBerichten(app, ids) {
  const uit = { gewist: 0, uitgesteld: 0 };
  const incident = {};
  for (let i = 0; i < ids.length; i++) {
    const r = zoekId(app, "hh_berichten", ids[i]);
    if (!r) continue;
    const klusId = String(r.get("klus") || "");
    if (!(klusId in incident)) incident[klusId] = heeftOpenIncident(app, klusId);
    if (incident[klusId]) {
      if (r.get("wissen_na_incident") !== true) {
        r.set("wissen_na_incident", true);
        app.save(r);
      }
      uit.uitgesteld++;
    } else {
      zetGewist(r);
      app.save(r);
      uit.gewist++;
    }
  }
  return uit;
}

/// Een incident is afgehandeld (of weg): uitgestelde berichten nu wissen,
/// maar alleen als er op die klus geen ander open incident meer is.
function wisNaIncident(app, klusId) {
  if (!klusId || heeftOpenIncident(app, klusId)) return 0;
  const rijen = app.findRecordsByFilter("hh_berichten", "klus = {:klus} && wissen_na_incident = true", "", 0, 0, { klus: klusId });
  for (let i = 0; i < rijen.length; i++) {
    zetGewist(rijen[i]);
    app.save(rijen[i]);
  }
  return rijen.length;
}

module.exports = {
  GEWIST: GEWIST,
  MELDING_INCIDENT: MELDING_INCIDENT,
  MELDING_GEEN_DEELNEMER: MELDING_GEEN_DEELNEMER,
  MELDING_LEEG: MELDING_LEEG,
  rolInGesprek: rolInGesprek,
  verbergVeld: verbergVeld,
  heeftOpenIncident: heeftOpenIncident,
  verbergGesprek: verbergGesprek,
  berichtenVan: berichtenVan,
  wisBerichten: wisBerichten,
  wisNaIncident: wisNaIncident,
  CHAT_DICHT_NA_UREN: CHAT_DICHT_NA_UREN,
  MELDING_INTERVAL_MINUTEN: MELDING_INTERVAL_MINUTEN,
  MAX_TEKST: MAX_TEKST,
  VERVANGING: VERVANGING,
  STATUS_LOOPT: STATUS_LOOPT,
  STATUS_AFGELOPEN: STATUS_AFGELOPEN,
  MELDING_DICHT: MELDING_DICHT,
  filterTekst: filterTekst,
  isContactverzoek: isContactverzoek,
  momentVan: momentVan,
  pbDatum: pbDatum,
  chatStand: chatStand,
  ontvangerVan: ontvangerVan,
  magMelden: magMelden,
  meldingTekst: meldingTekst,
  sluitMomentVan: sluitMomentVan,
  standVoorKlus: standVoorKlus,
  verwerkNieuwBericht: verwerkNieuwBericht,
};

// HeitjeHulp B6 — hh_chat.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// De chat tussen bewoner en helper per klus (collectie hh_berichten, scripts
// 110 en 111). Het rekenwerk staat in hh_chat_hulp.js (getest zonder server:
// backend/tests/hh_chat_hulp.test.mjs). Raakt alleen hh_berichten; maakt
// meldingen in hh_meldingen. hh_klussen.pb.js (B4) blijft ongemoeid.
//
// 1. AANMAKEN (onRecordCreateRequest, VOOR het opslaan en vóór de rule)
//    a. Filter: telefoonnummers (06..., +31..., met spaties/streepjes),
//       e-mailadressen en links worden "•••"; dan gefilterd = true (de
//       markering voor de meldkamer). Het origineel wordt NIET bewaard.
//    b. Markering contactverzoek ("heb je whatsapp/snap/insta, je nummer?"):
//       alleen markeren, nooit blokkeren.
//    c. helper = klus.toegewezen_jongere: het gesprek hoort bij deze helper.
//    d. Chat dicht? Na afgerond/geannuleerd mag een deelnemer nog 72 uur
//       schrijven (CHAT_DICHT_NA_UREN; het moment komt uit hh_klus_status).
//       Daarna 403 "Deze chat is gesloten." {reden: "dicht"}. Een vreemde
//       krijgt hier niets te horen; die houdt de rule tegen (400).
//    Ook een superuser gaat door het filter; alleen de dicht-check slaat hij
//    over (herstelwerk).
//
// 2. NA AANMAKEN (onRecordAfterCreateSuccess): een melding (soort "bericht")
//    voor de andere deelnemer, hooguit één per 10 minuten per chat. Een fout
//    hier breekt het bericht nooit (e.next() eerst, de rest in try/catch).
//
// 3. BIJWERKEN (onRecordUpdateRequest): alleen gelezen_op mag veranderen; de
//    rule (111) weigert elk ander veld al, dit zet ze voor de zekerheid terug
//    (tweede sluis, zoals hh_meldingen). Superuser: niets terugzetten.
//
// 4. VERRIJKEN (onRecordEnrich, ook realtime): contactverzoek is alleen voor
//    de meldkamer; voor iedereen behalve coordinator en superuser weg.
//    gefilterd blijft zichtbaar (de app zegt "nummer of link verborgen").
//
// 5. INTEGRATIE (antwoorden Ibrahim 4 okt): gesprek verwijderen en AVG
//    a. POST /api/hh/chat/{klus}/verbergen ("Gesprek verwijderen"): zet
//       verborgen_bewoner (bewoner: alle berichten van de klus) of
//       verborgen_helper (huidige helper: zijn gesprek). Alleen voor die
//       kant; de ander houdt zijn kopie, de meldkamer leest bij een incident.
//       Een nieuw bericht daarna is weer zichtbaar. 200 {verborgen: n};
//       403 {reden: "geendeelnemer"}; 404; 409 {reden: "incident"} zolang er
//       een incident zonder afhandeling op de klus loopt (KEUZE: weigeren;
//       de gebruiker kan het na de afhandeling opnieuw doen).
//    b. Account verwijderen (onRecordDeleteRequest op hh_users): de ids van
//       zijn berichten worden VOOR het verwijderen opgehaald; NA een gelukt
//       verwijderen: tekst leeg + gewist (de ander ziet "Bericht
//       verwijderd"). afzender is niet verplicht: PocketBase maakt hem leeg
//       en blokkeert het verwijderen niet meer. Loopt er een incident op die
//       klus: UITGESTELD (wissen_na_incident = ja, tekst blijft voor de
//       meldkamer) - KEUZE: het account gaat wel meteen weg (AVG-recht), alleen
//       het wissen van de tekst wacht.
//    c. Incident afgehandeld (afhandeling ingevuld) of verwijderd: de
//       uitgestelde berichten van die klus worden nu gewist, als er geen
//       ander open incident op de klus meer is.
//    d. Aanmaken zonder tekst (na het filter leeg): 400 "Typ eerst een
//       bericht." (tekst is niet meer verplicht in het schema, voor b).
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app; e.next() op elk pad (een throw is een bewuste weigering).
//
// DEPLOY: scripts/113-hook-deploy.sh (dit bestand + hh_chat_hulp.js, beide
// NIEUW). VOORWAARDE: 110 --apply (hh_berichten, soort "bericht").

onRecordCreateRequest((e) => {
  const hulp = require(`${__hooks}/hh_chat_hulp.js`);

  const uit = hulp.filterTekst(String(e.record.get("tekst") || ""));
  e.record.set("tekst", uit.tekst);
  e.record.set("gefilterd", uit.gefilterd);
  e.record.set("contactverzoek", uit.contactverzoek);
  if (!String(uit.tekst || "").trim()) throw new BadRequestError(hulp.MELDING_LEEG);
  // Tweede sluis naast de rule (111): deze velden zet nooit een gebruiker.
  e.record.set("verborgen_bewoner", false);
  e.record.set("verborgen_helper", false);
  e.record.set("gewist", false);
  e.record.set("wissen_na_incident", false);

  let klus = null;
  try {
    klus = $app.findRecordById("hh_klussen", String(e.record.get("klus") || ""));
  } catch (_) {
    klus = null; // de relatie-check en de rule weigeren dit verder
  }
  if (klus) {
    const helper = String(klus.get("toegewezen_jongere") || "");
    e.record.set("helper", helper);

    const isSuperuser = !!(e.hasSuperuserAuth && e.hasSuperuserAuth());
    const ik = e.auth ? e.auth.id : "";
    const isDeelnemer = !!ik && (ik === String(klus.get("hulpvrager") || "") || ik === helper);
    if (!isSuperuser && isDeelnemer) {
      const stand = hulp.standVoorKlus($app, klus, Date.now());
      if (stand !== "open") {
        throw new ForbiddenError(hulp.MELDING_DICHT, { reden: stand === "dicht" ? "dicht" : "geenhelper" });
      }
    }
  }

  e.next();
}, "hh_berichten");

onRecordAfterCreateSuccess((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_chat_hulp.js`);
    if (hulp.verwerkNieuwBericht({ app: $app, Record: Record }, e.record, Date.now())) {
      console.log(`[hh_chat] melding bij bericht ${e.record.id}`);
    }
  } catch (err) {
    console.log("[hh_chat] melding bij bericht mislukt:", String(err));
  }
}, "hh_berichten");

onRecordUpdateRequest((e) => {
  const VASTE_VELDEN = [
    "klus", "afzender", "helper", "tekst", "soort", "gefilterd", "contactverzoek",
    "verborgen_bewoner", "verborgen_helper", "gewist", "wissen_na_incident",
  ];
  const isSuperuser = !!(e.hasSuperuserAuth && e.hasSuperuserAuth());
  if (!isSuperuser) {
    try {
      const origineel = e.record.original();
      for (let i = 0; i < VASTE_VELDEN.length; i++) {
        e.record.set(VASTE_VELDEN[i], origineel.get(VASTE_VELDEN[i]));
      }
    } catch (err) {
      console.log("[hh_chat] terugzetten van vaste velden mislukt:", String(err));
    }
  }
  e.next();
}, "hh_berichten");

onRecordEnrich((e) => {
  const kijker = e.requestInfo ? e.requestInfo.auth : null;
  let magZien = false;
  if (kijker) {
    const naam = kijker.collection().name;
    magZien = naam === "_superusers" || (naam === "hh_users" && String(kijker.get("rol") || "") === "coordinator");
  }
  if (!magZien) {
    e.record.hide("contactverzoek");
    // Integratie: wie wat verborg en wat nog gewist wordt, is niet voor de ander.
    e.record.hide("verborgen_bewoner", "verborgen_helper", "wissen_na_incident");
  }
  return e.next();
}, "hh_berichten");

// --------------------------------------------------------------------------
// 5a. Gesprek verwijderen (alleen voor mezelf)
// --------------------------------------------------------------------------
routerAdd(
  "POST",
  "/api/hh/chat/{klus}/verbergen",
  (e) => {
    const hulp = require(`${__hooks}/hh_chat_hulp.js`);
    const klusId = String(e.request.pathValue("klus") || "").trim();
    let klus = null;
    try {
      klus = klusId ? $app.findRecordById("hh_klussen", klusId) : null;
    } catch (_) {
      klus = null;
    }
    if (!klus) return e.json(404, { melding: "Deze klus bestaat niet meer.", reden: "nietgevonden" });
    const uit = hulp.verbergGesprek($app, klus, e.auth.id);
    if (uit.status === 200) console.log(`[hh_chat] ${e.auth.id} verborg het gesprek van klus ${klus.id} (${uit.body.verborgen})`);
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// 5b. Account verwijderen: eigen berichten wissen (of uitstellen)
// --------------------------------------------------------------------------
onRecordDeleteRequest((e) => {
  let ids = [];
  try {
    const hulp = require(`${__hooks}/hh_chat_hulp.js`);
    ids = hulp.berichtenVan($app, e.record.id);
  } catch (err) {
    console.log("[hh_chat] berichten van het account ophalen mislukt:", String(err));
    ids = [];
  }

  e.next(); // gooit als het verwijderen mislukt: dan wordt er niets gewist

  if (!ids.length) return;
  try {
    const hulp = require(`${__hooks}/hh_chat_hulp.js`);
    const uit = hulp.wisBerichten($app, ids);
    console.log(`[hh_chat] account ${e.record.id} weg: ${uit.gewist} bericht(en) gewist, ${uit.uitgesteld} uitgesteld (incident)`);
  } catch (err) {
    console.log("[hh_chat] berichten wissen mislukt:", String(err));
  }
}, "hh_users");

// --------------------------------------------------------------------------
// 5c. Incident afgehandeld of weg: uitgestelde berichten nu wissen
// --------------------------------------------------------------------------
onRecordAfterUpdateSuccess((e) => {
  e.next();
  try {
    if (!String(e.record.get("afhandeling") || "").trim()) return;
    const hulp = require(`${__hooks}/hh_chat_hulp.js`);
    const n = hulp.wisNaIncident($app, String(e.record.get("klus") || ""));
    if (n) console.log(`[hh_chat] incident ${e.record.id} afgehandeld: ${n} uitgesteld(e) bericht(en) gewist`);
  } catch (err) {
    console.log("[hh_chat] wissen na incident mislukt:", String(err));
  }
}, "hh_incidenten");

onRecordAfterDeleteSuccess((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_chat_hulp.js`);
    const n = hulp.wisNaIncident($app, String(e.record.get("klus") || ""));
    if (n) console.log(`[hh_chat] incident ${e.record.id} weg: ${n} uitgesteld(e) bericht(en) gewist`);
  } catch (err) {
    console.log("[hh_chat] wissen na incident mislukt:", String(err));
  }
}, "hh_incidenten");

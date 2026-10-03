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
  const VASTE_VELDEN = ["klus", "afzender", "helper", "tekst", "soort", "gefilterd", "contactverzoek"];
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
  if (!magZien) e.record.hide("contactverzoek");
  return e.next();
}, "hh_berichten");

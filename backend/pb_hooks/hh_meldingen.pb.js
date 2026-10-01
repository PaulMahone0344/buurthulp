// HeitjeHulp M8 — hh_meldingen.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Laag 1 van de meldingen: een melding IN de app, als record in hh_meldingen
// (scripts/30 en 31). De app volgt zijn eigen meldingen met realtime. Laag 2
// (echte push naar het toestel) is niet gebouwd; zie app/OPEN-PUNTEN-M8.txt.
//
// Drie handlers, allemaal op eigen collecties; hh_klussen.pb.js (M5/M6) en
// hh_coordinator.pb.js (M10) blijven ongemoeid:
//
// 1. onRecordAfterCreateSuccess op hh_klus_status
//    M6 (en M10) schrijven bij ELKE statuswissel een logregel, ook bij
//    accepteren, koppelen, annuleren en vrijgeven, altijd via $app/txApp.
//    Een request-hook ziet die dus niet; een after-success-hook wel, en pas
//    als de transactie is gelukt. Per logregel:
//      naar geaccepteerd -> oudere (en geplaatst_door als dat iemand anders is)
//      naar onderweg     -> oudere
//      naar afgerond     -> oudere en jongere
//      naar geannuleerd  -> de andere deelnemer
//      terug naar open   -> oudere ("we zoeken iemand anders")
//      naar open         -> goedgekeurde jongeren in de wijk van de oudere
//                           (max 50, niet wie hem net teruggaf)
//
// 2. onRecordAfterCreateSuccess op hh_incidenten
//    Een melding soort incident voor ELKE coordinator; bij soort nood ook
//    voor het gekoppelde familielid van de melder (hh_koppelingen).
//
// 3. onRecordUpdateRequest op hh_meldingen
//    De ontvanger mag alleen gelezen_op zetten. De rule (script 31) weigert
//    al elk ander veld in de body; deze hook zet voor de zekerheid elk ander
//    veld terug op de opgeslagen waarde (tweede sluis, zoals bij ObyCom).
//    Een superuser: niets terugzetten (die moet kunnen herstellen).
//
// IDEMPOTENT: (ontvanger, soort, sleutel) is uniek; sleutel =
// "klusstatus:<logregel-id>" of "incident:<id>". Zie hh_meldingen_hulp.js.
//
// EEN FOUT BREEKT NOOIT DE STATUSWISSEL: e.next() komt EERST (de wissel is
// dan al opgeslagen en de rest van de keten loopt door), en al het werk
// daarna zit in try/catch met een logregel voor journalctl.
//
// RISICO (memory reference_pb_jsvm_hooks punt 11): een after-success-keten
// stopt als een handler vóór ons geen e.next() aanroept. Dit bestand laadt
// alfabetisch vóór main.pb.js; wij roepen e.next() altijd aan. Controle na
// deploy: scripts/32-meldingencheck.mjs --apply.
//
// Gotchas: helpers via require() BINNEN de handler, $app en niet e.app,
// e.next() op ELK pad, filters met {:param}.
//
// DEPLOY: scripts/33-hook-deploy.sh (dit bestand + hh_meldingen_hulp.js).
// ROLLBACK: 33-hook-deploy.sh --rollback.

onRecordAfterCreateSuccess((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_meldingen_hulp.js`);
    const aantal = hulp.verwerkWissel({ app: $app, Record: Record }, e.record);
    if (aantal > 0) {
      console.log(`[hh_meldingen] ${aantal} melding(en) bij logregel ${e.record.id}`);
    }
  } catch (err) {
    console.log("[hh_meldingen] meldingen bij statuswissel mislukt:", String(err));
  }
}, "hh_klus_status");

onRecordAfterCreateSuccess((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_meldingen_hulp.js`);
    const aantal = hulp.verwerkIncident({ app: $app, Record: Record }, e.record);
    console.log(`[hh_meldingen] ${aantal} melding(en) bij incident ${e.record.id}`);
  } catch (err) {
    console.log("[hh_meldingen] meldingen bij incident mislukt:", String(err));
  }
}, "hh_incidenten");

onRecordUpdateRequest((e) => {
  // Alleen gelezen_op mag veranderen; de rest terug naar wat er stond.
  const VASTE_VELDEN = ["ontvanger", "soort", "klus", "incident", "titel", "tekst", "sleutel"];
  let magAlles = false;
  try {
    magAlles = !!(e.hasSuperuserAuth && e.hasSuperuserAuth());
  } catch (_) {
    magAlles = false;
  }
  if (!magAlles) {
    try {
      const origineel = e.record.original();
      for (let i = 0; i < VASTE_VELDEN.length; i++) {
        e.record.set(VASTE_VELDEN[i], origineel.get(VASTE_VELDEN[i]));
      }
    } catch (err) {
      console.log("[hh_meldingen] terugzetten van vaste velden mislukt:", String(err));
    }
  }
  e.next();
}, "hh_meldingen");

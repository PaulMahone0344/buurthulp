// HeitjeHulp M9 — hh_familie.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Alles hieronder raakt alleen hh_koppelingen (en leest hh_users):
//
// 1. POST /api/hh/koppelingen/aanvragen   body {email_oudere}
//    Het familielid vraagt een koppeling aan (backend OPEN-PUNT 19). Zie
//    hh_familie_hulp.js: koppeling "aangevraagd" met lege rechten als de
//    oudere bestaat, en ALTIJD hetzelfde vaste bericht. Hooguit 5 per dag.
//    Antwoorden: 200 {melding} (altijd hetzelfde); 400 {melding, reden:
//    "email"}; 401 anoniem; 403 {melding, reden: "rol"} geen familie;
//    429 {melding, reden: "limiet"}.
//    De koppeling wordt via $app gemaakt: de createRule van hh_koppelingen
//    (alleen de oudere of de coordinator) blijft dus gewoon dicht voor het
//    familielid.
//
// 2. onRecordCreateRequest op hh_koppelingen
//    De bestaande weg (de oudere maakt zelf de koppeling, of de coordinator)
//    geeft meteen status actief, en zonder meegestuurde rechten allebei
//    (meekijken en plaatsen).
//
// 3. onRecordUpdateRequest op hh_koppelingen
//    Zet de oudere een aanvraag op actief ("Ja") zonder rechten mee te
//    sturen, dan krijgt de koppeling allebei. "Nee" en "Ontkoppelen" zijn een
//    gewone delete (deleteRule: oudere, familielid of coordinator). Het
//    familielid kan zijn eigen koppeling niet bijwerken: de updateRule laat
//    alleen de oudere en de coordinator toe.
//
// Gotchas: helpers via require() BINNEN de handler, $app en niet e.app,
// e.next() op ELK pad van een onRecord*-hook, bindBody met DynamicModel,
// filters met {:param}.
//
// DEPLOY: scripts/43-hook-deploy.sh (dit bestand + hh_familie_hulp.js).
// ROLLBACK: 43-hook-deploy.sh --rollback.

routerAdd(
  "POST",
  "/api/hh/koppelingen/aanvragen",
  (e) => {
    const hulp = require(`${__hooks}/hh_familie_hulp.js`);
    const data = new DynamicModel({ email_oudere: "" });
    try {
      e.bindBody(data);
    } catch (_) {
      // Leeg of onleesbaar: verwerkAanvraag geeft dan 400 op het adres.
    }
    const uit = hulp.verwerkAanvraag(
      { app: $app, Record: Record },
      {
        familielidId: e.auth.id,
        rol: String(e.auth.get("rol") || ""),
        email: String(data.email_oudere || ""),
        nu: Date.now(),
      }
    );
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

onRecordCreateRequest((e) => {
  try {
    const hulp = require(`${__hooks}/hh_familie_hulp.js`);
    e.record.set("status", "actief");
    e.record.set("rechten", hulp.rechtenOfStandaard(e.record.get("rechten")));
  } catch (err) {
    console.log("[hh_familie] standaard bij aanmaken mislukt:", String(err));
  }
  e.next();
}, "hh_koppelingen");

onRecordUpdateRequest((e) => {
  try {
    const hulp = require(`${__hooks}/hh_familie_hulp.js`);
    const wasActief = String(e.record.original().get("status") || "") === "actief";
    const wordtActief = String(e.record.get("status") || "") === "actief";
    if (wordtActief && !wasActief) {
      e.record.set("rechten", hulp.rechtenOfStandaard(e.record.get("rechten")));
    }
  } catch (err) {
    console.log("[hh_familie] rechten bij toestemming mislukt:", String(err));
  }
  e.next();
}, "hh_koppelingen");

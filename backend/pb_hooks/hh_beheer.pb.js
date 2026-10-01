// HeitjeHulp M14 — hh_beheer.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Drie dingen voor het beheerpaneel (website, #/beheer):
//
// 1. GEBLOKKEERD = BUITEN (hh_users.geblokkeerd, script 60)
//    a. onRecordAuthWithPasswordRequest op hh_users: een geblokkeerde
//       gebruiker met het juiste wachtwoord krijgt 400 met "Dit account is
//       geblokkeerd. ..." (een fout wachtwoord geeft de gewone 400).
//    b. routerUse: elke aanroep met een geldig token van een geblokkeerde
//       hh_users-gebruiker op /api/hh/*, /api/collections/hh_* (ook
//       auth-refresh) of /api/realtime krijgt 403 met dezelfde melding. Zo
//       werkt een token van vóór het blokkeren ook niet meer. Elke andere
//       aanroep (andere projecten op deze server, anoniem, superuser) gaat
//       ongemoeid door. Fail-open: lukt het nakijken niet, dan gaat het
//       verzoek door (de API-rules blijven de eerste sluis).
//
// 2. AUDITLOG (hh_auditlog, scripts 60/61; schrijven kan alleen via $app)
//    Elke create/update/delete door een COORDINATOR op hh_wijken,
//    hh_klustypes, hh_users, hh_profielen, hh_instellingen en hh_incidenten
//    krijgt een regel: door, actie (aanmaken|wijzigen|verwijderen),
//    doel_collectie, doel_id, detail (welke velden, van/naar; geheime velden
//    zoals wachtwoord, IBAN en foto's alleen bij naam).
//
//    AFWIJKING VAN DE PROMPT: de prompt noemt onRecordAfter*Success. Die
//    events dragen in PocketBase 0.25 geen auth (geen "wie"), en M7 meldt dat
//    after-success-ketens op deze server gevoelig zijn. Daarom de request-
//    hooks, zoals M6/M7 al doen: e.next() EERST (lukt de handeling niet, dan
//    gooit e.next() en komt er terecht geen regel), daarna het loggen in
//    try/catch. Een mislukte auditregel breekt de handeling nooit.
//    Gevolg: alleen handelingen via de API worden gelogd, niet wat een hook
//    of script via $app doet (die zijn geen beheerhandeling van een mens).
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler of via require() van een
// gewoon .js-bestand; $app en niet e.app; e.next() op elk pad (een throw is
// een bewuste weigering); json-velden met toString() decoderen.
//
// DEPLOY: scripts/63-hook-deploy.sh (dit bestand + hh_beheer_hulp.js).
// 10-hook-deploy.sh kent alleen hh_klussen.pb.js. ROLLBACK: 63 --rollback.
// VOORWAARDE: 60-beheer-velden.mjs --apply (veld geblokkeerd, hh_auditlog).

// --------------------------------------------------------------------------
// 1a. Inloggen geweigerd voor een geblokkeerde gebruiker
// --------------------------------------------------------------------------
onRecordAuthWithPasswordRequest((e) => {
  const hulp = require(`${__hooks}/hh_beheer_hulp.js`);
  let geblokkeerd = false;
  try {
    // Alleen bij het juiste wachtwoord: anders verraadt de melding dat het
    // account bestaat. Bij een fout wachtwoord doet PocketBase zijn gewone 400.
    geblokkeerd = !!(
      e.record &&
      e.record.getBool("geblokkeerd") &&
      e.record.validatePassword(String(e.password || ""))
    );
  } catch (err) {
    console.log("[hh_beheer] blokkade nakijken bij inloggen mislukt:", String(err));
  }
  if (geblokkeerd) {
    throw new BadRequestError(hulp.MELDING_GEBLOKKEERD);
  }
  e.next();
}, "hh_users");

// --------------------------------------------------------------------------
// 1b. Elke hh-aanroep geweigerd voor een geblokkeerde gebruiker
// --------------------------------------------------------------------------
routerUse((e) => {
  let geblokkeerd = false;
  let melding = "";
  try {
    if (e.auth) {
      const hulp = require(`${__hooks}/hh_beheer_hulp.js`);
      const pad = String((e.request && e.request.url && e.request.url.path) || "");
      if (hulp.isHhPad(pad) && String(e.auth.collection().name || "") === "hh_users") {
        geblokkeerd = e.auth.getBool("geblokkeerd");
        melding = hulp.MELDING_GEBLOKKEERD;
      }
    }
  } catch (err) {
    console.log("[hh_beheer] blokkade nakijken mislukt:", String(err));
    geblokkeerd = false;
  }
  if (geblokkeerd) {
    throw new ForbiddenError(melding);
  }
  return e.next();
});

// --------------------------------------------------------------------------
// 2. Auditlog: aanmaken
// --------------------------------------------------------------------------
onRecordCreateRequest(
  (e) => {
    e.next();
    try {
      const hulp = require(`${__hooks}/hh_beheer_hulp.js`);
      if (!e.auth) return;
      if (!hulp.isCoordinator(e.auth.collection().name, e.auth.get("rol"))) return;
      const na = hulp.plat(e.record, (raw) => toString(raw));
      const regel = new Record($app.findCollectionByNameOrId("hh_auditlog"));
      regel.set("door", e.auth.id);
      regel.set("actie", "aanmaken");
      regel.set("doel_collectie", String(e.record.collection().name));
      regel.set("doel_id", e.record.id);
      regel.set("detail", hulp.auditDetail("aanmaken", null, na));
      $app.save(regel);
    } catch (err) {
      console.log("[hh_beheer] auditregel (aanmaken) mislukt:", String(err));
    }
  },
  "hh_wijken",
  "hh_klustypes",
  "hh_users",
  "hh_profielen",
  "hh_instellingen",
  "hh_incidenten"
);

// --------------------------------------------------------------------------
// 2. Auditlog: wijzigen
// --------------------------------------------------------------------------
onRecordUpdateRequest(
  (e) => {
    let voor = null;
    let coordinator = false;
    try {
      const hulp = require(`${__hooks}/hh_beheer_hulp.js`);
      coordinator = !!e.auth && hulp.isCoordinator(e.auth.collection().name, e.auth.get("rol"));
      if (coordinator) voor = hulp.plat(e.record.original(), (raw) => toString(raw));
    } catch (err) {
      console.log("[hh_beheer] audit voorbereiden (wijzigen) mislukt:", String(err));
      coordinator = false;
    }

    e.next();

    if (!coordinator) return;
    try {
      const hulp = require(`${__hooks}/hh_beheer_hulp.js`);
      const na = hulp.plat(e.record, (raw) => toString(raw));
      const detail = hulp.auditDetail("wijzigen", voor, na);
      if (!detail.velden.length) return;
      const regel = new Record($app.findCollectionByNameOrId("hh_auditlog"));
      regel.set("door", e.auth.id);
      regel.set("actie", "wijzigen");
      regel.set("doel_collectie", String(e.record.collection().name));
      regel.set("doel_id", e.record.id);
      regel.set("detail", detail);
      $app.save(regel);
    } catch (err) {
      console.log("[hh_beheer] auditregel (wijzigen) mislukt:", String(err));
    }
  },
  "hh_wijken",
  "hh_klustypes",
  "hh_users",
  "hh_profielen",
  "hh_instellingen",
  "hh_incidenten"
);

// --------------------------------------------------------------------------
// 2. Auditlog: verwijderen
// --------------------------------------------------------------------------
onRecordDeleteRequest(
  (e) => {
    let voor = null;
    let coordinator = false;
    let doelCollectie = "";
    let doelId = "";
    try {
      const hulp = require(`${__hooks}/hh_beheer_hulp.js`);
      coordinator = !!e.auth && hulp.isCoordinator(e.auth.collection().name, e.auth.get("rol"));
      if (coordinator) {
        voor = hulp.plat(e.record, (raw) => toString(raw));
        doelCollectie = String(e.record.collection().name);
        doelId = e.record.id;
      }
    } catch (err) {
      console.log("[hh_beheer] audit voorbereiden (verwijderen) mislukt:", String(err));
      coordinator = false;
    }

    e.next();

    if (!coordinator) return;
    try {
      const hulp = require(`${__hooks}/hh_beheer_hulp.js`);
      const regel = new Record($app.findCollectionByNameOrId("hh_auditlog"));
      // Een coordinator die zichzelf verwijdert: dan bestaat "door" niet meer.
      if (!(doelCollectie === "hh_users" && doelId === e.auth.id)) regel.set("door", e.auth.id);
      regel.set("actie", "verwijderen");
      regel.set("doel_collectie", doelCollectie);
      regel.set("doel_id", doelId);
      regel.set("detail", hulp.auditDetail("verwijderen", voor, null));
      $app.save(regel);
    } catch (err) {
      console.log("[hh_beheer] auditregel (verwijderen) mislukt:", String(err));
    }
  },
  "hh_wijken",
  "hh_klustypes",
  "hh_users",
  "hh_profielen",
  "hh_instellingen",
  "hh_incidenten"
);

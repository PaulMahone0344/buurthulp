// HeitjeHulp B2 — hh_aanmelden.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Aanmelden en goedkeuren zonder de oude screening. Raakt alleen hh_users en
// hh_profielen. Het rekenwerk staat in hh_aanmelden_hulp.js (getest zonder
// server: backend/tests/hh_aanmelden_hulp.test.mjs).
//
// 1. hh_users AANMAKEN en BIJWERKEN (API, ook superuser en coordinator)
//    a. Een helper (rol jongere) onder de 10 jaar wordt geweigerd: 400 met
//       "Je moet minstens 10 jaar zijn om helper te worden." Ook bij het
//       bijwerken van de geboortedatum (die mag de eigenaar sinds 80 niet
//       meer zelf, maar de coordinator wel).
//    b. Werkgebied uit de postcode (K4 + besluit 3 okt: Tiel en 20 km
//       eromheen). Komt er een postcode mee (aanmaken, of een andere bij
//       bijwerken), dan vraagt de server Nominatim om het punt (zoals de
//       M5-hook: User-Agent, timeout 5 s, hooguit 1 verzoek per seconde)
//       en zet werkgebied_status:
//         binnen   -> wijk = "Tiel en omstreken" (regio-wijk, script 81)
//         buiten   -> wijk leeg (bij bijwerken: gewist)
//         onbekend -> geocoding mislukt of geen resultaat: aanmelden gaat
//                     door, wijk leeg (bij bijwerken: blijft staan); de
//                     meldkamer ziet de markering
//       Stuurt een coordinator zelf een wijk mee, dan blijft die staan.
//
// 2. hh_profielen GOEDKEUREN WIST HET ID-DOCUMENT (B1-gat 2)
//    onRecordUpdate (model-hook): draait bij ELKE opslag, ook via de
//    superuser (beheer-UI), een script of een andere hook via $app. Gaat
//    verificatiestatus van iets anders naar "goedgekeurd", dan vóór het
//    opslaan: document_foto leeg (PocketBase verwijdert het bestand na het
//    opslaan) en id_gecontroleerd_op = nu. De B1-request-hook in
//    hh_beheer.pb.js zet alleen nog id_gecontroleerd_door (die kent de
//    coordinator); zo loopt het wissen niet dubbel.
//
// 3. hh_users VERRIJKEN (onRecordEnrich: elk antwoord, ook expand en realtime)
//    Bij een helper (rol jongere):
//    - extra veld id_gecontroleerd (ja/nee): id_gecontroleerd_op op zijn
//      profiel is gevuld. Zo ziet een bewoner het vinkje "ID gecontroleerd"
//      zonder het profiel te kunnen lezen (dat blijft eigen + coordinator).
//    - voor iedereen behalve de helper zelf en de coordinator: geboortedatum,
//      adres, ouder-gegevens enz. weg (VERBORGEN_VOOR_ANDEREN) en naam =
//      alleen de voornaam. Zonder ingelogde kijker (registreren, inloggen:
//      dat is altijd de eigenaar zelf) blijft alles staan.
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app; e.next() op elk pad (een throw is een bewuste weigering); de
// server draait UTC.
//
// DEPLOY: scripts/83-hook-deploy.sh (NIEUW bestand, samen met
// hh_aanmelden_hulp.js). VOORWAARDE: 70-b1-velden.mjs (B1, staat op prod).

// --------------------------------------------------------------------------
// 1. hh_users aanmaken: te jong weigeren, wijk uit postcode
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  const hulp = require(`${__hooks}/hh_aanmelden_hulp.js`);
  const vandaag = new Date().toISOString().slice(0, 10);
  const rol = String(e.record.get("rol") || "");
  const geboortedatum = String(e.record.get("geboortedatum") || "");
  if (hulp.isTeJong(rol, geboortedatum, vandaag)) {
    throw new BadRequestError(hulp.MELDING_TE_JONG);
  }

  const postcode = String(e.record.get("postcode") || "").trim();
  const isCoordinator =
    !!e.auth && e.auth.collection().name === "hh_users" && String(e.auth.get("rol") || "") === "coordinator";
  const wijkGestuurd = String(e.record.get("wijk") || "") !== "";
  if (postcode && !(isCoordinator && wijkGestuurd)) {
    const uit = hulp.bepaalWerkgebied(omgeving(), postcode);
    const wijk = uit.werkgebied ? hulp.wijkIdVoor($app, uit.werkgebied) : "";
    // Binnen, maar de regio-wijk bestaat nog niet (81 niet gedraaid): dan
    // telt het als onbekend, zodat de meldkamer het ziet.
    e.record.set("werkgebied_status", uit.status === "binnen" && !wijk ? "onbekend" : uit.status);
    e.record.set("wijk", wijk);
  }

  e.next();

  /// Echte omgeving voor bepaalWerkgebied (de tests geven een nep mee).
  /// HH_NOMINATIM_URL alleen voor een lokale proef; op prod leeg.
  function omgeving() {
    return {
      url: $os.getenv("HH_NOMINATIM_URL") || "",
      http: (req) => $http.send(req),
      nu: () => Date.now(),
      sleep: (ms) => sleep(ms),
      store: $app.store(),
      log: (...a) => console.log(...a),
    };
  }
}, "hh_users");

// --------------------------------------------------------------------------
// 1. hh_users bijwerken: te jong weigeren, wijk volgt de postcode
// --------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  const hulp = require(`${__hooks}/hh_aanmelden_hulp.js`);
  const vandaag = new Date().toISOString().slice(0, 10);
  const oud = e.record.original();
  const rol = String(e.record.get("rol") || "");
  const geboortedatum = String(e.record.get("geboortedatum") || "");
  const gebOud = String(oud.get("geboortedatum") || "");
  if (geboortedatum !== gebOud && hulp.isTeJong(rol, geboortedatum, vandaag)) {
    throw new BadRequestError(hulp.MELDING_TE_JONG);
  }

  const postcode = String(e.record.get("postcode") || "").trim();
  const pcOud = String(oud.get("postcode") || "").trim();
  const isCoordinator =
    !!e.auth && e.auth.collection().name === "hh_users" && String(e.auth.get("rol") || "") === "coordinator";
  const wijkGestuurd = String(e.record.get("wijk") || "") !== String(oud.get("wijk") || "");
  if (postcode && postcode !== pcOud && !(isCoordinator && wijkGestuurd)) {
    const uit = hulp.bepaalWerkgebied(omgeving(), postcode);
    if (uit.status === "binnen") {
      const wijk = hulp.wijkIdVoor($app, uit.werkgebied);
      e.record.set("werkgebied_status", wijk ? "binnen" : "onbekend");
      if (wijk) e.record.set("wijk", wijk);
    } else if (uit.status === "buiten") {
      // Verhuisd buiten het werkgebied: geen wijk meer.
      e.record.set("werkgebied_status", "buiten");
      e.record.set("wijk", "");
    } else {
      // Onbekend (geen internet, geen resultaat): de wijk blijft staan.
      e.record.set("werkgebied_status", "onbekend");
    }
  }

  e.next();

  /// Echte omgeving voor bepaalWerkgebied (de tests geven een nep mee).
  /// HH_NOMINATIM_URL alleen voor een lokale proef; op prod leeg.
  function omgeving() {
    return {
      url: $os.getenv("HH_NOMINATIM_URL") || "",
      http: (req) => $http.send(req),
      nu: () => Date.now(),
      sleep: (ms) => sleep(ms),
      store: $app.store(),
      log: (...a) => console.log(...a),
    };
  }
}, "hh_users");

// --------------------------------------------------------------------------
// 2. Goedkeuren wist het ID-document, langs elke weg (B1-gat 2)
// --------------------------------------------------------------------------
onRecordUpdate((e) => {
  const beheer = require(`${__hooks}/hh_beheer_hulp.js`);
  const oud = String(e.record.original().get("verificatiestatus") || "");
  const nieuw = String(e.record.get("verificatiestatus") || "");
  const wissen = beheer.isGoedkeuring(oud, nieuw);
  if (wissen) {
    // Bewust geen try/catch: lukt het zetten niet, dan liever geen
    // goedkeuring dan een goedkeuring met het document nog op de server.
    e.record.set("document_foto", "");
    e.record.set("id_gecontroleerd_op", new DateTime());
  }

  e.next();

  if (wissen) {
    console.log(`[hh_aanmelden] profiel ${e.record.id} goedgekeurd: ID-document gewist`);
  }
}, "hh_profielen");

// --------------------------------------------------------------------------
// 3. Helper verrijken: vinkje "ID gecontroleerd", privé-velden weg voor anderen
// --------------------------------------------------------------------------
onRecordEnrich((e) => {
  if (String(e.record.get("rol") || "") !== "jongere") {
    return e.next();
  }
  const hulp = require(`${__hooks}/hh_aanmelden_hulp.js`);

  let gecontroleerd = false;
  try {
    const rijen = $app.findRecordsByFilter(
      "hh_profielen",
      "gebruiker = {:id} && id_gecontroleerd_op != ''",
      "",
      1,
      0,
      { id: e.record.id }
    );
    gecontroleerd = rijen.length > 0;
  } catch (err) {
    console.log("[hh_aanmelden] id_gecontroleerd nakijken mislukt:", String(err));
  }
  e.record.withCustomData(true);
  e.record.set("id_gecontroleerd", gecontroleerd);

  const kijker = e.requestInfo ? e.requestInfo.auth : null;
  if (kijker) {
    const kijkerRol = kijker.collection().name === "hh_users" ? String(kijker.get("rol") || "") : "";
    const isSuperuser = kijker.collection().name === "_superusers";
    if (!isSuperuser && !hulp.magAllesZien(kijker.id, kijkerRol, e.record.id)) {
      e.record.hide(...hulp.VERBORGEN_VOOR_ANDEREN);
      e.record.set("naam", hulp.voornaam(e.record.get("naam")));
    }
  }

  return e.next();
}, "hh_users");

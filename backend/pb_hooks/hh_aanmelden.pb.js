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
//    c. ADRES (4 okt, hh_adres_hulp.js): bewoner en helper hebben een
//       postcode (4 cijfers + 2 letters) en een huisnummer dat bij PDOK
//       (BAG) bestaat; straat, plaats, punt (lat/lon) en adres_bron = pdok
//       komen van PDOK en overschrijven vrije invoer. Bij aanmaken altijd,
//       bij bijwerken alleen als een adresveld verandert. Werkgebied uit het
//       exacte PDOK-punt (geen Nominatim). PDOK onbereikbaar: aanmelden gaat
//       door, adres_bron = ongecontroleerd, werkgebied via Nominatim (B2).
//       Coordinator/superuser met adres_bron = "handmatig": uitzondering
//       zonder PDOK. lat/lon/adres_bron zelf meesturen: alleen coordinator
//       en superuser. De superuser (seed, scripts) is verder niet streng.
//
// 2. hh_profielen GOEDKEUREN (B1-gat 2) EN AFKEUREN (4 okt) WISSEN HET ID-DOCUMENT
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
// ADRES: scripts/123-hook-deploy.sh, VOORWAARDE 120-adres-velden.mjs.

// --------------------------------------------------------------------------
// 1. hh_users aanmaken: te jong weigeren, adres via PDOK, wijk uit het punt
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  const hulp = require(`${__hooks}/hh_aanmelden_hulp.js`);
  const adres = require(`${__hooks}/hh_adres_hulp.js`);
  const vandaag = new Date().toISOString().slice(0, 10);
  const rol = String(e.record.get("rol") || "");
  const geboortedatum = String(e.record.get("geboortedatum") || "");
  if (hulp.isTeJong(rol, geboortedatum, vandaag)) {
    throw new BadRequestError(hulp.MELDING_TE_JONG);
  }

  // ADRES: de server is de waarheid (hh_adres_hulp.beoordeel).
  const body = e.requestInfo().body || {};
  const wie = adres.wieIs(e.auth);
  const uit = adres.beoordeel(adresOmgeving(), {
    wie: wie,
    rol: rol,
    nieuw: true,
    aangeraakt: true,
    servervelden: adres.serverveldenGestuurd(body),
    adresBron: String(body.adres_bron || ""),
    postcode: e.record.get("postcode"),
    huisnummer: e.record.get("huisnummer"),
    toevoeging: e.record.get("toevoeging"),
  });
  if (uit.actie === "weiger") {
    // data.adres.code "hh_adres_<reden>": de app toont dan deze melding.
    throw new BadRequestError(uit.melding, { adres: new ValidationError("hh_adres_" + uit.reden, uit.melding) });
  }
  if (uit.actie === "pdok") adres.zetPdokAdres(e.record, uit.adres);
  if (uit.actie === "terugval") adres.zetOngecontroleerd(e.record, uit);
  if (uit.actie === "handmatig") e.record.set("adres_bron", "handmatig");

  const postcode = String(e.record.get("postcode") || "").trim();
  const wijkGestuurd = String(e.record.get("wijk") || "") !== "";
  if (!(wie === "coordinator" && wijkGestuurd)) {
    let werk = null;
    if (uit.actie === "pdok") {
      // Exact punt van PDOK: geen Nominatim nodig.
      werk = hulp.werkgebiedUitPunt({ lat: uit.adres.lat, lon: uit.adres.lon });
    } else if (postcode) {
      // Terugval, uitzondering of oude weg: het postcode-punt (B2).
      werk = hulp.bepaalWerkgebied(nominatimOmgeving(), postcode);
    }
    if (werk) {
      const wijk = werk.werkgebied ? hulp.wijkIdVoor($app, werk.werkgebied) : "";
      // Binnen, maar de regio-wijk bestaat nog niet (81 niet gedraaid): dan
      // telt het als onbekend, zodat de meldkamer het ziet.
      e.record.set("werkgebied_status", werk.status === "binnen" && !wijk ? "onbekend" : werk.status);
      e.record.set("wijk", wijk);
    }
  }

  e.next();

  /// Echte omgeving voor bepaalWerkgebied (de tests geven een nep mee).
  /// HH_NOMINATIM_URL alleen voor een lokale proef; op prod leeg.
  function nominatimOmgeving() {
    return {
      url: $os.getenv("HH_NOMINATIM_URL") || "",
      http: (req) => $http.send(req),
      nu: () => Date.now(),
      sleep: (ms) => sleep(ms),
      store: $app.store(),
      log: (...a) => console.log(...a),
    };
  }

  /// Echte omgeving voor PDOK. HH_PDOK_URL alleen voor een lokale proef.
  function adresOmgeving() {
    return {
      url: $os.getenv("HH_PDOK_URL") || "",
      http: (req) => $http.send(req),
      nu: () => Date.now(),
      store: $app.store(),
      log: (...a) => console.log(...a),
      binnen: (punt) => !!hulp.werkgebiedVoorPunt(punt),
    };
  }
}, "hh_users");

// --------------------------------------------------------------------------
// 1. hh_users bijwerken: te jong weigeren, ander adres opnieuw via PDOK, de
//    wijk volgt het (nieuwe) punt
// --------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  const hulp = require(`${__hooks}/hh_aanmelden_hulp.js`);
  const adres = require(`${__hooks}/hh_adres_hulp.js`);
  const vandaag = new Date().toISOString().slice(0, 10);
  const oud = e.record.original();
  const rol = String(e.record.get("rol") || "");
  const geboortedatum = String(e.record.get("geboortedatum") || "");
  const gebOud = String(oud.get("geboortedatum") || "");
  if (geboortedatum !== gebOud && hulp.isTeJong(rol, geboortedatum, vandaag)) {
    throw new BadRequestError(hulp.MELDING_TE_JONG);
  }

  // ADRES: alleen als er aan het adres iets verandert (bestaande accounts
  // met een onvolledig adres kunnen gewoon hun naam enz. wijzigen).
  const body = e.requestInfo().body || {};
  const wie = adres.wieIs(e.auth);
  const uit = adres.beoordeel(adresOmgeving(), {
    wie: wie,
    rol: rol,
    nieuw: false,
    aangeraakt: adres.isAdresAangeraakt(e.record, oud),
    servervelden: adres.serverveldenGestuurd(body),
    adresBron: String(body.adres_bron || ""),
    postcode: e.record.get("postcode"),
    huisnummer: e.record.get("huisnummer"),
    toevoeging: e.record.get("toevoeging"),
  });
  if (uit.actie === "weiger") {
    // data.adres.code "hh_adres_<reden>": de app toont dan deze melding.
    throw new BadRequestError(uit.melding, { adres: new ValidationError("hh_adres_" + uit.reden, uit.melding) });
  }
  if (uit.actie === "pdok") adres.zetPdokAdres(e.record, uit.adres);
  if (uit.actie === "terugval") adres.zetOngecontroleerd(e.record, uit);
  if (uit.actie === "handmatig") e.record.set("adres_bron", "handmatig");

  const postcode = String(e.record.get("postcode") || "").trim();
  const pcOud = String(oud.get("postcode") || "").trim();
  const wijkGestuurd = String(e.record.get("wijk") || "") !== String(oud.get("wijk") || "");
  if (!(wie === "coordinator" && wijkGestuurd)) {
    let werk = null;
    if (uit.actie === "pdok") {
      werk = hulp.werkgebiedUitPunt({ lat: uit.adres.lat, lon: uit.adres.lon });
    } else if (postcode && postcode !== pcOud) {
      werk = hulp.bepaalWerkgebied(nominatimOmgeving(), postcode);
    }
    if (werk && werk.status === "binnen") {
      const wijk = hulp.wijkIdVoor($app, werk.werkgebied);
      e.record.set("werkgebied_status", wijk ? "binnen" : "onbekend");
      if (wijk) e.record.set("wijk", wijk);
    } else if (werk && werk.status === "buiten") {
      // Verhuisd buiten het werkgebied: geen wijk meer.
      e.record.set("werkgebied_status", "buiten");
      e.record.set("wijk", "");
    } else if (werk) {
      // Onbekend (geen internet, geen resultaat): de wijk blijft staan.
      e.record.set("werkgebied_status", "onbekend");
    }
  }

  e.next();

  /// Echte omgeving voor bepaalWerkgebied (de tests geven een nep mee).
  /// HH_NOMINATIM_URL alleen voor een lokale proef; op prod leeg.
  function nominatimOmgeving() {
    return {
      url: $os.getenv("HH_NOMINATIM_URL") || "",
      http: (req) => $http.send(req),
      nu: () => Date.now(),
      sleep: (ms) => sleep(ms),
      store: $app.store(),
      log: (...a) => console.log(...a),
    };
  }

  /// Echte omgeving voor PDOK. HH_PDOK_URL alleen voor een lokale proef.
  function adresOmgeving() {
    return {
      url: $os.getenv("HH_PDOK_URL") || "",
      http: (req) => $http.send(req),
      nu: () => Date.now(),
      store: $app.store(),
      log: (...a) => console.log(...a),
      binnen: (punt) => !!hulp.werkgebiedVoorPunt(punt),
    };
  }
}, "hh_users");

// --------------------------------------------------------------------------
// 2. Goedkeuren en afkeuren wissen het ID-document, langs elke weg (B1-gat 2)
// --------------------------------------------------------------------------
onRecordUpdate((e) => {
  const beheer = require(`${__hooks}/hh_beheer_hulp.js`);
  const oud = String(e.record.original().get("verificatiestatus") || "");
  const nieuw = String(e.record.get("verificatiestatus") || "");
  const goedgekeurd = beheer.isGoedkeuring(oud, nieuw);
  // ID-AFKEUR (4 okt): ook bij afkeuren gaat het document weg.
  const afgekeurd = beheer.isAfkeuring(oud, nieuw);
  if (goedgekeurd || afgekeurd) {
    // Bewust geen try/catch: lukt het zetten niet, dan liever geen
    // besluit dan een besluit met het document nog op de server.
    e.record.set("document_foto", "");
  }
  if (goedgekeurd) {
    e.record.set("id_gecontroleerd_op", new DateTime());
  }

  e.next();

  if (goedgekeurd || afgekeurd) {
    console.log(`[hh_aanmelden] profiel ${e.record.id} ${goedgekeurd ? "goedgekeurd" : "afgewezen"}: ID-document gewist`);
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

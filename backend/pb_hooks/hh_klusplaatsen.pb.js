// HeitjeHulp B4 — hh_klusplaatsen.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Klus plaatsen: categorie, foto, tijd, leeftijd en de controle door de
// meldkamer. Eigen bestand naast hh_klussen.pb.js (M5/M6; daar zit alleen de
// leeftijd- en keurcontrole in de accepteer-route bij). Rekenwerk:
// hh_klusplaatsen_hulp.js.
//
// 1. API-create van hh_klussen (onRecordCreateRequest)
//    - Iedereen: min_leeftijd (categorie, of 18 door de tijdregel) en
//      geboren_uiterlijk (klusdag min die jaren; zonder begintijd: vandaag)
//      rekent de server uit. De lijst-rule (101) vergelijkt daar de
//      geboortedatum van de helper mee. controle_markering = voorfilter op
//      de omschrijving (telefoon, e-mail, link, nee-lijst; blokkeert niet).
//    - Bewoner of familielid (geen coordinator, geen superuser), status open:
//      omschrijving 5-300 tekens, een foto, wanneer_van niet voorbij,
//      wanneer_tot (optioneel) na wanneer_van, nee_lijst_akkoord = ja.
//      Anders 400 met een Nederlandse melding. De klus begint ONGEKEURD
//      (klus_goedgekeurd_op leeg): helpers zien hem nog niet.
//      Een concept (status concept) hoeft nog niet compleet; concept -> open
//      blijft zoals in M6 en blijft ongekeurd tot de meldkamer keurt.
//    - Coordinator of superuser (telefonische ingang, punt 9; seed): geen
//      eisen, en de klus is meteen goedgekeurd (de meldkamer zette hem zelf).
//
// 2. API-update van hh_klussen (onRecordUpdateRequest)
//    - Verandert de categorie of een tijd: min_leeftijd en geboren_uiterlijk
//      opnieuw. Verandert de omschrijving: de markering opnieuw.
//    - Een bewoner/familielid die de inhoud (omschrijving, foto, categorie,
//      tijden, adres) van een GOEDGEKEURDE klus wijzigt: de goedkeuring
//      vervalt, de meldkamer kijkt opnieuw (anders: goedkeuren, daarna een
//      telefoonnummer erin zetten).
//
// 3. POST /api/hh/klussen/{id}/keuren   body { besluit, reden }
//    Alleen een coordinator. besluit "goedkeuren" of "afkeuren"; bij afkeuren
//    een reden van 5-300 tekens. Alleen een open klus zonder helper.
//      goedkeuren: klus_goedgekeurd_op = nu, _door = coordinator, leeftijd
//                  opnieuw uitgerekend, en een logregel open -> open
//                  ("goedgekeurd door de meldkamer"). Die logregel laat
//                  hh_meldingen de helpers in de wijk een "nieuwe klus" sturen
//                  (punt 4 hieronder filtert op leeftijd).
//      afkeuren:   klus_afgekeurd_op = nu, klus_afkeur_reden, status
//                  geannuleerd, en een logregel open -> geannuleerd met de
//                  reden. hh_meldingen stuurt de bewoner dan "geannuleerd";
//                  punt 4 maakt daar "Je klus is afgekeurd: <reden>" van.
//    Antwoorden: 200 { klus, besluit, status }; 400 { melding, reden:
//    "besluit" | "reden" }; 401 anoniem; 403 { reden: "rol" }; 404;
//    409 { reden: "status" | "algoedgekeurd" | "kennismaking" }. B11: met
//      b11_kennismaking_verplicht aan en de bewoner nog niet "gesproken"
//      -> 409 kennismaking (hh_meldkamer_hulp.wachtOpKennismaking).
//
// 4. hh_meldingen aanmaken (onRecordCreate, model-hook: ook via $app)
//    - "nieuwe_klus": alleen als de klus goedgekeurd is en de ontvanger oud
//      genoeg is (zelfde grens als de lijst-rule). Anders wordt de melding
//      NIET opgeslagen (geen e.next()). Zo krijgt een helper van 11 geen
//      melding van een tuinklus, en niemand een melding van een klus die nog
//      nagekeken wordt (hh_meldingen_hulp.js zelf blijft ongemoeid).
//    - "geannuleerd" voor de bewoner van een AFGEKEURDE klus: titel en tekst
//      met de reden van de meldkamer.
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app; e.next() op elk pad behalve een bewuste weigering; de server
// draait UTC (NL-tijd rekent het hulpbestand zelf). De statuscode van een
// route komt pas na runInTransaction (een fout van binnenuit wordt een 500).
//
// DEPLOY: scripts/103-hook-deploy.sh (NIEUW, met hh_klusplaatsen_hulp.js en
// hh_klussen.pb.js). VOORWAARDE: 100-b4-velden.mjs --apply.

// --------------------------------------------------------------------------
// 1. Aanmaken
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  const hulp = require(`${__hooks}/hh_klusplaatsen_hulp.js`);
  const beheer = isBeheer(e);
  const r = e.record;

  // Tweede sluis naast de rule (101): de keur-velden zet nooit een bewoner.
  if (!beheer) {
    r.set("klus_goedgekeurd_op", "");
    r.set("klus_goedgekeurd_door", "");
    r.set("klus_afgekeurd_op", "");
    r.set("klus_afkeur_reden", "");
  }

  if (!beheer && String(r.get("status") || "") === "open") {
    const fout = hulp.controleerNieuweKlus({
      omschrijving: String(r.get("omschrijving") || ""),
      heeftFoto: heeftFoto(r),
      neeLijstAkkoord: r.getBool("nee_lijst_akkoord"),
      van: String(r.get("wanneer_van") || ""),
      tot: String(r.get("wanneer_tot") || ""),
      nu: Date.now(),
    });
    if (fout) throw new BadRequestError(fout.melding);
  } else if (!beheer && String(r.get("omschrijving") || "").length > hulp.OMSCHRIJVING_MAX) {
    throw new BadRequestError("Je omschrijving is te lang (hooguit 300 tekens).");
  }

  zetBerekend(r, hulp);

  if (beheer && !String(r.get("klus_goedgekeurd_op") || "").trim() && !String(r.get("klus_afgekeurd_op") || "").trim()) {
    r.set("klus_goedgekeurd_op", new DateTime());
    const door = coordinatorId(e);
    if (door) r.set("klus_goedgekeurd_door", door);
  }

  e.next();

  // ---- helpers, BINNEN de handler (pool-runtime deelt geen scope) ----

  function isBeheer(ev) {
    try {
      if (ev.hasSuperuserAuth && ev.hasSuperuserAuth()) return true;
    } catch (_) {
      // oudere PocketBase: verder kijken
    }
    return coordinatorId(ev) !== "";
  }

  function coordinatorId(ev) {
    const auth = ev.auth;
    if (!auth) return "";
    try {
      if (String(auth.collection().name || "") !== "hh_users") return "";
      return String(auth.get("rol") || "") === "coordinator" ? auth.id : "";
    } catch (_) {
      return "";
    }
  }

  /// Een nieuw of bestaand bestand in "foto".
  function heeftFoto(record) {
    try {
      const nieuw = record.getUnsavedFiles("foto");
      if (nieuw && nieuw.length > 0) return true;
    } catch (_) {
      // geen getUnsavedFiles: verder kijken
    }
    const waarde = record.get("foto");
    if (Array.isArray(waarde)) return waarde.length > 0;
    return String(waarde || "").trim() !== "";
  }

  function zetBerekend(record, h) {
    let typeMin;
    try {
      const type = $app.findRecordById("hh_klustypes", String(record.get("klustype") || ""));
      typeMin = type.getInt("min_leeftijd");
    } catch (_) {
      typeMin = undefined; // geen of onbekende categorie: veilig 18
    }
    const van = String(record.get("wanneer_van") || "");
    const tot = String(record.get("wanneer_tot") || "");
    const min = h.minLeeftijdVoorKlus({ typeMinLeeftijd: typeMin, van: van, tot: tot });
    record.set("min_leeftijd", min);
    record.set("geboren_uiterlijk", h.geborenUiterlijk(van || new Date().toISOString(), min));
    record.set("controle_markering", h.voorfilter(String(record.get("omschrijving") || "")));
  }
}, "hh_klussen");

// --------------------------------------------------------------------------
// 2. Wijzigen
// --------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  const hulp = require(`${__hooks}/hh_klusplaatsen_hulp.js`);
  const r = e.record;
  const o = r.original();
  const anders = (veld) => JSON.stringify(r.get(veld)) !== JSON.stringify(o.get(veld));
  const beheer = isBeheer(e);

  if (!beheer && anders("omschrijving") && String(r.get("omschrijving") || "").length > hulp.OMSCHRIJVING_MAX) {
    throw new BadRequestError("Je omschrijving is te lang (hooguit 300 tekens).");
  }

  // Inhoud van een goedgekeurde klus gewijzigd door de bewoner: opnieuw keuren.
  const inhoud = ["omschrijving", "foto", "klustype", "wanneer_van", "wanneer_tot", "adres"];
  if (!beheer && String(o.get("klus_goedgekeurd_op") || "").trim() && inhoud.some(anders)) {
    r.set("klus_goedgekeurd_op", "");
    r.set("klus_goedgekeurd_door", "");
    console.log(`[hh_klusplaatsen] klus ${r.id} gewijzigd door de bewoner: opnieuw nakijken`);
  }

  if (anders("klustype") || anders("wanneer_van") || anders("wanneer_tot") || !String(r.get("geboren_uiterlijk") || "").trim()) {
    let typeMin;
    try {
      typeMin = $app.findRecordById("hh_klustypes", String(r.get("klustype") || "")).getInt("min_leeftijd");
    } catch (_) {
      typeMin = undefined;
    }
    const van = String(r.get("wanneer_van") || "");
    const tot = String(r.get("wanneer_tot") || "");
    const min = hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: typeMin, van: van, tot: tot });
    r.set("min_leeftijd", min);
    r.set("geboren_uiterlijk", hulp.geborenUiterlijk(van || String(r.get("created") || "") || new Date().toISOString(), min));
  }
  if (anders("omschrijving")) {
    r.set("controle_markering", hulp.voorfilter(String(r.get("omschrijving") || "")));
  }

  e.next();

  function isBeheer(ev) {
    try {
      if (ev.hasSuperuserAuth && ev.hasSuperuserAuth()) return true;
    } catch (_) {
      // verder kijken
    }
    const auth = ev.auth;
    if (!auth) return true; // fail-open zoals hh_klussen.pb.js: de rule is de eerste sluis
    try {
      if (String(auth.collection().name || "") !== "hh_users") return true;
      return String(auth.get("rol") || "") === "coordinator";
    } catch (_) {
      return false;
    }
  }
}, "hh_klussen");

// --------------------------------------------------------------------------
// 3. Keuren door de meldkamer
// --------------------------------------------------------------------------
routerAdd(
  "POST",
  "/api/hh/klussen/{id}/keuren",
  (e) => {
    const REDEN_MIN = 5;
    const REDEN_MAX = 300;
    const MELDING_ROL = "Alleen de meldkamer kan een klus keuren.";
    const MELDING_BESLUIT = "Kies goedkeuren of afkeuren.";
    const MELDING_REDEN = `Vul een reden in van ${REDEN_MIN} tot ${REDEN_MAX} tekens; de bewoner krijgt hem te zien.`;
    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";
    const MELDING_STATUS = "Deze klus staat niet meer open; keuren kan niet meer.";
    const MELDING_AL = "Deze klus is al goedgekeurd.";

    const hulp = require(`${__hooks}/hh_klusplaatsen_hulp.js`);
    const meldkamer = require(`${__hooks}/hh_meldkamer_hulp.js`);
    const klusId = String(e.request.pathValue("id") || "").trim();
    if (!klusId) return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });

    if (String(e.auth.get("rol") || "") !== "coordinator") {
      return e.json(403, { melding: MELDING_ROL, reden: "rol" });
    }
    const data = new DynamicModel({ besluit: "", reden: "" });
    try {
      e.bindBody(data);
    } catch (_) {
      return e.json(400, { melding: MELDING_BESLUIT, reden: "besluit" });
    }
    const besluit = String(data.besluit || "").trim();
    const reden = String(data.reden || "").trim();
    if (besluit !== "goedkeuren" && besluit !== "afkeuren") {
      return e.json(400, { melding: MELDING_BESLUIT, reden: "besluit" });
    }
    if (besluit === "afkeuren" && (reden.length < REDEN_MIN || reden.length > REDEN_MAX)) {
      return e.json(400, { melding: MELDING_REDEN, reden: "reden" });
    }

    const coordinatorId = e.auth.id;
    let uitkomst = "";
    let nieuweStatus = "";
    $app.runInTransaction((txApp) => {
      let klus;
      try {
        klus = txApp.findRecordById("hh_klussen", klusId);
      } catch (_) {
        uitkomst = "nietgevonden";
        return;
      }
      const status = String(klus.get("status") || "");
      const toegewezen = String(klus.get("toegewezen_jongere") || "").trim();
      if (status !== "open" || toegewezen) {
        uitkomst = "status";
        return;
      }
      const log = new Record(txApp.findCollectionByNameOrId("hh_klus_status"));
      log.set("klus", klus.id);
      log.set("door", coordinatorId);
      log.set("van", "open");

      if (besluit === "goedkeuren") {
        if (String(klus.get("klus_goedgekeurd_op") || "").trim()) {
          uitkomst = "algoedgekeurd";
          return;
        }
        // B11: met b11_kennismaking_verplicht aan wacht keuren op het belletje.
        if (meldkamer.wachtOpKennismaking(txApp, String(klus.get("hulpvrager") || ""))) {
          uitkomst = "kennismaking";
          return;
        }
        // Oude klussen (van vóór B4) hebben nog geen grens: nu uitrekenen.
        let typeMin;
        try {
          typeMin = txApp.findRecordById("hh_klustypes", String(klus.get("klustype") || "")).getInt("min_leeftijd");
        } catch (_) {
          typeMin = undefined;
        }
        const van = String(klus.get("wanneer_van") || "");
        const tot = String(klus.get("wanneer_tot") || "");
        const min = hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: typeMin, van: van, tot: tot });
        klus.set("min_leeftijd", min);
        klus.set("geboren_uiterlijk", hulp.geborenUiterlijk(van || new Date().toISOString(), min));
        klus.set("klus_goedgekeurd_op", new DateTime());
        klus.set("klus_goedgekeurd_door", coordinatorId);
        klus.set("klus_afgekeurd_op", "");
        klus.set("klus_afkeur_reden", "");
        nieuweStatus = "open";
        log.set("naar", "open");
        log.set("toelichting", "goedgekeurd door de meldkamer");
      } else {
        klus.set("klus_afgekeurd_op", new DateTime());
        klus.set("klus_afkeur_reden", reden);
        klus.set("klus_goedgekeurd_op", "");
        klus.set("klus_goedgekeurd_door", "");
        klus.set("status", "geannuleerd");
        nieuweStatus = "geannuleerd";
        log.set("naar", "geannuleerd");
        log.set("toelichting", ("afgekeurd door de meldkamer: " + reden).slice(0, REDEN_MAX));
      }
      txApp.save(klus);
      txApp.save(log);
      uitkomst = "ok";
    });

    if (uitkomst === "ok") {
      console.log(`[hh_klusplaatsen] coordinator ${coordinatorId}: klus ${klusId} ${besluit}`);
      return e.json(200, { klus: klusId, besluit: besluit, status: nieuweStatus });
    }
    if (uitkomst === "nietgevonden") return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    if (uitkomst === "algoedgekeurd") return e.json(409, { melding: MELDING_AL, reden: "algoedgekeurd" });
    if (uitkomst === "kennismaking") return e.json(409, { melding: meldkamer.MELDING_KEUREN, reden: "kennismaking" });
    return e.json(409, { melding: MELDING_STATUS, reden: "status" });
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// 4. Meldingen: geen "nieuwe klus" vóór de keuring of voor wie te jong is;
//    de afkeur-reden in de melding aan de bewoner.
// --------------------------------------------------------------------------
onRecordCreate((e) => {
  let opslaan = true;
  try {
    const soort = String(e.record.get("soort") || "");
    const klusId = String(e.record.get("klus") || "").trim();
    if (klusId && (soort === "nieuwe_klus" || soort === "geannuleerd")) {
      const hulp = require(`${__hooks}/hh_klusplaatsen_hulp.js`);
      const klus = $app.findRecordById("hh_klussen", klusId);
      const ontvangerId = String(e.record.get("ontvanger") || "");
      if (soort === "nieuwe_klus") {
        let geboortedatum = "";
        try {
          geboortedatum = String($app.findRecordById("hh_users", ontvangerId).get("geboortedatum") || "");
        } catch (_) {
          geboortedatum = "";
        }
        opslaan = hulp.magNieuweKlusMelding({
          goedgekeurdOp: String(klus.get("klus_goedgekeurd_op") || ""),
          geborenUiterlijk: String(klus.get("geboren_uiterlijk") || ""),
          geboortedatum: geboortedatum,
        });
      } else if (
        String(klus.get("klus_afgekeurd_op") || "").trim() &&
        ontvangerId === String(klus.get("hulpvrager") || "")
      ) {
        const t = hulp.afkeurTekst(String(klus.get("klus_afkeur_reden") || ""));
        e.record.set("titel", t.titel);
        e.record.set("tekst", t.tekst.slice(0, 600));
      }
    }
  } catch (err) {
    // Een fout hier mag een melding nooit tegenhouden (behalve de bewuste
    // weigering hierboven).
    console.log("[hh_klusplaatsen] melding nakijken mislukt:", String(err));
    opslaan = true;
  }
  if (!opslaan) return; // bewust: deze melding wordt niet opgeslagen
  e.next();
}, "hh_meldingen");

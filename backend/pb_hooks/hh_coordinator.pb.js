// HeitjeHulp M10 — hh_coordinator.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Twee routes voor C2 "klus doorzetten of handmatig koppelen". Allebei alleen
// op hh_klussen en hh_klus_status, allebei alleen voor rol coordinator.
//
// 1. POST /api/hh/klussen/{id}/koppelen   body { jongere }
//    De coordinator wijst een klus toe aan een jongere. Uitkomst op de klus is
//    EXACT gelijk aan accepteren door de jongere zelf (hh_klussen.pb.js, M5):
//    toegewezen_jongere = de jongere, status = geaccepteerd, plus een logregel
//    in hh_klus_status. Verschil: "door" is de coordinator en de logregel
//    draagt toelichting "handmatig gekoppeld".
//    De WIJK hoeft NIET gelijk te zijn — dat is juist het nut van handmatig
//    koppelen (een jongere uit de buurwijk invallen). Het antwoord meldt met
//    andere_wijk of dat zo is, zodat de app een waarschuwing kon tonen vóór
//    het bevestigen; de route zelf weigert er niet op.
//    De jongere moet wel rol jongere hebben en een hh_profielen-record met
//    verificatiestatus goedgekeurd.
//
//    Antwoorden:
//      200 { klus, status: "geaccepteerd", toegewezen_jongere, andere_wijk }
//      400 { melding, reden: "geenjongere" } — geen jongere in de body
//      401 anoniem ($apis.requireAuth)
//      403 { melding, reden: "rol" } — ingelogd, maar geen coordinator
//      404 { melding, reden: "nietgevonden" } — klus bestaat niet
//      409 { melding, reden: "bezet" } — klus niet meer open of al toegewezen
//      409 { melding, reden: "jongeronbekend" | "geenjongere" | "nietgoedgekeurd"
//                            | "vogverlopen" }  (vog_geldig_tot vóór vandaag; M14)
//
// 2. POST /api/hh/klussen/{id}/vrijgeven   body { reden }
//    Doorzetten: de coordinator haalt de jongere van een klus die geaccepteerd
//    of onderweg is. Klus gaat terug naar status open met een lege
//    toegewezen_jongere, plus een logregel (van = de oude status, naar = open,
//    toelichting "vrijgegeven: <reden>"). Daarna kan hij opnieuw koppelen.
//    Een reden is verplicht: een klus die uit iemands handen wordt gehaald mag
//    nooit zonder uitleg in het logboek staan.
//
//    Antwoorden:
//      200 { klus, status: "open", van }
//      400 { melding, reden: "geenreden" }
//      401 / 403 / 404 zoals hierboven
//      409 { melding, reden: "nietvrijtegeven" } — klus staat niet op
//          geaccepteerd of onderweg
//
// M6 blokkeert statuswijziging via een gewone record-update voor niet-
// coordinatoren. Deze routes gaan NIET via record-update maar rechtstreeks in
// een transactie, zodat de logregel altijd klopt en er nooit een statuswissel
// zonder logregel kan bestaan.
//
// Gotchas (memory reference_pb_jsvm_hooks): helpers BINNEN elke handler (de
// pool-runtime deelt geen scope), $app en niet e.app, e.bindBody met een
// DynamicModel (een kaal object crasht in Go), record.get() eerst naar String
// dwingen, server draait UTC (hier geen datumrekening). Er zitten geen
// onRecord*-hooks in dit bestand, dus geen e.next()-keten om te breken.
//
// Fouten van binnen runInTransaction verliezen hun statuscode (409 wordt een
// generieke 500); daarom zet de transactie alleen een uitkomst en gooit niets,
// de statuscode komt erna. Zelfde patroon als hh_klussen.pb.js.
//
// VELD toelichting: hh_klus_status.toelichting komt van M6
// (scripts/12-status-velden.mjs). Zolang dat script niet is uitgerold bestaat
// het veld niet en laat PocketBase de waarde stil vallen — de koppeling en de
// logregel zelf werken dan gewoon, alleen zonder toelichting. Rol M6-script 12
// dus eerst uit; scripts/50-koppelcheck.mjs meldt in dry-run of het veld er is.
//
// DEPLOY: scripts/10-hook-deploy.sh (kopie naar /root/pb_hooks/, geen restart;
// PocketBase herlaadt hooks bij een bestandswijziging). ROLLBACK: het bestand
// weer verwijderen uit /root/pb_hooks/.

routerAdd(
  "POST",
  "/api/hh/klussen/{id}/koppelen",
  (e) => {
    const MELDING_GEEN_COORDINATOR =
      "Alleen een coordinator kan een klus handmatig koppelen.";
    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";
    const MELDING_GEEN_JONGERE_MEE = "Kies eerst een helper.";
    const MELDING_BEZET =
      "Deze klus is niet meer open; hij is al aan iemand toegewezen.";
    const MELDING_JONGERE_ONBEKEND = "Deze helper bestaat niet.";
    const MELDING_GEEN_JONGERE = "Deze gebruiker is geen helper.";
    const MELDING_NIET_GOEDGEKEURD =
      "Deze helper is nog niet goedgekeurd en kan geen klussen doen.";
    const MELDING_VOG_VERLOPEN =
      "De VOG van deze helper is verlopen. Eerst een nieuwe VOG, dan koppelen.";

    const klusId = String(e.request.pathValue("id") || "").trim();
    if (!klusId) {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }

    // --- Wie vraagt ---------------------------------------------------------
    const coordinatorId = e.auth.id;
    if (String(e.auth.get("rol") || "") !== "coordinator") {
      return e.json(403, { melding: MELDING_GEEN_COORDINATOR, reden: "rol" });
    }

    // Een kaal object crasht in Go ("Unmarshal non-pointer map"); een
    // DynamicModel met een lege beginwaarde per veld werkt wel.
    const invoer = new DynamicModel({ jongere: "" });
    try {
      e.bindBody(invoer);
    } catch (err) {
      console.log("[hh_coordinator] koppelen: body onleesbaar:", String(err));
    }
    const jongereId = String(invoer.jongere || "").trim();
    if (!jongereId) {
      return e.json(400, {
        melding: MELDING_GEEN_JONGERE_MEE,
        reden: "geenjongere",
      });
    }

    // --- De toewijzing: alles in één transactie -----------------------------
    let uitkomst = "";
    let andereWijk = false;
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
      if (status !== "open" || toegewezen !== "") {
        uitkomst = "bezet";
        return;
      }

      let jongere;
      try {
        jongere = txApp.findRecordById("hh_users", jongereId);
      } catch (_) {
        uitkomst = "jongeronbekend";
        return;
      }
      if (String(jongere.get("rol") || "") !== "jongere") {
        uitkomst = "geenjongere";
        return;
      }
      if (!isGoedgekeurd(txApp, jongereId)) {
        uitkomst = "nietgoedgekeurd";
        return;
      }
      if (isVogVerlopen(txApp, jongereId)) {
        uitkomst = "vogverlopen";
        return;
      }

      // Alleen ter informatie voor de app; koppelen mag over de wijkgrens.
      andereWijk = heeftAndereWijk(txApp, klus, jongere);

      klus.set("toegewezen_jongere", jongereId);
      klus.set("status", "geaccepteerd");
      txApp.save(klus);

      const logCollectie = txApp.findCollectionByNameOrId("hh_klus_status");
      const log = new Record(logCollectie);
      log.set("klus", klus.id);
      log.set("door", coordinatorId);
      log.set("van", "open");
      log.set("naar", "geaccepteerd");
      log.set("toelichting", "handmatig gekoppeld");
      txApp.save(log);

      uitkomst = "ok";
    });

    if (uitkomst === "ok") {
      console.log(
        `[hh_coordinator] coordinator ${coordinatorId} koppelde klus ${klusId} aan jongere ${jongereId}`
      );
      return e.json(200, {
        klus: klusId,
        status: "geaccepteerd",
        toegewezen_jongere: jongereId,
        andere_wijk: andereWijk,
      });
    }
    if (uitkomst === "nietgevonden") {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }
    if (uitkomst === "jongeronbekend") {
      return e.json(409, {
        melding: MELDING_JONGERE_ONBEKEND,
        reden: "jongeronbekend",
      });
    }
    if (uitkomst === "geenjongere") {
      return e.json(409, { melding: MELDING_GEEN_JONGERE, reden: "geenjongere" });
    }
    if (uitkomst === "nietgoedgekeurd") {
      return e.json(409, {
        melding: MELDING_NIET_GOEDGEKEURD,
        reden: "nietgoedgekeurd",
      });
    }
    if (uitkomst === "vogverlopen") {
      return e.json(409, { melding: MELDING_VOG_VERLOPEN, reden: "vogverlopen" });
    }
    return e.json(409, { melding: MELDING_BEZET, reden: "bezet" });

    // ---- helpers, BINNEN de handler (pool-runtime deelt geen scope) ----

    /// Verlopen = vog_geldig_tot ligt vóór vandaag (UTC). De dag zelf telt nog
    /// mee. Leeg veld = geen datum bekend = niet verlopen (seed, oude profielen).
    function isVogVerlopen(txApp, gebruikerId) {
      const rijen = txApp.findRecordsByFilter(
        "hh_profielen",
        "gebruiker = {:gebruiker}",
        "",
        1,
        0,
        { gebruiker: gebruikerId }
      );
      if (rijen.length === 0) return false;
      const geldigTot = String(rijen[0].get("vog_geldig_tot") || "").slice(0, 10);
      if (!geldigTot) return false;
      const nu = new Date();
      const vandaag = new Date(
        Date.UTC(nu.getUTCFullYear(), nu.getUTCMonth(), nu.getUTCDate())
      )
        .toISOString()
        .slice(0, 10);
      return geldigTot < vandaag;
    }

    function isGoedgekeurd(txApp, gebruikerId) {
      const rijen = txApp.findRecordsByFilter(
        "hh_profielen",
        'gebruiker = {:gebruiker} && verificatiestatus = "goedgekeurd"',
        "",
        1,
        0,
        { gebruiker: gebruikerId }
      );
      return rijen.length > 0;
    }

    /// Woont de oudere van de klus in een andere wijk dan de jongere? Een
    /// lege wijk aan een van beide kanten telt als "niet te vergelijken" en
    /// levert dus geen waarschuwing op.
    function heeftAndereWijk(txApp, klus, jongere) {
      const jongereWijk = String(jongere.get("wijk") || "").trim();
      if (!jongereWijk) return false;
      let oudere;
      try {
        oudere = txApp.findRecordById("hh_users", String(klus.get("hulpvrager") || ""));
      } catch (_) {
        return false;
      }
      const oudereWijk = String(oudere.get("wijk") || "").trim();
      if (!oudereWijk) return false;
      return oudereWijk !== jongereWijk;
    }
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------

routerAdd(
  "POST",
  "/api/hh/klussen/{id}/vrijgeven",
  (e) => {
    const MELDING_GEEN_COORDINATOR =
      "Alleen een coordinator kan een klus vrijgeven.";
    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";
    const MELDING_GEEN_REDEN = "Vul eerst een reden in.";
    const MELDING_NIET_VRIJ_TE_GEVEN =
      "Deze klus staat niet op geaccepteerd of onderweg en kan niet worden vrijgegeven.";

    /// Alleen vanuit deze twee statussen mag een klus terug naar open. Bezig,
    /// afgerond en geannuleerd zijn verder in de stroom; die horen bij M6.
    const VRIJ_TE_GEVEN = ["geaccepteerd", "onderweg"];

    /// Even lang als de toelichting in de app; het veld op de server is een
    /// gewoon tekstveld (M6).
    const MAX_REDEN = 200;

    const klusId = String(e.request.pathValue("id") || "").trim();
    if (!klusId) {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }

    const coordinatorId = e.auth.id;
    if (String(e.auth.get("rol") || "") !== "coordinator") {
      return e.json(403, { melding: MELDING_GEEN_COORDINATOR, reden: "rol" });
    }

    const invoer = new DynamicModel({ reden: "" });
    try {
      e.bindBody(invoer);
    } catch (err) {
      console.log("[hh_coordinator] vrijgeven: body onleesbaar:", String(err));
    }
    const reden = String(invoer.reden || "").trim().substring(0, MAX_REDEN);
    if (!reden) {
      return e.json(400, { melding: MELDING_GEEN_REDEN, reden: "geenreden" });
    }

    let uitkomst = "";
    let vanStatus = "";
    $app.runInTransaction((txApp) => {
      let klus;
      try {
        klus = txApp.findRecordById("hh_klussen", klusId);
      } catch (_) {
        uitkomst = "nietgevonden";
        return;
      }
      const status = String(klus.get("status") || "");
      if (VRIJ_TE_GEVEN.indexOf(status) === -1) {
        uitkomst = "nietvrijtegeven";
        return;
      }
      vanStatus = status;

      klus.set("toegewezen_jongere", "");
      klus.set("status", "open");
      txApp.save(klus);

      const logCollectie = txApp.findCollectionByNameOrId("hh_klus_status");
      const log = new Record(logCollectie);
      log.set("klus", klus.id);
      log.set("door", coordinatorId);
      log.set("van", status);
      log.set("naar", "open");
      log.set("toelichting", `vrijgegeven: ${reden}`);
      txApp.save(log);

      uitkomst = "ok";
    });

    if (uitkomst === "ok") {
      console.log(
        `[hh_coordinator] coordinator ${coordinatorId} gaf klus ${klusId} vrij (van ${vanStatus})`
      );
      return e.json(200, { klus: klusId, status: "open", van: vanStatus });
    }
    if (uitkomst === "nietgevonden") {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }
    return e.json(409, {
      melding: MELDING_NIET_VRIJ_TE_GEVEN,
      reden: "nietvrijtegeven",
    });
  },
  $apis.requireAuth("hh_users")
);

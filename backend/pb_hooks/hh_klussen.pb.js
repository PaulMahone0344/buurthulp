// HeitjeHulp M5 — hh_klussen.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Twee dingen, allebei alleen op hh_klussen en hh_klus_status:
//
// 1. POST /api/hh/klussen/{id}/accepteren
//    De ENIGE nette weg waarlangs een jongere een klus aanneemt (M5, keuze 4).
//    Vereist een ingelogde hh_users met rol jongere en een hh_profielen-record
//    met verificatiestatus goedgekeurd. Daarna in EEN transactie: klus opnieuw
//    laden, eisen status = open en toegewezen_jongere leeg en wijk van de
//    oudere = wijk van de jongere, dan toegewezen_jongere = auth.id, status =
//    geaccepteerd, opslaan, en een logregel in hh_klus_status (door = auth.id,
//    van = open, naar = geaccepteerd). Twee jongeren die tegelijk accepteren:
//    de transactie serialiseert, de tweede ziet de klus al bezet en krijgt
//    409 met een Nederlandse melding. Bewezen in scripts/11-accepteercheck.mjs
//    (20 ronden Promise.all). De updateRule-tak "jongere accepteert" in
//    02/06-rules blijft staan als vangnet.
//
//    Antwoorden:
//      200 { klus, status: "geaccepteerd", toegewezen_jongere }
//      401 anoniem ($apis.requireAuth)
//      403 geen jongere, niet goedgekeurd, of geen wijk ingesteld
//      404 klus bestaat niet
//      409 { melding, reden: "bezet" | "wijk" } — al aangenomen, niet meer
//          open, of de oudere woont in een andere wijk
//
// 2. Geocoding (M5, keuze 2). Bij aanmaken van een hh_klussen via de API en bij
//    wijzigen van het adres vraagt de hook Nominatim (OpenStreetMap) om lat/lon
//    en zet die op het record vóór het opslaan. Mislukt het (time-out, geen
//    resultaat, rare respons): lat/lon blijven leeg, er komt een logregel, het
//    aanmaken gaat ALTIJD door. Precies één verzoek per aanmaak of
//    adreswijziging. Records die al lat/lon meekrijgen (03-seed) worden
//    overgeslagen.
//
// Gotchas (memory reference_pb_jsvm_hooks): helpers BINNEN elke handler (de
// pool-runtime deelt geen scope; daarom staat de geocode-helper twee keer),
// $app en niet e.app, e.next() op ELK pad van een onRecord*-hook, server
// draait UTC (hier geen datumrekening), record.get() op een leeg veld eerst
// naar String dwingen.
//
// Fouten van binnen runInTransaction verliezen hun statuscode (409 wordt een
// generieke 500); daarom zet de transactie alleen een uitkomst en gooit niets,
// de statuscode komt erna.
//
// DEPLOY: scripts/10-hook-deploy.sh (kopie naar /root/pb_hooks/, geen restart;
// PocketBase herlaadt hooks bij een bestandswijziging). ROLLBACK: het bestand
// weer verwijderen uit /root/pb_hooks/.

routerAdd(
  "POST",
  "/api/hh/klussen/{id}/accepteren",
  (e) => {
    const MELDING_BEZET = "Deze klus is net door iemand anders aangenomen.";
    const MELDING_WIJK = "Deze klus ligt niet in jouw wijk.";
    const MELDING_GEEN_JONGERE = "Alleen een jongere kan een klus aannemen.";
    const MELDING_NIET_GOEDGEKEURD =
      "Je aanmelding is nog niet goedgekeurd. Je kunt nog geen klussen aannemen.";
    const MELDING_GEEN_WIJK = "Stel eerst je werkgebied in.";
    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";

    const klusId = String(e.request.pathValue("id") || "").trim();
    if (!klusId) {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }

    // --- Wie vraagt (leesacties vóór de transactie) ------------------------
    const jongereId = e.auth.id;
    const rol = String(e.auth.get("rol") || "");
    if (rol !== "jongere") {
      return e.json(403, { melding: MELDING_GEEN_JONGERE, reden: "rol" });
    }
    const wijk = String(e.auth.get("wijk") || "").trim();
    if (!wijk) {
      return e.json(403, { melding: MELDING_GEEN_WIJK, reden: "geenwijk" });
    }
    if (!isGoedgekeurd(jongereId)) {
      return e.json(403, { melding: MELDING_NIET_GOEDGEKEURD, reden: "nietgoedgekeurd" });
    }

    // --- De toewijzing: alles in één transactie ----------------------------
    let uitkomst = "";
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
      let oudere;
      try {
        oudere = txApp.findRecordById("hh_users", String(klus.get("hulpvrager") || ""));
      } catch (_) {
        uitkomst = "bezet";
        return;
      }
      if (String(oudere.get("wijk") || "").trim() !== wijk) {
        uitkomst = "wijk";
        return;
      }

      klus.set("toegewezen_jongere", jongereId);
      klus.set("status", "geaccepteerd");
      txApp.save(klus);

      const logCollectie = txApp.findCollectionByNameOrId("hh_klus_status");
      const log = new Record(logCollectie);
      log.set("klus", klus.id);
      log.set("door", jongereId);
      log.set("van", "open");
      log.set("naar", "geaccepteerd");
      txApp.save(log);

      uitkomst = "ok";
    });

    if (uitkomst === "ok") {
      console.log(`[hh_klussen] jongere ${jongereId} nam klus ${klusId} aan`);
      return e.json(200, {
        klus: klusId,
        status: "geaccepteerd",
        toegewezen_jongere: jongereId,
      });
    }
    if (uitkomst === "nietgevonden") {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }
    if (uitkomst === "wijk") {
      return e.json(409, { melding: MELDING_WIJK, reden: "wijk" });
    }
    return e.json(409, { melding: MELDING_BEZET, reden: "bezet" });

    // ---- helpers, BINNEN de handler (pool-runtime deelt geen scope) ----

    function isGoedgekeurd(gebruikerId) {
      const rijen = $app.findRecordsByFilter(
        "hh_profielen",
        'gebruiker = {:gebruiker} && verificatiestatus = "goedgekeurd"',
        "",
        1,
        0,
        { gebruiker: gebruikerId }
      );
      return rijen.length > 0;
    }
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// Geocoding bij aanmaken (API-create van hh_klussen: oudere, familielid,
// coordinator, superuser/seed). Alleen als er een adres is en er nog geen
// coördinaten meekomen.
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  try {
    const adres = String(e.record.get("adres") || "").trim();
    const lat = Number(e.record.get("lat") || 0);
    const lon = Number(e.record.get("lon") || 0);
    if (adres && lat === 0 && lon === 0) {
      const punt = geocodeer(adres);
      if (punt) {
        e.record.set("lat", punt.lat);
        e.record.set("lon", punt.lon);
      }
    }
  } catch (err) {
    console.log("[hh_klussen] geocoding bij aanmaken overgeslagen:", String(err));
  }
  e.next();

  // ---- helper, BINNEN de handler (pool-runtime deelt geen scope) ----
  function geocodeer(adresTekst) {
    const url =
      "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=nl&q=" +
      encodeURIComponent(adresTekst);
    let res;
    try {
      res = $http.send({
        url: url,
        method: "GET",
        headers: {
          "User-Agent": "HeitjeHulp/0.1 (info@heitjehulp.nl)",
          Accept: "application/json",
        },
        timeout: 5,
      });
    } catch (err) {
      console.log("[hh_klussen] geocoding mislukt (verzoek):", String(err));
      return null;
    }
    if (!res || res.statusCode !== 200) {
      console.log("[hh_klussen] geocoding mislukt (status):", res ? res.statusCode : "geen antwoord");
      return null;
    }
    let lijst = res.json;
    if (!Array.isArray(lijst)) {
      try {
        lijst = JSON.parse(String(res.raw || ""));
      } catch (_) {
        lijst = [];
      }
    }
    if (!Array.isArray(lijst) || lijst.length === 0) {
      console.log("[hh_klussen] geocoding: geen resultaat voor het adres");
      return null;
    }
    const lat = parseFloat(lijst[0].lat);
    const lon = parseFloat(lijst[0].lon);
    if (!isFinite(lat) || !isFinite(lon)) {
      console.log("[hh_klussen] geocoding: onbruikbare coördinaten");
      return null;
    }
    return { lat: lat, lon: lon };
  }
}, "hh_klussen");

// --------------------------------------------------------------------------
// Geocoding bij een adreswijziging (API-update van hh_klussen). Het
// accepteren via de route hierboven loopt niet langs deze hook (txApp.save is
// geen API-request), dus daar wordt nooit gegeocodeerd.
// --------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  try {
    const nieuwAdres = String(e.record.get("adres") || "").trim();
    const oudAdres = String(e.record.original().get("adres") || "").trim();
    if (nieuwAdres && nieuwAdres !== oudAdres) {
      const punt = geocodeer(nieuwAdres);
      if (punt) {
        e.record.set("lat", punt.lat);
        e.record.set("lon", punt.lon);
      } else {
        // Oud adres, oude coördinaten: die kloppen niet meer. Leeg is eerlijker.
        e.record.set("lat", 0);
        e.record.set("lon", 0);
      }
    }
  } catch (err) {
    console.log("[hh_klussen] geocoding bij wijzigen overgeslagen:", String(err));
  }
  e.next();

  // ---- helper, BINNEN de handler (letterlijk gelijk aan hierboven) ----
  function geocodeer(adresTekst) {
    const url =
      "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=nl&q=" +
      encodeURIComponent(adresTekst);
    let res;
    try {
      res = $http.send({
        url: url,
        method: "GET",
        headers: {
          "User-Agent": "HeitjeHulp/0.1 (info@heitjehulp.nl)",
          Accept: "application/json",
        },
        timeout: 5,
      });
    } catch (err) {
      console.log("[hh_klussen] geocoding mislukt (verzoek):", String(err));
      return null;
    }
    if (!res || res.statusCode !== 200) {
      console.log("[hh_klussen] geocoding mislukt (status):", res ? res.statusCode : "geen antwoord");
      return null;
    }
    let lijst = res.json;
    if (!Array.isArray(lijst)) {
      try {
        lijst = JSON.parse(String(res.raw || ""));
      } catch (_) {
        lijst = [];
      }
    }
    if (!Array.isArray(lijst) || lijst.length === 0) {
      console.log("[hh_klussen] geocoding: geen resultaat voor het adres");
      return null;
    }
    const lat = parseFloat(lijst[0].lat);
    const lon = parseFloat(lijst[0].lon);
    if (!isFinite(lat) || !isFinite(lon)) {
      console.log("[hh_klussen] geocoding: onbruikbare coördinaten");
      return null;
    }
    return { lat: lat, lon: lon };
  }
}, "hh_klussen");

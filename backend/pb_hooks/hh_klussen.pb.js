// HeitjeHulp M5 + M6 (+ B2, B4) — hh_klussen.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Alles hieronder raakt alleen hh_klussen en hh_klus_status:
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
//      403 geen jongere, niet goedgekeurd, geen wijk ingesteld, of (B2)
//          { melding, reden } met reden "geboortedatum" (onbekend),
//          "ouder" (onder 18 zonder ouder_toestemming_op), "vog" (18+
//          zonder vog_gezien_op) of "vogverlopen" (vog_geldig_tot vóór
//          vandaag, oude data). Rekenwerk: hh_aanmelden_hulp.js.
//      404 klus bestaat niet
//      409 { melding, reden: "bezet" | "wijk" } — al aangenomen, niet meer
//          open, of de oudere woont in een andere wijk (B2: een regio-wijk
//          als "Tiel en omstreken" past bij elke wijk in dezelfde gemeente)
//      B4: 409 { melding, reden: "nietgekeurd" } — de meldkamer keurde de
//          klus nog niet (klus_goedgekeurd_op leeg)
//      B4: 403 { melding, reden: "leeftijd" } — de helper is op de klusdag
//          jonger dan de categorie of de tijdregel vraagt (07:00-19:00, max
//          2 uur, anders 18+; 10-14 jaar om 18:00 klaar, anders 15+). De route rekent dat zelf opnieuw uit met
//          hh_klusplaatsen_hulp.js en vertrouwt de opgeslagen velden niet.
//
// 1b. M6 — POST /api/hh/klussen/{id}/status  body {naar}
//    De statusmachine, alleen voor de TOEGEWEZEN jongere:
//      geaccepteerd -> onderweg -> bezig -> afgerond
//    Geen stap overslaan, nooit terug. In EEN transactie: klus opnieuw laden,
//    de overgang toetsen, status opslaan, logregel in hh_klus_status (door,
//    van, naar). Tijdstempel = created van de logregel.
//    Antwoorden: 200 {klus, status}; 400 {melding, reden:"naar"} zonder of
//    met een onbekende doelstatus; 401 anoniem; 403 niet de toegewezen
//    jongere; 404 onbekende klus; 409 {melding, reden:"overgang"}.
//    M7: bij de stap naar afgerond rekent de route daarna de reputatie
//    (klussen_aantal en sterren_gemiddeld) van de jongere en de oudere
//    opnieuw uit met hh_reputatie.js. Mislukt dat, dan staat de klus wel op
//    afgerond; de volgende beoordeling zet het getal recht.
//
// 1c. M6 — POST /api/hh/klussen/{id}/annuleren  body {reden}
//    reden verplicht, 5 t/m 300 tekens, komt in hh_klus_status.toelichting.
//    - Oudere (hulpvrager) of geplaatst_door: mag bij open, geaccepteerd,
//      onderweg. De klus gaat naar geannuleerd; de jongere blijft eraan
//      hangen zodat hij ziet wat er met zijn klus gebeurde.
//    - Toegewezen jongere: mag bij geaccepteerd, onderweg. De klus gaat
//      TERUG naar open en toegewezen_jongere wordt leeg, zodat een andere
//      jongere hem kan aannemen: de oudere heeft de hulp nog steeds nodig.
//    - Bij status bezig annuleert niemand; dat wordt "probleem melden" (M8).
//    Antwoorden: 200 {klus, status}; 400 {melding, reden:"reden"}; 401; 403
//    geen deelnemer; 404; 409 {melding, reden:"bezig"|"status"}.
//
// 1d. M6 — GET /api/hh/klussen/{id}/bel
//    Pilotversie van J16. Echt afschermen vraagt een telefoniedienst en kost
//    geld; dat is bewust NIET gebouwd (OPEN-PUNTEN-M6). Geeft {nummer, naam}
//    aan een deelnemer van de klus (oudere, geplaatst_door, toegewezen
//    jongere) en alleen bij status geaccepteerd, onderweg of bezig. De
//    jongere krijgt het nummer van de oudere (hh_users.telefoon, anders
//    contact_telefoon), de oudere dat van de jongere.
//    Antwoorden: 200 {nummer, naam}; 401; 403 geen deelnemer; 404;
//    409 {melding, reden:"status"|"geennummer"}.
//
// 1e. M6 — DE ACHTERDEUR DICHT (backend OPEN-PUNT 15/16, app M5:65).
//    In onRecordUpdateRequest op hh_klussen mag een niet-coordinator via een
//    gewone record-update nog maar EEN statuswissel doen: concept -> open (de
//    oudere die zijn concept plaatst). Elke andere statuswijziging en elke
//    wijziging van toegewezen_jongere via record-update geeft 403. Superuser
//    en coordinator mogen alles. De statusmachine loopt dus altijd langs de
//    routes hierboven, die de logregel zelf schrijven.
//
// 1f. M6 — LOGREGELS SCHRIJFT DE HOOK (backend OPEN-PUNT 16, app M4:32).
//    Bij een API-create van een hh_klussen schrijft de hook zelf de eerste
//    logregel (van = leeg, naar = de status waarmee hij ontstaat) en bij een
//    record-update concept -> open de regel concept -> open. De app schrijft
//    geen logregels meer; hh_klus_status.createRule staat alleen nog open
//    voor de coordinator (13-status-rules.mjs).
//
// 2. Geocoding (M5, keuze 2). ADRES (4 okt): staat de klus op het adres van
//    de bewoner en is dat door PDOK bevestigd (hh_users.lat/lon, adres_bron =
//    pdok), dan neemt de hook dat exacte punt en vraagt hij Nominatim niets.
//    Een ander adres (of een bewoner zonder PDOK-punt): Nominatim zoals hier. Bij aanmaken van een hh_klussen via de API en bij
//    wijzigen van het adres vraagt de hook Nominatim (OpenStreetMap) om lat/lon
//    en zet die op het record vóór het opslaan. Mislukt het (time-out, geen
//    resultaat, rare respons): lat/lon blijven leeg, er komt een logregel, het
//    aanmaken gaat ALTIJD door. Precies één verzoek per aanmaak of
//    adreswijziging. Records die al lat/lon meekrijgen (03-seed) worden
//    overgeslagen.
//
// 3. ADRES (antwoord Ibrahim 4 okt, vraag 3): VAAG VÓÓR DE MATCH.
//    onRecordEnrich (elk antwoord, ook expand en realtime): een helper die
//    niet de toegewezen helper is, krijgt lat/lon ~200 m verschoven (stabiel
//    per klus, uit het klus-id; met HH_VAAG_ZOUT uit de omgeving als geheim),
//    geen adres, en afstand_m = de afstand van zijn eigen (PDOK-)punt tot het
//    ECHTE punt, afgerond op 100 m (alleen als hij een punt heeft), plus
//    locatie_vaag = ja. Na de match: alles exact (zoals voorheen). De bewoner,
//    het familielid, de coordinator en de superuser zien altijd alles.
//    Raden via filters kan niet: een helper die filtert of sorteert op lat,
//    lon, adres, postcode, huisnummer of toevoeging (ook via een relatie)
//    krijgt 400, bij lijsten en bij realtime-abonnementen.
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
// B4: de accepteer-route kijkt ook naar de keuring van de meldkamer en de
// leeftijd (zie 1). Het plaatsen zelf (foto, tijd, leeftijdsgrens, keuren)
// zit in hh_klusplaatsen.pb.js; dat bestand laadt vóór dit bestand en roept
// e.next() aan, zodat de geocoding en de eerste logregel hier gewoon volgen.
//
// B5 (4 okt): de app neemt geen klus meer aan, maar REAGEERT (hh_reacties.pb.js)
// en de bewoner KIEST. Deze route blijft bestaan (vangnet oude app, meldkamer-
// checks); met de schakelaar b5_accepteren_dicht in hh_instellingen op true
// geeft hij elke helper 409 { reden: "reageren" }. Het statusverloop van M6
// verandert niet: kiezen zet de klus op precies dezelfde manier op
// geaccepteerd (zelfde velden, zelfde soort logregel).
//
// DEPLOY: sinds B5 scripts/133-hook-deploy.sh (eerder 10/83/103/123; kopie naar /root/pb_hooks/, geen restart;
// PocketBase herlaadt hooks bij een bestandswijziging). ROLLBACK: het bestand
// weer verwijderen uit /root/pb_hooks/.

routerAdd(
  "POST",
  "/api/hh/klussen/{id}/accepteren",
  (e) => {
    const MELDING_BEZET = "Deze klus is net door iemand anders aangenomen.";
    const MELDING_WIJK = "Deze klus ligt niet in jouw wijk.";
    const MELDING_GEEN_JONGERE = "Alleen een helper kan een klus aannemen.";
    const MELDING_NIET_GOEDGEKEURD =
      "Je aanmelding is nog niet goedgekeurd. Je kunt nog geen klussen aannemen.";
    const MELDING_GEEN_WIJK =
      "HeitjeHulp is nog niet in jouw buurt. We laten het je weten zodra we er zijn.";
    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";
    const MELDING_NIET_GEKEURD = "Deze klus wordt nog nagekeken door de meldkamer.";

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
    // B5: aannemen wordt reageren + de bewoner kiest. Zolang de schakelaar
    // b5_accepteren_dicht (hh_instellingen) uit staat, werkt deze route nog
    // zoals in M5 (oude app, checks 11/14/22/32/50/62/65/82/102/122); staat
    // hij aan, dan krijgt elke helper 409 "reageren". Koppelen door de
    // meldkamer (hh_coordinator.pb.js) blijft altijd werken.
    try {
      const reacties = require(`${__hooks}/hh_reacties_hulp.js`);
      if (reacties.instellingAan($app, reacties.INSTELLING_ACCEPTEREN_DICHT)) {
        const teksten = require(`${__hooks}/hh_reacties_teksten.js`);
        return e.json(409, { melding: teksten.MELDING.reageren, reden: "reageren" });
      }
    } catch (err) {
      // Geen B5-bestanden (rollback van 133): accepteren zoals voorheen.
      console.log("[hh_klussen] schakelaar accepteren niet te lezen:", String(err));
    }
    const wijk = String(e.auth.get("wijk") || "").trim();
    if (!wijk) {
      return e.json(403, { melding: MELDING_GEEN_WIJK, reden: "geenwijk" });
    }
    if (!isGoedgekeurd(jongereId)) {
      return e.json(403, { melding: MELDING_NIET_GOEDGEKEURD, reden: "nietgoedgekeurd" });
    }
    // B2: onder 18 eerst ouder-toestemming, vanaf 18 eerst VOG gezien
    // (vog_gezien_op); een verlopen vog_geldig_tot (oude data) blijft
    // geweigerd. Zie hh_aanmelden_hulp.js klusBlokkade.
    const blokkade = klusBlokkadeVan(e.auth, jongereId);
    if (blokkade) {
      return e.json(403, { melding: blokkade.melding, reden: blokkade.reden });
    }

    // --- De toewijzing: alles in één transactie ----------------------------
    let uitkomst = "";
    let nodigeLeeftijd = 0;
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
      // B2: zelfde wijk, of een regio-wijk ("Tiel en omstreken") in dezelfde
      // gemeente (hh_aanmelden_hulp.js wijkenPassen).
      if (!wijkenPassenVoor(txApp, String(oudere.get("wijk") || "").trim(), wijk)) {
        uitkomst = "wijk";
        return;
      }
      // B4: eerst de meldkamer, dan de leeftijd op de klusdag.
      if (!String(klus.get("klus_goedgekeurd_op") || "").trim()) {
        uitkomst = "nietgekeurd";
        return;
      }
      nodigeLeeftijd = leeftijdNodigVoor(txApp, klus);
      if (nodigeLeeftijd > 0) {
        uitkomst = "leeftijd";
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
    if (uitkomst === "nietgekeurd") {
      return e.json(409, { melding: MELDING_NIET_GEKEURD, reden: "nietgekeurd" });
    }
    if (uitkomst === "leeftijd") {
      return e.json(403, { melding: `Deze klus is pas vanaf ${nodigeLeeftijd} jaar.`, reden: "leeftijd" });
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

    /// B2: { id, gemeente, regio } van twee wijk-ids, en of ze passen.
    function wijkenPassenVoor(app, oudereWijkId, helperWijkId) {
      const hulp = require(`${__hooks}/hh_aanmelden_hulp.js`);
      const lees = (id) => {
        if (!id) return null;
        try {
          const w = app.findRecordById("hh_wijken", id);
          return { id: w.id, gemeente: String(w.get("gemeente") || ""), regio: w.getBool("regio") };
        } catch (_) {
          return null;
        }
      };
      return hulp.wijkenPassen(lees(oudereWijkId), lees(helperWijkId));
    }

    /// B4: hoe oud moet je zijn voor deze klus, als de helper (e.auth) dat
    /// op de klusdag NIET is? 0 = oud genoeg. Rekent opnieuw uit uit de
    /// categorie en de tijden (hh_klusplaatsen_hulp.js), net als de hook die
    /// geboren_uiterlijk zet; zonder begintijd telt vandaag.
    function leeftijdNodigVoor(app, klus) {
      const plaats = require(`${__hooks}/hh_klusplaatsen_hulp.js`);
      let typeMin;
      try {
        typeMin = app.findRecordById("hh_klustypes", String(klus.get("klustype") || "")).getInt("min_leeftijd");
      } catch (_) {
        typeMin = undefined; // onbekende categorie: veilig 18
      }
      const van = String(klus.get("wanneer_van") || "");
      const tot = String(klus.get("wanneer_tot") || "");
      const min = plaats.minLeeftijdVoorKlus({ typeMinLeeftijd: typeMin, van: van, tot: tot });
      const grens = plaats.geborenUiterlijk(van || new Date().toISOString(), min);
      return plaats.isOudGenoeg(String(e.auth.get("geboortedatum") || ""), grens) ? 0 : min;
    }

    /// B2: waarom mag deze goedgekeurde helper nog niet? null = mag.
    /// Leest de geboortedatum en ouder_toestemming_op van het account en
    /// vog_gezien_op/vog_geldig_tot van het profiel (UTC-datum van vandaag).
    function klusBlokkadeVan(auth, gebruikerId) {
      const hulp = require(`${__hooks}/hh_aanmelden_hulp.js`);
      const rijen = $app.findRecordsByFilter(
        "hh_profielen",
        "gebruiker = {:gebruiker}",
        "",
        1,
        0,
        { gebruiker: gebruikerId }
      );
      const profiel = rijen.length ? rijen[0] : null;
      return hulp.klusBlokkade({
        geboortedatum: String(auth.get("geboortedatum") || ""),
        ouderToestemmingOp: String(auth.get("ouder_toestemming_op") || ""),
        vogGezienOp: profiel ? String(profiel.get("vog_gezien_op") || "") : "",
        vogGeldigTot: profiel ? String(profiel.get("vog_geldig_tot") || "") : "",
        vandaag: new Date().toISOString().slice(0, 10),
      });
    }
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// M6 — POST /api/hh/klussen/{id}/status   body {naar}
// De statusmachine. Alleen de toegewezen jongere, alleen één stap vooruit.
// --------------------------------------------------------------------------
routerAdd(
  "POST",
  "/api/hh/klussen/{id}/status",
  (e) => {
    // De enige toegestane overgangen. Verder is niets mogelijk: niet
    // overslaan, niet terug, niet annuleren (dat is een eigen route).
    const VOLGENDE = {
      geaccepteerd: "onderweg",
      onderweg: "bezig",
      bezig: "afgerond",
    };
    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";
    const MELDING_NIET_VAN_JOU = "Deze klus staat niet op jouw naam.";
    const MELDING_OVERGANG =
      "Deze stap kan nu niet meer. Ververs het scherm en probeer het opnieuw.";
    const MELDING_NAAR = "Onbekende volgende stap.";

    const klusId = String(e.request.pathValue("id") || "").trim();
    if (!klusId) {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }

    // Een kaal object werkt niet als doel van bindBody (Go: Unmarshal
    // non-pointer map); elk verwacht veld krijgt een lege beginwaarde.
    const data = new DynamicModel({ naar: "" });
    try {
      e.bindBody(data);
    } catch (err) {
      return e.json(400, { melding: MELDING_NAAR, reden: "naar" });
    }
    const naar = String(data.naar || "").trim();
    if (!naar) {
      return e.json(400, { melding: MELDING_NAAR, reden: "naar" });
    }

    const jongereId = e.auth.id;

    let uitkomst = "";
    let hulpvragerId = "";
    $app.runInTransaction((txApp) => {
      let klus;
      try {
        klus = txApp.findRecordById("hh_klussen", klusId);
      } catch (_) {
        uitkomst = "nietgevonden";
        return;
      }
      const toegewezen = String(klus.get("toegewezen_jongere") || "").trim();
      if (!toegewezen || toegewezen !== jongereId) {
        uitkomst = "nietvanjou";
        return;
      }
      const van = String(klus.get("status") || "");
      if (VOLGENDE[van] !== naar) {
        uitkomst = "overgang";
        return;
      }
      hulpvragerId = String(klus.get("hulpvrager") || "").trim();

      klus.set("status", naar);
      txApp.save(klus);

      const log = new Record(txApp.findCollectionByNameOrId("hh_klus_status"));
      log.set("klus", klus.id);
      log.set("door", jongereId);
      log.set("van", van);
      log.set("naar", naar);
      txApp.save(log);

      uitkomst = "ok";
    });

    // De statuscode komt pas NA de transactie: een fout van binnenuit
    // verliest zijn code en wordt een generieke 500.
    if (uitkomst === "ok") {
      console.log(`[hh_klussen] jongere ${jongereId} zette klus ${klusId} op ${naar}`);
      // M7: een afgeronde klus telt meteen mee in klussen_aantal, ook als
      // er (nog) niemand beoordeelt. Na de transactie: de klus staat er dan
      // al op afgerond, en een fout hier mag de stap nooit terugdraaien.
      if (naar === "afgerond") {
        try {
          const reputatie = require(`${__hooks}/hh_reputatie.js`);
          reputatie.werkReputatieBij($app, jongereId);
          reputatie.werkReputatieBij($app, hulpvragerId);
        } catch (err) {
          console.log("[hh_klussen] reputatie bijwerken na afgerond mislukt:", String(err));
        }
      }
      return e.json(200, { klus: klusId, status: naar });
    }
    if (uitkomst === "nietgevonden") {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }
    if (uitkomst === "nietvanjou") {
      return e.json(403, { melding: MELDING_NIET_VAN_JOU, reden: "nietvanjou" });
    }
    return e.json(409, { melding: MELDING_OVERGANG, reden: "overgang" });
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// M6 — POST /api/hh/klussen/{id}/annuleren   body {reden}
// De oudere annuleert de klus; de jongere geeft hem terug aan de buurt.
// M14: een coordinator (meldkamer) annuleert net als de oudere, ook bij een
// klus die de oudere zelf in de app zette.
// --------------------------------------------------------------------------
routerAdd(
  "POST",
  "/api/hh/klussen/{id}/annuleren",
  (e) => {
    const REDEN_MIN = 5;
    const REDEN_MAX = 300;
    // Bij welke status wie mag annuleren.
    const OUDERE_MAG = { open: 1, geaccepteerd: 1, onderweg: 1 };
    const JONGERE_MAG = { geaccepteerd: 1, onderweg: 1 };

    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";
    const MELDING_GEEN_DEELNEMER = "Je hoort niet bij deze klus.";
    const MELDING_REDEN = `Vul een reden in van ${REDEN_MIN} tot ${REDEN_MAX} tekens.`;
    const MELDING_BEZIG =
      "De klus is al bezig. Bel elkaar even; lukt het niet, meld dan een probleem.";
    const MELDING_STATUS = "Deze klus kan niet meer geannuleerd worden.";

    const klusId = String(e.request.pathValue("id") || "").trim();
    if (!klusId) {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }

    const data = new DynamicModel({ reden: "" });
    try {
      e.bindBody(data);
    } catch (err) {
      return e.json(400, { melding: MELDING_REDEN, reden: "reden" });
    }
    const reden = String(data.reden || "").trim();
    if (reden.length < REDEN_MIN || reden.length > REDEN_MAX) {
      return e.json(400, { melding: MELDING_REDEN, reden: "reden" });
    }

    const authId = e.auth.id;
    const isCoordinator = String(e.auth.get("rol") || "") === "coordinator";

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
      const hulpvrager = String(klus.get("hulpvrager") || "").trim();
      const geplaatstDoor = String(klus.get("geplaatst_door") || "").trim();
      const toegewezen = String(klus.get("toegewezen_jongere") || "").trim();
      // De coordinator annuleert namens de oudere: zelfde regels, zelfde uitkomst.
      const isOudere = authId === hulpvrager || authId === geplaatstDoor || isCoordinator;
      const isJongere = !isOudere && toegewezen !== "" && authId === toegewezen;
      if (!isOudere && !isJongere) {
        uitkomst = "geendeelnemer";
        return;
      }

      const van = String(klus.get("status") || "");
      if (van === "bezig") {
        uitkomst = "bezig";
        return;
      }
      if (isOudere) {
        if (!OUDERE_MAG[van]) {
          uitkomst = "status";
          return;
        }
        nieuweStatus = "geannuleerd";
        klus.set("status", nieuweStatus);
      } else {
        if (!JONGERE_MAG[van]) {
          uitkomst = "status";
          return;
        }
        // Terug de buurt in: de oudere heeft de hulp nog steeds nodig.
        nieuweStatus = "open";
        klus.set("status", nieuweStatus);
        klus.set("toegewezen_jongere", "");
      }
      txApp.save(klus);

      const log = new Record(txApp.findCollectionByNameOrId("hh_klus_status"));
      log.set("klus", klus.id);
      log.set("door", authId);
      log.set("van", van);
      log.set("naar", nieuweStatus);
      log.set("toelichting", reden);
      txApp.save(log);

      uitkomst = "ok";
    });

    if (uitkomst === "ok") {
      console.log(`[hh_klussen] ${authId} annuleerde klus ${klusId} -> ${nieuweStatus}`);
      return e.json(200, { klus: klusId, status: nieuweStatus });
    }
    if (uitkomst === "nietgevonden") {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }
    if (uitkomst === "geendeelnemer") {
      return e.json(403, { melding: MELDING_GEEN_DEELNEMER, reden: "geendeelnemer" });
    }
    if (uitkomst === "bezig") {
      return e.json(409, { melding: MELDING_BEZIG, reden: "bezig" });
    }
    return e.json(409, { melding: MELDING_STATUS, reden: "status" });
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// M6 — GET /api/hh/klussen/{id}/bel
// Pilotversie: het nummer gaat naar de app, die meteen de kiezer opent en het
// nummer NIET als tekst toont. Echt afschermen komt later (OPEN-PUNTEN-M6).
// --------------------------------------------------------------------------
routerAdd(
  "GET",
  "/api/hh/klussen/{id}/bel",
  (e) => {
    const MAG_BIJ = { geaccepteerd: 1, onderweg: 1, bezig: 1 };
    const MELDING_NIET_GEVONDEN = "Deze klus bestaat niet meer.";
    const MELDING_GEEN_DEELNEMER = "Je hoort niet bij deze klus.";
    const MELDING_STATUS = "Bellen kan pas als de klus is aangenomen.";
    const MELDING_GEEN_NUMMER = "Er is geen telefoonnummer bekend.";

    const klusId = String(e.request.pathValue("id") || "").trim();
    if (!klusId) {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }

    let klus;
    try {
      klus = $app.findRecordById("hh_klussen", klusId);
    } catch (_) {
      return e.json(404, { melding: MELDING_NIET_GEVONDEN, reden: "nietgevonden" });
    }

    const authId = e.auth.id;
    const hulpvrager = String(klus.get("hulpvrager") || "").trim();
    const geplaatstDoor = String(klus.get("geplaatst_door") || "").trim();
    const toegewezen = String(klus.get("toegewezen_jongere") || "").trim();
    const isJongere = toegewezen !== "" && authId === toegewezen;
    const isOudere = authId === hulpvrager || authId === geplaatstDoor;
    if (!isJongere && !isOudere) {
      return e.json(403, { melding: MELDING_GEEN_DEELNEMER, reden: "geendeelnemer" });
    }

    const status = String(klus.get("status") || "");
    if (!MAG_BIJ[status]) {
      return e.json(409, { melding: MELDING_STATUS, reden: "status" });
    }

    // De jongere belt de oudere, de oudere belt de jongere.
    const doelId = isJongere ? hulpvrager : toegewezen;
    if (!doelId) {
      return e.json(409, { melding: MELDING_GEEN_NUMMER, reden: "geennummer" });
    }
    let doel;
    try {
      doel = $app.findRecordById("hh_users", doelId);
    } catch (_) {
      return e.json(409, { melding: MELDING_GEEN_NUMMER, reden: "geennummer" });
    }

    let nummer = String(doel.get("telefoon") || "").trim();
    // Alleen bij de oudere is er een contactpersoon als terugval.
    if (!nummer && isJongere) {
      nummer = String(doel.get("contact_telefoon") || "").trim();
    }
    if (!nummer) {
      return e.json(409, { melding: MELDING_GEEN_NUMMER, reden: "geennummer" });
    }

    return e.json(200, { nummer: nummer, naam: String(doel.get("naam") || "") });
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// Geocoding bij aanmaken (API-create van hh_klussen: oudere, familielid,
// coordinator, superuser/seed). Alleen als er een adres is en er nog geen
// coördinaten meekomen. Daarna (M6) de EERSTE logregel: leeg -> status.
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  try {
    const adres = String(e.record.get("adres") || "").trim();
    const lat = Number(e.record.get("lat") || 0);
    const lon = Number(e.record.get("lon") || 0);
    if (adres && lat === 0 && lon === 0) {
      // ADRES: op het (PDOK-)adres van de bewoner -> zijn punt, geen verzoek.
      const punt = puntVanBewoner(e.record, adres) || geocodeer(adres);
      if (punt) {
        e.record.set("lat", punt.lat);
        e.record.set("lon", punt.lon);
      }
    }
  } catch (err) {
    console.log("[hh_klussen] geocoding bij aanmaken overgeslagen:", String(err));
  }
  e.next();

  // M6: de app schrijft geen logregels meer; de hook doet het, ná e.next()
  // (dan pas heeft het record een id). Mislukt het, dan staat de klus er
  // wel: een logboek mag het plaatsen nooit tegenhouden.
  try {
    const naar = String(e.record.get("status") || "");
    if (naar) {
      const log = new Record($app.findCollectionByNameOrId("hh_klus_status"));
      log.set("klus", e.record.id);
      log.set("door", wieSchreefHem(e.record));
      log.set("van", "");
      log.set("naar", naar);
      $app.save(log);
    }
  } catch (err) {
    console.log("[hh_klussen] eerste logregel mislukt:", String(err));
  }

  // ---- helpers, BINNEN de handler (pool-runtime deelt geen scope) ----

  /// door = wie de klus invoerde; altijd een geldige hh_users-verwijzing,
  /// ook als de create van de superuser of een seed komt.
  function wieSchreefHem(record) {
    return String(record.get("geplaatst_door") || record.get("hulpvrager") || "");
  }

  /// ADRES (4 okt): ligt de klus op het door PDOK bevestigde adres van de
  /// bewoner (hh_users.lat/lon, adres_bron = pdok)? Dan dat punt; anders
  /// null en vraagt de hook Nominatim zoals in M5.
  function puntVanBewoner(record, klusAdres) {
    try {
      const id = String(record.get("hulpvrager") || "");
      if (!id) return null;
      const b = $app.findRecordById("hh_users", id);
      const adresHulp = require(`${__hooks}/hh_adres_hulp.js`);
      return adresHulp.puntVoorKlus(klusAdres, {
        adres: String(b.get("adres") || ""),
        postcode: String(b.get("postcode") || ""),
        plaats: String(b.get("plaats") || ""),
        lat: Number(b.get("lat") || 0),
        lon: Number(b.get("lon") || 0),
        adres_bron: String(b.get("adres_bron") || ""),
      });
    } catch (err) {
      console.log("[hh_klussen] punt van de bewoner niet te lezen:", String(err));
      return null;
    }
  }

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
// API-update van hh_klussen. Vier dingen, in deze volgorde:
//   1. M6: de achterdeur dicht — status en toegewezen_jongere zijn voor een
//      niet-coordinator niet meer via een record-update te wijzigen; de ene
//      uitzondering is concept -> open (de oudere plaatst zijn concept).
//   2. M5: geocoding bij een adreswijziging.
//   3. M6: de logregel concept -> open, ná e.next().
//   4. M7: zet de coordinator (of een superuser) een klus op of van
//      afgerond, dan de reputatie van de deelnemers opnieuw uitrekenen.
// Het accepteren en de statusroutes lopen niet langs deze hook (txApp.save is
// geen API-request), dus daar wordt nooit gegeocodeerd en niet dubbel gelogd.
// --------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  const MELDING_STATUS =
    "De status van een klus wijzig je in de app, niet rechtstreeks.";
  const MELDING_TOEWIJZING =
    "Een klus toewijzen of teruggeven gaat via de app, niet rechtstreeks.";

  const vorigeStatus = String(e.record.original().get("status") || "");

  // 1. Achterdeur. Gooien breekt de keten met opzet: het verzoek wordt
  //    geweigerd, er komt niets meer achteraan.
  if (!magAlles(e)) {
    const nieuweStatus = String(e.record.get("status") || "");
    const oudeJongere = String(
      e.record.original().get("toegewezen_jongere") || ""
    ).trim();
    const nieuweJongere = String(e.record.get("toegewezen_jongere") || "").trim();
    if (nieuweJongere !== oudeJongere) {
      throw new ForbiddenError(MELDING_TOEWIJZING);
    }
    if (
      nieuweStatus !== vorigeStatus &&
      !(vorigeStatus === "concept" && nieuweStatus === "open")
    ) {
      throw new ForbiddenError(MELDING_STATUS);
    }
  }

  // 2. Geocoding.
  try {
    const nieuwAdres = String(e.record.get("adres") || "").trim();
    const oudAdres = String(e.record.original().get("adres") || "").trim();
    if (nieuwAdres && nieuwAdres !== oudAdres) {
      // ADRES: op het (PDOK-)adres van de bewoner -> zijn punt, geen verzoek.
      const punt = puntVanBewoner(e.record, nieuwAdres) || geocodeer(nieuwAdres);
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

  // 3. De enige statuswissel die hier nog langskomt, logt de hook zelf.
  try {
    if (vorigeStatus === "concept" && String(e.record.get("status") || "") === "open") {
      const log = new Record($app.findCollectionByNameOrId("hh_klus_status"));
      log.set("klus", e.record.id);
      log.set("door", String(e.record.get("geplaatst_door") || e.record.get("hulpvrager") || ""));
      log.set("van", "concept");
      log.set("naar", "open");
      $app.save(log);
    }
  } catch (err) {
    console.log("[hh_klussen] logregel concept -> open mislukt:", String(err));
  }

  // 4. M7: alleen de coordinator en de superuser komen hier met een andere
  //    status langs (stap 1 houdt de rest tegen). Op of van afgerond: tel
  //    opnieuw, voor de jongere van nu én die van vóór de wijziging.
  try {
    const nieuweStatus = String(e.record.get("status") || "");
    if (
      nieuweStatus !== vorigeStatus &&
      (nieuweStatus === "afgerond" || vorigeStatus === "afgerond")
    ) {
      const reputatie = require(`${__hooks}/hh_reputatie.js`);
      const jongeren = [
        String(e.record.get("toegewezen_jongere") || "").trim(),
        String(e.record.original().get("toegewezen_jongere") || "").trim(),
      ];
      if (jongeren[1] === jongeren[0]) jongeren.pop();
      for (let i = 0; i < jongeren.length; i++) {
        reputatie.werkReputatieBij($app, jongeren[i]);
      }
      reputatie.werkReputatieBij($app, String(e.record.get("hulpvrager") || ""));
    }
  } catch (err) {
    console.log("[hh_klussen] reputatie bijwerken na statuswissel mislukt:", String(err));
  }

  // ---- helpers, BINNEN de handler (pool-runtime deelt geen scope) ----

  /// Mag deze aanvrager alles? Superuser en coordinator wel. Bewust
  /// fail-open: kunnen we de aanvrager niet als gewone hh_users-gebruiker
  /// herkennen, dan laten we hem door. De API-rules zijn de eerste sluis;
  /// deze hook is de tweede. Zo kan een superuser zich nooit buitensluiten
  /// op een server waar ook andere projecten op draaien.
  function magAlles(ev) {
    try {
      if (ev.hasSuperuserAuth && ev.hasSuperuserAuth()) return true;
    } catch (_) {
      // Oudere PocketBase zonder deze methode: verder kijken.
    }
    const auth = ev.auth;
    if (!auth) return true;
    let collectieNaam = "";
    try {
      collectieNaam = String(auth.collection().name || "");
    } catch (_) {
      collectieNaam = "";
    }
    if (collectieNaam && collectieNaam !== "hh_users") return true;
    let rol = "";
    try {
      rol = String(auth.get("rol") || "");
    } catch (_) {
      rol = "";
    }
    return rol === "coordinator";
  }

  /// ADRES (4 okt): ligt de klus op het door PDOK bevestigde adres van de
  /// bewoner (hh_users.lat/lon, adres_bron = pdok)? Dan dat punt; anders
  /// null en vraagt de hook Nominatim zoals in M5.
  function puntVanBewoner(record, klusAdres) {
    try {
      const id = String(record.get("hulpvrager") || "");
      if (!id) return null;
      const b = $app.findRecordById("hh_users", id);
      const adresHulp = require(`${__hooks}/hh_adres_hulp.js`);
      return adresHulp.puntVoorKlus(klusAdres, {
        adres: String(b.get("adres") || ""),
        postcode: String(b.get("postcode") || ""),
        plaats: String(b.get("plaats") || ""),
        lat: Number(b.get("lat") || 0),
        lon: Number(b.get("lon") || 0),
        adres_bron: String(b.get("adres_bron") || ""),
      });
    } catch (err) {
      console.log("[hh_klussen] punt van de bewoner niet te lezen:", String(err));
      return null;
    }
  }

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
// 3. ADRES: vaag vóór de match (antwoord Ibrahim 4 okt, vraag 3)
// --------------------------------------------------------------------------
onRecordEnrich((e) => {
  const kijker = e.requestInfo ? e.requestInfo.auth : null;
  if (!kijker) return e.next();
  const adres = require(`${__hooks}/hh_adres_hulp.js`);
  const wie = {
    id: kijker.id,
    collectie: kijker.collection().name,
    rol: kijker.collection().name === "hh_users" ? String(kijker.get("rol") || "") : "",
  };
  if (!adres.isVoorDeMatch(wie, e.record.get("toegewezen_jongere"))) return e.next();

  const echt = { lat: Number(e.record.get("lat") || 0), lon: Number(e.record.get("lon") || 0) };
  const vaag = adres.vaagPunt(e.record.id, echt, $os.getenv("HH_VAAG_ZOUT") || "");
  e.record.set("lat", vaag ? vaag.lat : 0);
  e.record.set("lon", vaag ? vaag.lon : 0);
  e.record.hide("adres");
  e.record.withCustomData(true);
  e.record.set("locatie_vaag", true);
  const afstand = adres.afstandAfgerond(
    { lat: Number(kijker.get("lat") || 0), lon: Number(kijker.get("lon") || 0) },
    echt
  );
  if (afstand !== null) e.record.set("afstand_m", afstand);
  return e.next();
}, "hh_klussen");

// Raden via filters of sorteren op locatievelden: dicht voor een helper.
onRecordsListRequest((e) => {
  const adres = require(`${__hooks}/hh_adres_hulp.js`);
  const auth = e.auth;
  const isHelper =
    !!auth && auth.collection().name === "hh_users" && String(auth.get("rol") || "") === "jongere";
  if (isHelper) {
    // requestInfo(): e.request is in deze event niet bereikbaar vanuit de JSVM.
    const q = (e.requestInfo() || {}).query || {};
    if (adres.zoektOpLocatie(q.filter, q.sort)) {
      throw new BadRequestError("Filteren of sorteren op de locatie van een klus kan niet.");
    }
  }
  return e.next();
}, "hh_klussen", "hh_meldingen", "hh_klus_status", "hh_berichten", "hh_beoordelingen");

onRealtimeSubscribeRequest((e) => {
  const adres = require(`${__hooks}/hh_adres_hulp.js`);
  const auth = e.auth;
  const isHelper =
    !!auth && auth.collection().name === "hh_users" && String(auth.get("rol") || "") === "jongere";
  if (isHelper) {
    for (const sub of e.subscriptions || []) {
      let tekst = String(sub);
      try {
        tekst = decodeURIComponent(tekst);
      } catch (_) {
        // onleesbaar: dan de ruwe tekst toetsen
      }
      const vraag = tekst.indexOf("?");
      if (vraag >= 0 && adres.zoektOpLocatie(tekst.slice(vraag + 1), "")) {
        throw new BadRequestError("Filteren op de locatie van een klus kan niet.");
      }
    }
  }
  return e.next();
});

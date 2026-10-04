// HeitjeHulp B11 — hh_meldkamer.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Meldkamer en beheerpaneel bijwerken (besluiten Ibrahim 4 okt, zie
// app-plan/PROMPT-B11-MELDKAMER.txt). Het rekenwerk staat in
// hh_meldkamer_hulp.js (getest zonder server: tests/hh_meldkamer_hulp.test.mjs).
//
// 1. hh_users AANMAKEN (onRecordCreateRequest)
//    a. PARTNERCODE: een helper (rol jongere) mag partner_code meesturen (geen
//       veld; de app stuurt hem in de body). Leeg = geen partner. Een actieve
//       partner met die code -> partner gezet. Onbekend/niet actief -> 400
//       met data.partner_code.code "hh_partner_code". Bij een andere rol
//       wordt de code genegeerd. partner zelf meesturen mag alleen de
//       coordinator (rule 151).
//    b. KENNISMAKING: een bewoner (rol hulpvrager) die de MELDKAMER zelf
//       aanmeldt (telefonische ingang) is meteen "gesproken".
// 2. POST /api/hh/meldkamer/kennismaking/{id}  body { besluit, notitie }
//    Alleen coordinator. besluit gesproken | geweigerd. Geweigerd = account
//    geblokkeerd + open/concept-klussen zonder helper geannuleerd (logregel
//    in hh_klus_status). Auditregel in hh_auditlog. 200 { gebruiker,
//    kennismaking_status, geannuleerd, lopend }; 400 besluit/notitie;
//    403 rol; 404; 409 rol (geen bewoner).
// 3. GET /api/hh/meldkamer/partners  -> { partners: [{ id, naam, code, actief,
//    aangemeld, goedgekeurd }] }   (coordinator)
// 4. GET /api/hh/meldkamer/vog       -> { helpers: [{ gebruiker, profiel, naam,
//    leeftijd, verificatiestatus, vog_gezien_op, verloopt_op, reden }] }
//    reden = geen | verlopen (3 jaar na vog_gezien_op)   (coordinator)
// 5. ZELFDE PAAR (onRecordAfterCreateSuccess hh_klus_status, e.next() eerst):
//    naar afgerond + schakelaar b11_zelfde_paar_aan -> eventueel één incident
//    soort "signaal" (geen alarm). Breekt de statuswissel nooit.
// 6. hh_klussen VERRIJKEN (onRecordEnrich): wacht_op_kennismaking = true als
//    de klus nog niet gekeurd is en keuren wacht op de kennismaking
//    (schakelaar b11_kennismaking_verplicht). Keuren zelf: hh_klusplaatsen.pb.js
//    (409 reden "kennismaking").
// 7. hh_users VERRIJKEN: kennismaking_notitie/_door alleen voor de meldkamer;
//    kennismaking_status/_op en partner ook voor de gebruiker zelf.
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app; e.next() op elk pad (een throw is een bewuste weigering); de
// server draait UTC.
//
// DEPLOY: scripts/153-hook-deploy.sh. VOORWAARDE: 150 --apply en 151 --apply.

// --------------------------------------------------------------------------
// 1. hh_users aanmaken: partnercode en kennismaking via de meldkamer
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  const hulp = require(`${__hooks}/hh_meldkamer_hulp.js`);
  const body = e.requestInfo().body || {};
  const rol = String(e.record.get("rol") || "");
  const coordinator = !!e.auth && e.auth.collection().name === "hh_users" && String(e.auth.get("rol") || "") === "coordinator";
  const superuser = !!e.auth && e.auth.collection().name === "_superusers";

  // Gewone aanmelding: de code is de enige weg naar een partner. Coordinator
  // of superuser: een meegestuurde code (zonder partner-id) ook omzetten.
  const gewoon = !coordinator && !superuser;
  const metCode = String(body.partner_code || "").trim() !== "" && String(body.partner || "").trim() === "";
  if (rol === "jongere" && (gewoon || metCode)) {
    const uit = hulp.partnerVoorCode($app, body.partner_code);
    if (!uit.ok) {
      throw new BadRequestError(hulp.MELDING_CODE, { partner_code: new ValidationError("hh_partner_code", hulp.MELDING_CODE) });
    }
    e.record.set("partner", uit.partner);
  }

  if (rol === "hulpvrager") {
    if (coordinator) {
      e.record.set("kennismaking_status", hulp.KENNISMAKING.GESPROKEN);
      e.record.set("kennismaking_op", new DateTime());
      e.record.set("kennismaking_door", e.auth.id);
      e.record.set("kennismaking_notitie", "aangemeld door de meldkamer");
    } else if (!superuser) {
      e.record.set("kennismaking_status", hulp.KENNISMAKING.NOG);
    }
  }
  e.next();
}, "hh_users");

// --------------------------------------------------------------------------
// 2. Kennismaking afvinken
// --------------------------------------------------------------------------
routerAdd(
  "POST",
  "/api/hh/meldkamer/kennismaking/{id}",
  (e) => {
    const hulp = require(`${__hooks}/hh_meldkamer_hulp.js`);
    if (String(e.auth.get("rol") || "") !== "coordinator") {
      return e.json(403, { melding: "Alleen de meldkamer kan dit.", reden: "rol" });
    }
    const data = new DynamicModel({ besluit: "", notitie: "" });
    try {
      e.bindBody(data);
    } catch (_) {
      return e.json(400, { melding: "Kies gesproken of geweigerd.", reden: "besluit" });
    }
    const uit = hulp.kennismaking(
      { app: $app, Record: Record, nu: () => Date.now() },
      {
        coordinatorId: e.auth.id,
        userId: String(e.request.pathValue("id") || "").trim(),
        besluit: data.besluit,
        notitie: data.notitie,
      }
    );
    if (uit.status === 200) {
      console.log(`[hh_meldkamer] coordinator ${e.auth.id}: kennismaking ${uit.body.gebruiker} ${uit.body.kennismaking_status} (${uit.body.geannuleerd} geannuleerd)`);
    }
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// 3. Partners met tellers
// --------------------------------------------------------------------------
routerAdd(
  "GET",
  "/api/hh/meldkamer/partners",
  (e) => {
    const hulp = require(`${__hooks}/hh_meldkamer_hulp.js`);
    if (String(e.auth.get("rol") || "") !== "coordinator") {
      return e.json(403, { melding: "Alleen de meldkamer kan dit.", reden: "rol" });
    }
    return e.json(200, { partners: hulp.partnerTellers($app) });
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// 4. VOG-wachtrij
// --------------------------------------------------------------------------
routerAdd(
  "GET",
  "/api/hh/meldkamer/vog",
  (e) => {
    const hulp = require(`${__hooks}/hh_meldkamer_hulp.js`);
    if (String(e.auth.get("rol") || "") !== "coordinator") {
      return e.json(403, { melding: "Alleen de meldkamer kan dit.", reden: "rol" });
    }
    return e.json(200, { helpers: hulp.vogWachtrij($app, Date.now()) });
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// 5. Zelfde paar: signaal na een afgeronde klus
// --------------------------------------------------------------------------
onRecordAfterCreateSuccess((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_meldkamer_hulp.js`);
    const id = hulp.zelfdePaar({ app: $app, Record: Record, nu: () => Date.now() }, e.record);
    if (id) console.log(`[hh_meldkamer] signaal zelfde paar ${id} na logregel ${e.record.id}`);
  } catch (err) {
    console.log("[hh_meldkamer] zelfde paar mislukt:", String(err));
  }
}, "hh_klus_status");

// --------------------------------------------------------------------------
// 6. Klus verrijken: wacht op de kennismaking?
// --------------------------------------------------------------------------
onRecordEnrich((e) => {
  try {
    const status = String(e.record.get("status") || "");
    if ((status === "open" || status === "concept") && !String(e.record.get("klus_goedgekeurd_op") || "").trim()) {
      const hulp = require(`${__hooks}/hh_meldkamer_hulp.js`);
      if (hulp.wachtOpKennismaking($app, String(e.record.get("hulpvrager") || ""))) {
        e.record.withCustomData(true);
        e.record.set("wacht_op_kennismaking", true);
      }
    }
  } catch (err) {
    console.log("[hh_meldkamer] klus verrijken mislukt:", String(err));
  }
  return e.next();
}, "hh_klussen");

// --------------------------------------------------------------------------
// 7. hh_users verrijken: meldkamer-velden alleen voor de meldkamer
//    notitie en door: alleen coordinator en superuser. Status, datum en
//    partner: ook de gebruiker zelf (de app zegt "De meldkamer belt je").
// --------------------------------------------------------------------------
onRecordEnrich((e) => {
  const kijker = e.requestInfo ? e.requestInfo.auth : null;
  const naam = kijker ? kijker.collection().name : "";
  const meldkamer = naam === "_superusers" || (naam === "hh_users" && String(kijker.get("rol") || "") === "coordinator");
  if (!meldkamer) {
    const eigen = !kijker || kijker.id === e.record.id;
    const verberg = ["kennismaking_notitie", "kennismaking_door"];
    if (!eigen) verberg.push("kennismaking_status", "kennismaking_op", "partner");
    e.record.hide(...verberg);
  }
  return e.next();
}, "hh_users");

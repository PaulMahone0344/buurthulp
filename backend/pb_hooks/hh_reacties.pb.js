// HeitjeHulp B5 — hh_reacties.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Reageren en kiezen (match). Alle rekenwerk en teksten staan in
// hh_reacties_hulp.js en hh_reacties_teksten.js (getest zonder server:
// backend/tests/hh_reacties_hulp.test.mjs). Raakt hh_reacties (130) en via
// $app hh_klussen, hh_klus_status, hh_meldingen, hh_profielen.beschikbaar_tot
// en hh_incidenten. GEEN bestaande rule verandert.
//
// ROUTES
//   POST /api/hh/klussen/{id}/reageren   helper. body { bericht?, ouder_gaat_mee? }
//        Zelfde voorwaarden als accepteren (goedgekeurd, werkgebied, ouder/VOG,
//        keuring meldkamer, leeftijd + tijdvenster). Klus blijft OPEN.
//        < 18: status wacht_op_ouder + mail aan de ouder (B3-mailpad,
//        afzender HeitjeHulp, link https://heitjehulp.nl/#/ouder/klus?token=).
//        18+: status open + gebundelde melding aan de bewoner.
//        200 {melding, reactie, klus, status}; 400 bericht | oudermee;
//        401; 403 rol | geenwijk | nietgoedgekeurd | ouder | vog | leeftijd ...;
//        404; 409 bezet | wijk | nietgekeurd | begonnen | algereageerd |
//        geenouder; 429 limiet (10 open); 502 mail
//   POST /api/hh/reacties/{id}/intrekken  helper, eigen reactie, vóór kiezen.
//        200; 404 nietvanjou; 409 status
//   GET  /api/hh/klussen/{id}/reacties   bewoner van de klus (of meldkamer):
//        de kaarten voor KiesHelper (voornaam, leeftijd, niveau, sterren,
//        aantal, ID gecontroleerd, laatste recensie, berichtje). Nooit
//        achternaam, geboortedatum of adres. 200; 403 geenbewoner; 404
//   POST /api/hh/klussen/{id}/kiezen     body { reactie }. Bewoner (of
//        meldkamer namens hem). EEN transactie: klus open -> geaccepteerd +
//        toegewezen helper, reactie gekozen, rest afgewezen/vervallen,
//        logregel (toelichting "gekozen door de bewoner"). Dezelfde helper
//        kan niet op hetzelfde moment twee klussen krijgen.
//        200 {melding: "Het is een match!", klus, status, toegewezen_jongere,
//        reactie, helper_voornaam}; 400 geenreactie; 403 geenbewoner; 404;
//        409 klusbezet | reactieweg | helperbezet
//   POST /api/hh/ouder/klus              PUBLIEK. body { token } -> stand +
//        wat/waar/wanneer/voornaam bewoner. 404 link; 429 teveel (30/IP/uur)
//   POST /api/hh/ouder/klus/besluit      PUBLIEK. body { token, besluit:
//        "goed" | "lieverniet" }. 400 besluit; 404; 429
//   POST /api/hh/beschikbaar             helper. body { aan } -> "Ik kan nu
//        helpen" = nu + 3 uur (of uit). 200 {beschikbaar_tot, aan}; 403; 409
//   GET  /api/hh/beschikbaar?klustype=&van=&tot=  bewoner: {aantal} helpers
//        die nu kunnen (werkgebied, leeftijd). Alleen een aantal.
//
// HOOKS
//   onRecordAfterCreateSuccess hh_klus_status: na elke statuswissel (ook
//     koppelen, accepteren, annuleren, afkeuren, ouder trekt in) de reacties
//     bijwerken: geaccepteerd -> open afgewezen ("De bewoner koos iemand
//     anders"), geannuleerd -> vervallen ("Klus gaat niet door"), terug naar
//     open -> de gekozen reactie ingetrokken. e.next() EERST.
//   onRecordCreate hh_meldingen (model-hook): "toegewezen" na een keuze van de
//     bewoner wordt "Het is een match!" (de bewoner zelf krijgt hem niet: die
//     koos net); "nieuwe klus" alleen aan wie nu kan helpen ALS de schakelaar
//     b5_nieuwe_klus_alleen_beschikbaar (hh_instellingen) aan staat.
//   onRecordCreateRequest/UpdateRequest hh_profielen: beschikbaar_tot in de
//     body van een gewone gebruiker -> 400 (alleen de route zet hem).
//   onRecordCreateRequest/UpdateRequest hh_beoordelingen: na e.next() de
//     geheime vraag: alles_in_orde = nee -> incident voor de meldkamer.
//   onRecordEnrich hh_beoordelingen: alles_in_orde en geheim_toelichting
//     alleen voor de gever, de coordinator en de superuser.
//   onRecordEnrich hh_klussen: reacties_aantal (en voor een helper
//     mijn_reactie) erbij.
//   onRecordsListRequest hh_beoordelingen / hh_reacties en realtime: filteren
//     op de geheime vraag (iedereen behalve de coordinator) of op de locatie
//     van de klus (helper) -> 400.
//   cronAdd "hh_reacties_vervallen" (elke 10 minuten): wachtende reacties van
//     een begonnen klus vervallen.
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app; e.next() op elk pad behalve een bewuste weigering; de server
// draait UTC. De statuscode van een route komt pas na runInTransaction.
//
// DEPLOY: scripts/133-hook-deploy.sh (dit bestand + hh_reacties_hulp.js +
// hh_reacties_teksten.js + hh_klussen.pb.js). VOORWAARDE: 130 --apply.

routerAdd(
  "POST",
  "/api/hh/klussen/{id}/reageren",
  (e) => {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const data = new DynamicModel({ bericht: "", ouder_gaat_mee: false });
    try {
      e.bindBody(data);
    } catch (_) {
      // Leeg of onleesbaar: dan zonder berichtje en zonder vinkje.
    }
    const helper = $app.findRecordById("hh_users", e.auth.id);
    const uit = hulp.reageer(env, {
      helper: helper,
      klusId: String(e.request.pathValue("id") || ""),
      bericht: String(data.bericht || ""),
      ouderGaatMee: data.ouder_gaat_mee === true,
    });
    if (uit.status === 200) console.log(`[hh_reacties] helper ${e.auth.id} reageerde op klus ${uit.body.klus} (${uit.body.status})`);
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd(
  "POST",
  "/api/hh/reacties/{id}/intrekken",
  (e) => {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const uit = hulp.trekIn(env, { helperId: e.auth.id, reactieId: String(e.request.pathValue("id") || "") });
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd(
  "GET",
  "/api/hh/klussen/{id}/reacties",
  (e) => {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const uit = hulp.reactiesVoorBewoner(env, {
      kijker: { id: e.auth.id, rol: String(e.auth.get("rol") || "") },
      klusId: String(e.request.pathValue("id") || ""),
    });
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd(
  "POST",
  "/api/hh/klussen/{id}/kiezen",
  (e) => {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const data = new DynamicModel({ reactie: "" });
    try {
      e.bindBody(data);
    } catch (_) {
      // Leeg: kies geeft 400 geenreactie.
    }
    const uit = hulp.kies(env, {
      kijker: { id: e.auth.id, rol: String(e.auth.get("rol") || "") },
      klusId: String(e.request.pathValue("id") || ""),
      reactieId: String(data.reactie || ""),
    });
    if (uit.status === 200) console.log(`[hh_reacties] ${e.auth.id} koos helper ${uit.body.toegewezen_jongere} voor klus ${uit.body.klus}`);
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd("POST", "/api/hh/ouder/klus", (e) => {
  const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
  const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
  const data = new DynamicModel({ token: "" });
  try {
    e.bindBody(data);
  } catch (_) {
    // Leeg: 404 link.
  }
  const uit = hulp.ouderStand(env, { token: String(data.token || ""), ip: e.realIP() });
  return e.json(uit.status, uit.body);
});

routerAdd("POST", "/api/hh/ouder/klus/besluit", (e) => {
  const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
  const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
  const data = new DynamicModel({ token: "", besluit: "" });
  try {
    e.bindBody(data);
  } catch (_) {
    // Leeg: 400 besluit.
  }
  const uit = hulp.ouderBesluit(env, { token: String(data.token || ""), besluit: String(data.besluit || ""), ip: e.realIP() });
  return e.json(uit.status, uit.body);
});

routerAdd(
  "POST",
  "/api/hh/beschikbaar",
  (e) => {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const data = new DynamicModel({ aan: false });
    try {
      e.bindBody(data);
    } catch (_) {
      // Onleesbaar: aan blijft false = uitzetten.
    }
    const helper = $app.findRecordById("hh_users", e.auth.id);
    const uit = hulp.zetBeschikbaar(env, { helper: helper, aan: data.aan === true });
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd(
  "GET",
  "/api/hh/beschikbaar",
  (e) => {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const q = e.request.url.query();
    const uit = hulp.telBeschikbaar(env, {
      kijker: { id: e.auth.id, rol: String(e.auth.get("rol") || ""), wijk: String(e.auth.get("wijk") || "") },
      klustypeId: String(q.get("klustype") || ""),
      van: String(q.get("van") || ""),
      tot: String(q.get("tot") || ""),
    });
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

// --------------------------------------------------------------------------
// Na elke statuswissel: de reacties bijwerken.
// --------------------------------------------------------------------------
onRecordAfterCreateSuccess((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const n = hulp.naKlusWissel(env, e.record);
    if (n > 0) console.log(`[hh_reacties] ${n} reactie(s) bijgewerkt na logregel ${e.record.id}`);
  } catch (err) {
    console.log("[hh_reacties] reacties bijwerken na statuswissel mislukt:", String(err));
  }
}, "hh_klus_status");

// --------------------------------------------------------------------------
// Meldingen nakijken: match-tekst, en "nieuwe klus" alleen aan wie nu kan.
// --------------------------------------------------------------------------
onRecordCreate((e) => {
  let opslaan = true;
  try {
    const soort = String(e.record.get("soort") || "");
    if (soort === "toegewezen" || soort === "nieuwe_klus") {
      const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
      const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
      const uit = hulp.nakijkenMelding(env, e.record);
      opslaan = uit.opslaan !== false;
      if (uit.titel) e.record.set("titel", uit.titel);
      if (uit.tekst) e.record.set("tekst", uit.tekst.slice(0, 600));
    }
  } catch (err) {
    // Een fout hier mag een melding nooit tegenhouden.
    console.log("[hh_reacties] melding nakijken mislukt:", String(err));
    opslaan = true;
  }
  if (!opslaan) return; // bewust: deze melding wordt niet opgeslagen
  e.next();
}, "hh_meldingen");

// --------------------------------------------------------------------------
// beschikbaar_tot zet alleen de route (of de meldkamer / superuser).
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  weigerBeschikbaarVeld(e);
  e.next();

  function weigerBeschikbaarVeld(ev) {
    const teksten = require(`${__hooks}/hh_reacties_teksten.js`);
    let beheer = false;
    try {
      beheer = !!(ev.hasSuperuserAuth && ev.hasSuperuserAuth());
    } catch (_) {
      beheer = false;
    }
    if (!beheer && ev.auth && ev.auth.collection().name === "hh_users") {
      beheer = String(ev.auth.get("rol") || "") === "coordinator";
    }
    const body = ev.requestInfo().body || {};
    if (!beheer && body.beschikbaar_tot !== undefined) throw new BadRequestError(teksten.MELDING.beschikbaarVeld);
  }
}, "hh_profielen");

onRecordUpdateRequest((e) => {
  weigerBeschikbaarVeld(e);
  e.next();

  function weigerBeschikbaarVeld(ev) {
    const teksten = require(`${__hooks}/hh_reacties_teksten.js`);
    let beheer = false;
    try {
      beheer = !!(ev.hasSuperuserAuth && ev.hasSuperuserAuth());
    } catch (_) {
      beheer = false;
    }
    if (!beheer && ev.auth && ev.auth.collection().name === "hh_users") {
      beheer = String(ev.auth.get("rol") || "") === "coordinator";
    }
    const body = ev.requestInfo().body || {};
    if (!beheer && body.beschikbaar_tot !== undefined) throw new BadRequestError(teksten.MELDING.beschikbaarVeld);
  }
}, "hh_profielen");

// --------------------------------------------------------------------------
// Geheime vraag na de klus: "nee" -> incident voor de meldkamer.
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    if (hulp.verwerkGeheim(env, e.record)) console.log(`[hh_reacties] geheime vraag "nee" bij beoordeling ${e.record.id}: incident gemaakt`);
  } catch (err) {
    console.log("[hh_reacties] geheime vraag verwerken mislukt:", String(err));
  }
}, "hh_beoordelingen");

onRecordUpdateRequest((e) => {
  e.next();
  try {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    if (hulp.verwerkGeheim(env, e.record)) console.log(`[hh_reacties] geheime vraag "nee" bij beoordeling ${e.record.id}: incident gemaakt`);
  } catch (err) {
    console.log("[hh_reacties] geheime vraag verwerken mislukt:", String(err));
  }
}, "hh_beoordelingen");

onRecordEnrich((e) => {
  const kijker = e.requestInfo ? e.requestInfo.auth : null;
  let magZien = false;
  if (kijker) {
    const naam = kijker.collection().name;
    magZien =
      naam === "_superusers" ||
      (naam === "hh_users" &&
        (String(kijker.get("rol") || "") === "coordinator" || kijker.id === String(e.record.get("van_gebruiker") || "")));
  }
  if (!magZien) e.record.hide("alles_in_orde", "geheim_toelichting");
  return e.next();
}, "hh_beoordelingen");

// --------------------------------------------------------------------------
// Klus verrijken: hoeveel helpers reageerden (en de eigen stand).
// --------------------------------------------------------------------------
onRecordEnrich((e) => {
  try {
    const kijker = e.requestInfo ? e.requestInfo.auth : null;
    if (kijker && kijker.collection().name === "hh_users") {
      const rol = String(kijker.get("rol") || "");
      if (rol === "jongere" || rol === "hulpvrager") {
        const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
        const extra = hulp.verrijkKlus({ app: $app }, { kijker: { id: kijker.id, rol: rol }, klus: e.record });
        if (extra) {
          e.record.withCustomData(true);
          for (const k in extra) e.record.set(k, extra[k]);
        }
      }
    }
  } catch (err) {
    console.log("[hh_reacties] klus verrijken mislukt:", String(err));
  }
  return e.next();
}, "hh_klussen");

// --------------------------------------------------------------------------
// Raden dicht: filteren op de geheime vraag (niet-coordinator) of op de
// locatie van de klus via een reactie (helper).
// --------------------------------------------------------------------------
onRecordsListRequest((e) => {
  const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
  const adres = require(`${__hooks}/hh_adres_hulp.js`);
  const auth = e.auth;
  const isGebruiker = !!auth && auth.collection().name === "hh_users";
  const rol = isGebruiker ? String(auth.get("rol") || "") : "";
  const q = (e.requestInfo() || {}).query || {};
  if (isGebruiker && rol !== "coordinator" && hulp.zoektOpGeheim(q.filter, q.sort)) {
    throw new BadRequestError("Filteren of sorteren op de geheime vraag kan niet.");
  }
  if (isGebruiker && rol === "jongere" && adres.zoektOpLocatie(q.filter, q.sort)) {
    throw new BadRequestError("Filteren of sorteren op de locatie van een klus kan niet.");
  }
  return e.next();
}, "hh_beoordelingen", "hh_reacties");

onRealtimeSubscribeRequest((e) => {
  const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
  const auth = e.auth;
  const isGebruiker = !!auth && auth.collection().name === "hh_users";
  if (isGebruiker && String(auth.get("rol") || "") !== "coordinator") {
    for (const sub of e.subscriptions || []) {
      let t = String(sub);
      try {
        t = decodeURIComponent(t);
      } catch (_) {
        // onleesbaar: de ruwe tekst toetsen
      }
      const vraag = t.indexOf("?");
      if (vraag >= 0 && hulp.zoektOpGeheim(t.slice(vraag + 1), "")) {
        throw new BadRequestError("Filteren op de geheime vraag kan niet.");
      }
    }
  }
  return e.next();
});

// --------------------------------------------------------------------------
// Elke 10 minuten: wachtende reacties van een begonnen klus vervallen.
// --------------------------------------------------------------------------
cronAdd("hh_reacties_vervallen", "*/10 * * * *", () => {
  try {
    const hulp = require(`${__hooks}/hh_reacties_hulp.js`);
    const env = hulp.hookOmgeving({ require: require, hooks: __hooks, app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const n = hulp.vervalVerlopen(env);
    if (n > 0) console.log(`[hh_reacties] ${n} wachtende reactie(s) vervallen (klus begonnen)`);
  } catch (err) {
    console.log("[hh_reacties] vervallen mislukt:", String(err));
  }
});

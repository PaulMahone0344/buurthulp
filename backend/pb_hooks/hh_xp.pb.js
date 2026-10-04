// HeitjeHulp B9 — hh_xp.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Routes voor XP, niveaus, badges, verdiensten, de "Verklaring van inzet" en
// recensie verbergen. Het rekenen staat in hh_xp_regels.js, het lezen/
// schrijven in hh_xp_hulp.js (beide gewone .js, geen hook; getest zonder
// server in backend/tests/hh_xp_*.test.mjs). XP BOEKEN gebeurt niet hier
// maar op de plekken waar een klus afgerond raakt of een beoordeling
// verandert (hh_klussen.pb.js en hh_beoordelingen.pb.js roepen
// hh_xp_hulp.werkXpBij aan, ná de reputatie).
//
//   GET  /api/hh/xp/mijn                  helper: alles voor HProfiel, het
//        Start-blok en "Mijn verdiensten" (XP, niveau, volgend niveau,
//        badges, vertrouwensbadges met datum, verdiensten, recensies).
//   POST /api/hh/xp/verklaring            helper: maakt (of hergebruikt) een
//        Verklaring van inzet -> { code, uitgegeven_op, gegevens }.
//   GET  /api/hh/verklaring/{code}        PUBLIEK (30 per IP per uur): wat er
//        op de verklaring met die controlecode stond. Voor de meldkamer
//        (paneel) en wie de verklaring krijgt; er staat alleen de voornaam op.
//   POST /api/hh/beoordelingen/{id}/verbergen  {verborgen, reden}  coordinator:
//        recensie verbergen of terugzetten; daarna reputatie + XP opnieuw.
//   POST /api/hh/xp/naberekenen  {droog}  ALLEEN superuser (script 144).
//   onRecordEnrich hh_beoordelingen: verborgen_door en verborgen_reden alleen
//        voor de coordinator en de superuser.
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app; e.next() op elk pad; record.get() naar String/Number.
//
// DEPLOY: scripts/143-hook-deploy.sh. VOORWAARDE: 140 --apply (collecties
// hh_xp, hh_badges, hh_verklaringen en de velden) en 141 --apply.

routerAdd(
  "GET",
  "/api/hh/xp/mijn",
  (e) => {
    const xp = require(`${__hooks}/hh_xp_hulp.js`);
    if (String(e.auth.get("rol") || "") !== "jongere") {
      return e.json(403, { melding: "Alleen voor strijders.", reden: "geenhelper" });
    }
    const uit = xp.overzicht({ app: $app, nu: () => Date.now() }, e.auth.id);
    return e.json(200, uit);
  },
  $apis.requireAuth("hh_users")
);

routerAdd(
  "POST",
  "/api/hh/xp/verklaring",
  (e) => {
    const xp = require(`${__hooks}/hh_xp_hulp.js`);
    if (String(e.auth.get("rol") || "") !== "jongere") {
      return e.json(403, { melding: "Alleen voor strijders.", reden: "geenhelper" });
    }
    const env = {
      app: $app,
      Record: Record,
      nu: () => Date.now(),
      willekeurig: (n) => $security.randomStringWithAlphabet(n, xp.CODE_TEKENS),
    };
    try {
      const uit = xp.verklaringMaken(env, e.auth.id);
      console.log(`[hh_xp] verklaring ${uit.code} voor helper ${e.auth.id}`);
      return e.json(200, uit);
    } catch (err) {
      console.log("[hh_xp] verklaring maken mislukt:", String(err));
      return e.json(500, { melding: "De verklaring lukt nu niet. Probeer het later nog eens.", reden: "mislukt" });
    }
  },
  $apis.requireAuth("hh_users")
);

routerAdd("GET", "/api/hh/verklaring/{code}", (e) => {
  const xp = require(`${__hooks}/hh_xp_hulp.js`);
  const MAX_PER_IP_PER_UUR = 30;
  const sleutel = "hh_verklaring_ip:" + String(e.realIP() || "onbekend") + ":" + Math.floor(Date.now() / 3600000);
  const store = $app.store();
  const aantal = Number(store.get(sleutel) || 0);
  if (aantal >= MAX_PER_IP_PER_UUR) {
    return e.json(429, { melding: "Te vaak geprobeerd. Probeer het over een uur nog eens.", reden: "limiet" });
  }
  store.set(sleutel, aantal + 1);
  const uit = xp.verklaringOpzoeken({ app: $app }, String(e.request.pathValue("code") || ""));
  if (!uit) {
    return e.json(404, { melding: "Deze code kennen we niet. Kijk of je hem goed hebt overgenomen.", reden: "onbekend" });
  }
  return e.json(200, uit);
});

routerAdd(
  "POST",
  "/api/hh/beoordelingen/{id}/verbergen",
  (e) => {
    const xp = require(`${__hooks}/hh_xp_hulp.js`);
    const data = new DynamicModel({ verborgen: true, reden: "" });
    try {
      e.bindBody(data);
    } catch (_) {
      // Leeg: verbergen zonder reden.
    }
    const env = { app: $app, Record: Record, nu: () => Date.now() };
    const kijker = { id: e.auth.id, rol: String(e.auth.get("rol") || "") };
    const uit = xp.recensieVerbergen(env, kijker, String(e.request.pathValue("id") || ""), data.verborgen !== false, String(data.reden || ""));
    if (uit.status === 200) {
      // Sterren en XP opnieuw (een fout hier draait het verbergen niet terug).
      try {
        const reputatie = require(`${__hooks}/hh_reputatie.js`);
        reputatie.werkReputatieBij($app, uit.body.naar_gebruiker);
        xp.werkXpBij(env, uit.body.naar_gebruiker);
      } catch (err) {
        console.log("[hh_xp] herberekenen na verbergen mislukt:", String(err));
      }
      console.log(`[hh_xp] coordinator ${e.auth.id} zette beoordeling ${uit.body.beoordeling} verborgen=${uit.body.verborgen}`);
    }
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd(
  "POST",
  "/api/hh/xp/naberekenen",
  (e) => {
    const xp = require(`${__hooks}/hh_xp_hulp.js`);
    const data = new DynamicModel({ droog: true });
    try {
      e.bindBody(data);
    } catch (_) {
      // Leeg: droog (veilig).
    }
    const droog = data.droog !== false;
    const env = { app: $app, Record: Record, nu: () => Date.now() };
    const uit = xp.naberekenen(env, { droog: droog });
    console.log(`[hh_xp] naberekenen droog=${droog}: ${uit.length} helper(s)`);
    return e.json(200, { droog: droog, helpers: uit });
  },
  $apis.requireSuperuserAuth()
);

onRecordEnrich((e) => {
  const kijker = e.requestInfo ? e.requestInfo.auth : null;
  let magZien = false;
  if (kijker) {
    const naam = kijker.collection().name;
    magZien = naam === "_superusers" || (naam === "hh_users" && String(kijker.get("rol") || "") === "coordinator");
  }
  if (!magZien) e.record.hide("verborgen_door", "verborgen_reden");
  return e.next();
}, "hh_beoordelingen");

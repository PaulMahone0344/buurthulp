// HeitjeHulp B3 — hh_ouder.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Ouder-toestemming met een code. Alleen routes; al het rekenwerk en de
// teksten staan in hh_ouder_hulp.js (getest zonder server en zonder mail:
// backend/tests/hh_ouder_hulp.test.mjs). Raakt alleen hh_ouder_toestemming
// (script 90) en de velden ouder_email, ouder_toestemming_op en
// ouder_iban_ok op hh_users (B1, script 70). Alles via $app: de collectie
// zelf is alleen leesbaar voor de coordinator en voor niemand schrijfbaar.
//
//   POST /api/hh/ouder/versturen    ingelogde helper (rol jongere) onder 18
//        body { ouder_email? }       200 {melding, status, ouder_email,
//                                    verstuurd_op, code_verloopt_op,
//                                    nog_te_sturen}; 400 email | eigenadres;
//                                    401; 403 rol; 409 geboortedatum |
//                                    volwassen | algegeven; 429 limiet (3 per
//                                    dag); 502 mail
//   GET  /api/hh/ouder/status       ingelogde helper: wat de app toont
//   POST /api/hh/ouder/code         PUBLIEK. body { email, code } of { token }
//                                    200 {status, voornaam, sessie?};
//                                    400 invoer | code; 404 link;
//                                    429 geblokkeerd (5 fout) | teveel (IP)
//   POST /api/hh/ouder/toestemming  PUBLIEK met ouder-sessie.
//        body { sessie, naam, iban, akkoord, avp }
//                                    200 {status: gegeven, ...}; 400 akkoord |
//                                    naam | iban; 401 sessie; 409 status
//   POST /api/hh/ouder/intrekken    PUBLIEK met link-token (altijd geldig) of
//        body { token } | { sessie }  ouder-sessie. 200 {status: ingetrokken}
//
// MAIL (K4): $app.newMailClient() met de bestaande globale SMTP-instelling
// van de server. Dit bestand wijzigt GEEN instelling. Afzender (besluit 4
// okt): naam altijd "HeitjeHulp"; adres uit HH_MAIL_AFZENDER (systemd-env
// van pocketbase, bedoeld info@heitjehulp.nl, dan ook Reply-To), anders het
// adres uit de globale instelling (hh_ouder_hulp.js afzenderVoor). Adressen op .invalid/.test/.example/.localhost krijgen nooit
// mail (92-b3check gebruikt ...@heitjehulp.invalid).
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app; de server draait UTC.
//
// DEPLOY: scripts/93-hook-deploy.sh (NIEUW, samen met hh_ouder_hulp.js).
// VOORWAARDE: 90-b3-collectie.mjs --apply (anders 500 op elke route).

routerAdd(
  "POST",
  "/api/hh/ouder/versturen",
  (e) => {
    const hulp = require(`${__hooks}/hh_ouder_hulp.js`);
    const aanmelden = require(`${__hooks}/hh_aanmelden_hulp.js`);
    const data = new DynamicModel({ ouder_email: "" });
    try {
      e.bindBody(data);
    } catch (_) {
      // Leeg of onleesbaar: dan het bewaarde adres van de helper.
    }
    const helper = $app.findRecordById("hh_users", e.auth.id);
    const vandaag = new Date().toISOString().slice(0, 10);
    const env = hulp.jsvmOmgeving({ app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const uit = hulp.verstuur(env, {
      helper: helper,
      leeftijd: aanmelden.leeftijd(String(helper.get("geboortedatum") || ""), vandaag),
      ouderEmail: String(data.ouder_email || ""),
    });
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd(
  "GET",
  "/api/hh/ouder/status",
  (e) => {
    const hulp = require(`${__hooks}/hh_ouder_hulp.js`);
    const aanmelden = require(`${__hooks}/hh_aanmelden_hulp.js`);
    const helper = $app.findRecordById("hh_users", e.auth.id);
    if (String(helper.get("rol") || "") !== "jongere") {
      return e.json(403, { melding: hulp.MELDING.rol, reden: "rol" });
    }
    const vandaag = new Date().toISOString().slice(0, 10);
    const env = hulp.jsvmOmgeving({ app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
    const uit = hulp.statusVoorHelper(env, {
      helper: helper,
      leeftijd: aanmelden.leeftijd(String(helper.get("geboortedatum") || ""), vandaag),
    });
    return e.json(uit.status, uit.body);
  },
  $apis.requireAuth("hh_users")
);

routerAdd("POST", "/api/hh/ouder/code", (e) => {
  const hulp = require(`${__hooks}/hh_ouder_hulp.js`);
  const data = new DynamicModel({ email: "", code: "", token: "" });
  try {
    e.bindBody(data);
  } catch (_) {
    // Leeg of onleesbaar: controleerCode geeft dan 400 invoer.
  }
  const env = hulp.jsvmOmgeving({ app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
  const uit = hulp.controleerCode(env, {
    email: String(data.email || ""),
    code: String(data.code || ""),
    token: String(data.token || ""),
    ip: e.realIP(),
  });
  return e.json(uit.status, uit.body);
});

routerAdd("POST", "/api/hh/ouder/toestemming", (e) => {
  const hulp = require(`${__hooks}/hh_ouder_hulp.js`);
  const data = new DynamicModel({ sessie: "", naam: "", iban: "", akkoord: false, avp: false });
  try {
    e.bindBody(data);
  } catch (_) {
    // Onleesbaar (bv. akkoord als tekst): akkoord blijft false -> 400.
  }
  const env = hulp.jsvmOmgeving({ app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
  const uit = hulp.geefToestemming(env, {
    sessie: String(data.sessie || ""),
    naam: String(data.naam || ""),
    iban: String(data.iban || ""),
    akkoord: data.akkoord === true,
    avp: data.avp === true,
    ip: e.realIP(),
  });
  return e.json(uit.status, uit.body);
});

routerAdd("POST", "/api/hh/ouder/intrekken", (e) => {
  const hulp = require(`${__hooks}/hh_ouder_hulp.js`);
  const data = new DynamicModel({ token: "", sessie: "" });
  try {
    e.bindBody(data);
  } catch (_) {
    // Leeg: trekIn geeft 400.
  }
  const env = hulp.jsvmOmgeving({ app: $app, Record: Record, security: $security, MailerMessage: MailerMessage, os: $os });
  const uit = hulp.trekIn(env, {
    token: String(data.token || ""),
    sessie: String(data.sessie || ""),
    ip: e.realIP(),
  });
  return e.json(uit.status, uit.body);
});

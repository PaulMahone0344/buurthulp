// HeitjeHulp M9 — hh_familie_hulp.js (hulpbestand, GEEN hook)
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. De
// handlers in hh_familie.pb.js halen dit bestand BINNEN de handler op met
//   const hulp = require(`${__hooks}/hh_familie_hulp.js`);
// De aanroeper geeft een omgeving { app: $app, Record: Record } mee, zodat
// dit bestand niet op de globals van de JSVM leunt.
//
// DE AANVRAAG (backend OPEN-PUNT 19)
//   Het familielid vraagt aan met het e-mailadres van de oudere. Bestaat er
//   een oudere (rol hulpvrager) met dat adres en is er nog geen koppeling,
//   dan komt er een koppeling met status "aangevraagd" en lege rechten. Het
//   antwoord is ALTIJD hetzelfde vaste bericht, ook bij een onbekend adres,
//   een jongere of een bestaande koppeling: nooit verklappen wie klant is.
//   Hooguit 5 aanvragen per familielid per UTC-dag, ook voor onbekende
//   adressen (anders kun je alsnog adressen aflopen).
//
// DE TELLER: in $app.store() (geheugen van de server, per dag per
// familielid), met als ondergrens het aantal koppelingen dat dit
// familielid vandaag maakte (dat overleeft een herstart). Een herstart zet
// dus alleen de pogingen op ONBEKENDE adressen terug; zie OPEN-PUNTEN-M9.

const MAX_PER_DAG = 5;
const ALLE_RECHTEN = ["meekijken", "plaatsen"];

const VAST_BERICHT =
  "Als dit adres bij ons bekend is, krijgt je familielid een vraag om toestemming.";
const MELDING_EMAIL = "Vul een geldig e-mailadres in.";
const MELDING_LIMIET =
  "Je hebt vandaag al vaak een aanvraag gedaan. Probeer het morgen opnieuw.";
const MELDING_ROL = "Alleen een familielid kan een koppeling aanvragen.";

// --------------------------------------------------------------------------
// PUUR
// --------------------------------------------------------------------------

function normaliseerEmail(waarde) {
  return String(waarde || "").trim().toLowerCase();
}

/// Eenvoudige vorm: iets@iets.iets, zonder spaties. De server zoekt daarna
/// letterlijk; een strengere controle voegt niets toe.
function isGeldigEmail(waarde) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(waarde || ""));
}

function tweeCijfers(n) {
  return n < 10 ? "0" + n : String(n);
}

/// "2026-09-27": de dag in UTC (de server draait op UTC).
function dagSleutel(ms) {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${tweeCijfers(d.getUTCMonth() + 1)}-${tweeCijfers(d.getUTCDate())}`;
}

/// Het begin van die UTC-dag in de vorm waarin PocketBase datums bewaart.
function dagBeginIso(ms) {
  return `${dagSleutel(ms)} 00:00:00.000Z`;
}

/// Rechten uit een verzoek, of de standaard (beide) als er niets is.
function rechtenOfStandaard(rechten) {
  if (!rechten) return ALLE_RECHTEN.slice();
  const lijst = [];
  for (let i = 0; i < rechten.length; i++) lijst.push(String(rechten[i]));
  return lijst.length ? lijst : ALLE_RECHTEN.slice();
}

function antwoord(status, melding, reden) {
  const body = { melding: melding };
  if (reden) body.reden = reden;
  return { status: status, body: body };
}

// --------------------------------------------------------------------------
// MET app
// --------------------------------------------------------------------------

function zoekEerste(app, collectie, filter, params) {
  try {
    return app.findFirstRecordByFilter(collectie, filter, params);
  } catch (_) {
    return null;
  }
}

/// Hoeveel aanvragen dit familielid vandaag al deed.
function pogingenVandaag(env, familielidId, nu) {
  let uitGeheugen = 0;
  try {
    uitGeheugen = Number(env.app.store().get(`hh_aanvragen:${familielidId}:${dagSleutel(nu)}`) || 0);
  } catch (_) {
    uitGeheugen = 0;
  }
  let uitDatabase = 0;
  try {
    uitDatabase = env.app.findRecordsByFilter(
      "hh_koppelingen",
      "familielid = {:familielid} && created >= {:vanaf}",
      "",
      0,
      0,
      { familielid: familielidId, vanaf: dagBeginIso(nu) }
    ).length;
  } catch (_) {
    uitDatabase = 0;
  }
  return Math.max(uitGeheugen, uitDatabase);
}

function telPoging(env, familielidId, nu, aantal) {
  try {
    env.app.store().set(`hh_aanvragen:${familielidId}:${dagSleutel(nu)}`, aantal);
  } catch (_) {
    // Geen geheugen: de database-telling blijft de ondergrens.
  }
}

/// De hele aanvraag. Geeft { status, body }; de route zet dat om in e.json.
///   invoer = { familielidId, rol, email, nu (ms) }
function verwerkAanvraag(env, invoer) {
  if (invoer.rol !== "familie") return antwoord(403, MELDING_ROL, "rol");
  const email = normaliseerEmail(invoer.email);
  if (!isGeldigEmail(email)) return antwoord(400, MELDING_EMAIL, "email");

  const eerder = pogingenVandaag(env, invoer.familielidId, invoer.nu);
  if (eerder >= MAX_PER_DAG) return antwoord(429, MELDING_LIMIET, "limiet");
  telPoging(env, invoer.familielidId, invoer.nu, eerder + 1);

  const oudere = zoekEerste(env.app, "hh_users", 'email = {:email} && rol = "hulpvrager"', {
    email: email,
  });
  if (oudere) {
    const bestaat = zoekEerste(
      env.app,
      "hh_koppelingen",
      "oudere = {:oudere} && familielid = {:familielid}",
      { oudere: oudere.id, familielid: invoer.familielidId }
    );
    if (!bestaat) {
      try {
        const record = new env.Record(env.app.findCollectionByNameOrId("hh_koppelingen"));
        record.set("oudere", oudere.id);
        record.set("familielid", invoer.familielidId);
        record.set("status", "aangevraagd");
        record.set("rechten", []);
        env.app.save(record);
      } catch (err) {
        // Ook een botsing op de unieke index geeft het vaste bericht.
        console.log("[hh_familie] aanvraag opslaan mislukt:", String(err));
      }
    }
  }
  return antwoord(200, VAST_BERICHT);
}

module.exports = {
  MAX_PER_DAG: MAX_PER_DAG,
  ALLE_RECHTEN: ALLE_RECHTEN,
  VAST_BERICHT: VAST_BERICHT,
  normaliseerEmail: normaliseerEmail,
  isGeldigEmail: isGeldigEmail,
  dagSleutel: dagSleutel,
  dagBeginIso: dagBeginIso,
  rechtenOfStandaard: rechtenOfStandaard,
  verwerkAanvraag: verwerkAanvraag,
};

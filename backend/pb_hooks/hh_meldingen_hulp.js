// HeitjeHulp M8 — hh_meldingen_hulp.js (hulpbestand, GEEN hook)
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. De
// handlers in hh_meldingen.pb.js halen dit bestand BINNEN de handler op met
//   const hulp = require(`${__hooks}/hh_meldingen_hulp.js`);
// (de pool-runtime deelt geen scope tussen handlers).
//
// Twee soorten functies:
//   - PUUR (geen $app): de teksten, de Nederlandse tijd en wie welke melding
//     krijgt bij een statuswissel. Die zijn los te testen met node.
//   - MET app: records lezen en de melding idempotent aanmaken. De
//     aanroeper geeft een omgeving { app: $app, Record: Record } mee, zodat
//     dit bestand niet op de globals van de JSVM leunt.
//
// IDEMPOTENT: een melding is uniek op (ontvanger, soort, sleutel). De sleutel
// is "klusstatus:<id van de logregel>" of "incident:<id>". maakMelding kijkt
// eerst of hij er al is; de unieke index idx_hh_meldingen_uniek (script 30)
// is de tweede sluis als twee aanroepen tegelijk komen.
//
// Teksten in gewone taal: voor de oudere met "u", voor de jongere met "je".
//
// DEPLOY: samen met hh_meldingen.pb.js (scripts/33-hook-deploy.sh).

const MAX_NIEUWE_KLUS = 50;

const WEEKDAGEN = ["zondag", "maandag", "dinsdag", "woensdag", "donderdag", "vrijdag", "zaterdag"];
const MAANDEN = [
  "januari", "februari", "maart", "april", "mei", "juni",
  "juli", "augustus", "september", "oktober", "november", "december",
];

// --------------------------------------------------------------------------
// PUUR
// --------------------------------------------------------------------------

/// De laatste zondag van [maand] (0-11) in [jaar], om 01:00 UTC: het moment
/// van de zomertijdwissel in de EU.
function laatsteZondagEenUur(jaar, maand) {
  const laatsteDag = new Date(Date.UTC(jaar, maand + 1, 0));
  const terug = laatsteDag.getUTCDay();
  return Date.UTC(jaar, maand, laatsteDag.getUTCDate() - terug, 1, 0, 0);
}

/// Een UTC-moment als Nederlandse wandklok (CET +1, CEST +2). De server
/// draait op UTC en de JSVM heeft geen tijdzonedatabase; de EU-regel is
/// vast: zomertijd van de laatste zondag van maart tot de laatste zondag van
/// oktober, telkens om 01:00 UTC.
function nederlandseTijd(moment) {
  const ms = moment instanceof Date ? moment.getTime() : Number(moment);
  const jaar = new Date(ms).getUTCFullYear();
  const zomer = ms >= laatsteZondagEenUur(jaar, 2) && ms < laatsteZondagEenUur(jaar, 9);
  const lokaal = new Date(ms + (zomer ? 2 : 1) * 3600 * 1000);
  return {
    weekdag: WEEKDAGEN[lokaal.getUTCDay()],
    dag: lokaal.getUTCDate(),
    maand: MAANDEN[lokaal.getUTCMonth()],
    uur: lokaal.getUTCHours(),
    minuut: lokaal.getUTCMinutes(),
  };
}

/// "dinsdag 15 september om 10:00", of "" zonder (geldige) datum.
/// PocketBase geeft "2026-09-15 08:00:00.000Z"; die spatie maakt er ISO van.
function wanneerTekst(waarde) {
  const tekst = String(waarde || "").trim();
  if (!tekst) return "";
  const ms = Date.parse(tekst.replace(" ", "T"));
  if (!isFinite(ms)) return "";
  const t = nederlandseTijd(ms);
  const mm = t.minuut < 10 ? "0" + t.minuut : String(t.minuut);
  return `${t.weekdag} ${t.dag} ${t.maand} om ${t.uur}:${mm}`;
}

function voornaam(naam) {
  const delen = String(naam || "").trim().split(/\s+/);
  return delen[0] || "";
}

function metHoofdletter(tekst) {
  const t = String(tekst || "").trim();
  return t ? t.charAt(0).toUpperCase() + t.slice(1) : "";
}

/// De titel en tekst van één melding. [rol] is die van de ONTVANGER
/// (hulpvrager, jongere, familie, coordinator). [ctx]:
///   jongere     voornaam van de jongere (kan leeg zijn)
///   oudere      naam van de oudere
///   klussoort   naam van het klustype ("boodschappen")
///   wanneer     wanneerTekst van de klus, of ""
///   teruggegeven  true bij geannuleerd via "terug naar open"
///   incidentSoort nood | probleem | overig
///   melder      naam van wie het incident meldde
///   omschrijving  tekst van het incident
function tekstVoor(soort, rol, ctx) {
  const c = ctx || {};
  const jongere = c.jongere || "";
  const wie = jongere || "Iemand";
  const klus = metHoofdletter(c.klussoort) || "Een klus";
  const wanneer = c.wanneer ? ` ${c.wanneer}` : "";
  const oudere = c.oudere || "";

  switch (soort) {
    case "nieuwe_klus":
      return { titel: "Nieuwe klus in je buurt", tekst: `${klus}${wanneer}.` };

    case "toegewezen":
      if (rol === "familie") {
        return {
          titel: "Er komt iemand helpen",
          tekst: `${wie} helpt ${oudere || "uw familielid"}${wanneer}.`,
        };
      }
      return {
        titel: "Er komt iemand helpen",
        tekst: c.wanneer ? `${wie} komt${wanneer}.` : `${wie} heeft uw hulpvraag aangenomen.`,
      };

    case "onderweg":
      return { titel: "Onderweg naar u", tekst: `${wie} is onderweg naar u.` };

    case "afgerond":
      if (rol === "jongere") {
        return { titel: "Klus afgerond", tekst: `Bedankt voor je hulp. ${klus} is klaar.` };
      }
      return { titel: "De hulp is klaar", tekst: `${wie} heeft de klus gedaan.` };

    case "geannuleerd":
      if (rol === "jongere") {
        return { titel: "Klus gaat niet door", tekst: `${klus}${wanneer} gaat niet door.` };
      }
      if (c.teruggegeven) {
        return {
          titel: "We zoeken iemand anders",
          tekst: jongere
            ? `${jongere} kan toch niet komen. We zoeken iemand anders voor u.`
            : "Er kan toch niemand komen. We zoeken iemand anders voor u.",
        };
      }
      return { titel: "Hulpvraag gestopt", tekst: "Uw hulpvraag gaat niet door." };

    case "incident": {
      const melder = c.melder || "Iemand";
      const omschrijving = String(c.omschrijving || "").trim();
      if (rol === "familie") {
        return {
          titel: "Noodmelding",
          tekst: `${melder} heeft op de noodknop gedrukt. De meldkamer neemt contact op.`,
        };
      }
      if (c.incidentSoort === "nood") {
        return {
          titel: "Noodmelding",
          tekst: omschrijving
            ? `${melder}: ${omschrijving}`
            : `${melder} heeft op de noodknop gedrukt.`,
        };
      }
      return {
        titel: c.incidentSoort === "probleem" ? "Probleem gemeld" : "Nieuwe melding",
        tekst: omschrijving ? `${melder}: ${omschrijving}` : `${melder} heeft iets gemeld.`,
      };
    }
  }
  return { titel: "Melding", tekst: "" };
}

/// Wie welke melding krijgt bij één logregel van hh_klus_status. Puur: de
/// klus en de logregel komen als gewone objecten binnen:
///   klus = { hulpvrager, geplaatst_door, toegewezen_jongere }
///   log  = { van, naar, door }
/// Geeft [{ ontvanger, rol, soort, teruggegeven? }]. "nieuwe_klus" voor de
/// jongeren in de wijk zit hier NIET in (dat vraagt een zoekopdracht); zie
/// isNieuweOpenKlus.
function ontvangersVoorWissel(klus, log) {
  const oudere = String(klus.hulpvrager || "");
  const geplaatstDoor = String(klus.geplaatst_door || "");
  const jongere = String(klus.toegewezen_jongere || "");
  const door = String(log.door || "");
  const van = String(log.van || "");
  const naar = String(log.naar || "");
  const lijst = [];
  const voeg = (id, rol, soort, extra) => {
    if (!id) return;
    if (lijst.some((o) => o.ontvanger === id && o.soort === soort)) return;
    lijst.push(Object.assign({ ontvanger: id, rol: rol, soort: soort }, extra || {}));
  };

  switch (naar) {
    case "geaccepteerd":
      voeg(oudere, "hulpvrager", "toegewezen");
      if (geplaatstDoor && geplaatstDoor !== oudere) voeg(geplaatstDoor, "familie", "toegewezen");
      break;
    case "onderweg":
      voeg(oudere, "hulpvrager", "onderweg");
      break;
    case "afgerond":
      voeg(oudere, "hulpvrager", "afgerond");
      voeg(jongere, "jongere", "afgerond");
      break;
    case "geannuleerd":
      // "De andere deelnemer": wie annuleerde krijgt niets.
      if (door !== oudere && door !== geplaatstDoor) voeg(oudere, "hulpvrager", "geannuleerd");
      if (jongere && door !== jongere) voeg(jongere, "jongere", "geannuleerd");
      break;
    case "open":
      // Terug naar open: de jongere gaf hem terug (of de coordinator gaf
      // hem vrij). De oudere hoort dat er iemand anders gezocht wordt.
      if (van === "geaccepteerd" || van === "onderweg") {
        voeg(oudere, "hulpvrager", "geannuleerd", { teruggegeven: true });
      }
      break;
  }
  return lijst;
}

/// Staat de klus na deze logregel (weer) open? Dan krijgen de goedgekeurde
/// jongeren in de wijk een melding "nieuwe klus".
function isNieuweOpenKlus(log) {
  return String(log.naar || "") === "open";
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

function zoekId(app, collectie, id) {
  if (!id) return null;
  try {
    return app.findRecordById(collectie, id);
  } catch (_) {
    return null;
  }
}

/// Maakt één melding, tenzij (ontvanger, soort, sleutel) al bestaat.
/// Geeft true als er een nieuwe is gemaakt.
function maakMelding(env, m) {
  const app = env.app;
  if (!m.ontvanger || !m.soort || !m.sleutel) return false;
  const bestaand = zoekEerste(
    app,
    "hh_meldingen",
    "ontvanger = {:ontvanger} && soort = {:soort} && sleutel = {:sleutel}",
    { ontvanger: m.ontvanger, soort: m.soort, sleutel: m.sleutel }
  );
  if (bestaand) return false;
  const record = new env.Record(app.findCollectionByNameOrId("hh_meldingen"));
  record.set("ontvanger", m.ontvanger);
  record.set("soort", m.soort);
  if (m.klus) record.set("klus", m.klus);
  if (m.incident) record.set("incident", m.incident);
  record.set("titel", m.titel || "");
  record.set("tekst", m.tekst || "");
  record.set("sleutel", m.sleutel);
  app.save(record);
  return true;
}

/// Alle meldingen bij één nieuwe logregel van hh_klus_status. Elke melding
/// in een eigen try/catch: één mislukte ontvanger houdt de rest niet tegen.
/// Geeft het aantal nieuwe meldingen terug.
function verwerkWissel(env, logRecord) {
  const app = env.app;
  const klusId = String(logRecord.get("klus") || "");
  const klus = zoekId(app, "hh_klussen", klusId);
  if (!klus) return 0;

  const log = {
    van: String(logRecord.get("van") || ""),
    naar: String(logRecord.get("naar") || ""),
    door: String(logRecord.get("door") || ""),
  };
  const k = {
    hulpvrager: String(klus.get("hulpvrager") || ""),
    geplaatst_door: String(klus.get("geplaatst_door") || ""),
    toegewezen_jongere: String(klus.get("toegewezen_jongere") || ""),
  };

  // Voornaam van de jongere: de toegewezen jongere, of bij "terug naar
  // open" degene die hem teruggaf.
  const jongereId = k.toegewezen_jongere || (log.naar === "open" ? log.door : "");
  const jongereRec = zoekId(app, "hh_users", jongereId);
  const jongereNaam =
    jongereRec && String(jongereRec.get("rol") || "") === "jongere"
      ? voornaam(jongereRec.get("naam"))
      : "";
  const oudereRec = zoekId(app, "hh_users", k.hulpvrager);
  const typeRec = zoekId(app, "hh_klustypes", String(klus.get("klustype") || ""));
  const ctx = {
    jongere: jongereNaam,
    oudere: oudereRec ? String(oudereRec.get("naam") || "") : "",
    klussoort: typeRec ? String(typeRec.get("naam") || "") : "",
    wanneer: wanneerTekst(klus.get("wanneer_van")),
  };
  const sleutel = "klusstatus:" + logRecord.id;
  let aantal = 0;

  const ontvangers = ontvangersVoorWissel(k, log);
  for (let i = 0; i < ontvangers.length; i++) {
    const o = ontvangers[i];
    try {
      const t = tekstVoor(o.soort, o.rol, Object.assign({}, ctx, { teruggegeven: !!o.teruggegeven }));
      if (maakMelding(env, {
        ontvanger: o.ontvanger, soort: o.soort, klus: klusId,
        titel: t.titel, tekst: t.tekst, sleutel: sleutel,
      })) aantal++;
    } catch (err) {
      console.log(`[hh_meldingen] melding ${o.soort} aan ${o.ontvanger} mislukt:`, String(err));
    }
  }

  if (isNieuweOpenKlus(log) && oudereRec) {
    const wijk = String(oudereRec.get("wijk") || "");
    if (wijk) {
      let profielen = [];
      try {
        profielen = app.findRecordsByFilter(
          "hh_profielen",
          'verificatiestatus = "goedgekeurd" && gebruiker.rol = "jongere" && gebruiker.wijk = {:wijk}',
          "",
          MAX_NIEUWE_KLUS,
          0,
          { wijk: wijk }
        );
      } catch (err) {
        console.log("[hh_meldingen] jongeren in de wijk zoeken mislukt:", String(err));
      }
      const t = tekstVoor("nieuwe_klus", "jongere", ctx);
      for (let i = 0; i < profielen.length; i++) {
        const ontvanger = String(profielen[i].get("gebruiker") || "");
        // Wie de klus net teruggaf, hoeft hem niet opnieuw aangeboden te krijgen.
        if (!ontvanger || ontvanger === log.door) continue;
        try {
          if (maakMelding(env, {
            ontvanger: ontvanger, soort: "nieuwe_klus", klus: klusId,
            titel: t.titel, tekst: t.tekst, sleutel: sleutel,
          })) aantal++;
        } catch (err) {
          console.log(`[hh_meldingen] nieuwe klus aan ${ontvanger} mislukt:`, String(err));
        }
      }
    }
  }
  return aantal;
}

/// Een nieuw hh_incidenten-record: een melding voor ELKE coordinator, en bij
/// soort nood ook voor het gekoppelde familielid van de melder (als er een
/// is). Geeft het aantal nieuwe meldingen terug.
function verwerkIncident(env, incident) {
  const app = env.app;
  const soort = String(incident.get("soort") || "");
  const melderId = String(incident.get("melder") || "");
  const melder = zoekId(app, "hh_users", melderId);
  const ctx = {
    incidentSoort: soort,
    melder: melder ? String(melder.get("naam") || "") : "",
    omschrijving: String(incident.get("omschrijving") || ""),
  };
  const klusId = String(incident.get("klus") || "");
  const sleutel = "incident:" + incident.id;
  let aantal = 0;

  const ontvangers = [];
  let coordinatoren = [];
  try {
    coordinatoren = app.findRecordsByFilter("hh_users", 'rol = "coordinator"', "", 0, 0);
  } catch (err) {
    console.log("[hh_meldingen] coordinatoren zoeken mislukt:", String(err));
  }
  for (let i = 0; i < coordinatoren.length; i++) {
    ontvangers.push({ id: coordinatoren[i].id, rol: "coordinator" });
  }
  if (soort === "nood" && melderId) {
    let koppelingen = [];
    try {
      koppelingen = app.findRecordsByFilter(
        "hh_koppelingen", "oudere = {:oudere}", "", 0, 0, { oudere: melderId }
      );
    } catch (err) {
      console.log("[hh_meldingen] familie zoeken mislukt:", String(err));
    }
    for (let i = 0; i < koppelingen.length; i++) {
      ontvangers.push({ id: String(koppelingen[i].get("familielid") || ""), rol: "familie" });
    }
  }

  for (let i = 0; i < ontvangers.length; i++) {
    const o = ontvangers[i];
    if (!o.id) continue;
    try {
      const t = tekstVoor("incident", o.rol, ctx);
      if (maakMelding(env, {
        ontvanger: o.id, soort: "incident", klus: klusId, incident: incident.id,
        titel: t.titel, tekst: t.tekst, sleutel: sleutel,
      })) aantal++;
    } catch (err) {
      console.log(`[hh_meldingen] incidentmelding aan ${o.id} mislukt:`, String(err));
    }
  }
  return aantal;
}

module.exports = {
  MAX_NIEUWE_KLUS: MAX_NIEUWE_KLUS,
  nederlandseTijd: nederlandseTijd,
  wanneerTekst: wanneerTekst,
  voornaam: voornaam,
  tekstVoor: tekstVoor,
  ontvangersVoorWissel: ontvangersVoorWissel,
  isNieuweOpenKlus: isNieuweOpenKlus,
  maakMelding: maakMelding,
  verwerkWissel: verwerkWissel,
  verwerkIncident: verwerkIncident,
};

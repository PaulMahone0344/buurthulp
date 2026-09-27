// HeitjeHulp M7 — hh_beoordelingen.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// Dit bestand raakt alleen hh_beoordelingen (lezen), hh_klussen (tellen),
// hh_users en hh_profielen (de twee reputatievelden schrijven). Het voegt GEEN
// route toe: een beoordeling maken en wijzigen gaat via de gewone API, want de
// rules dekken dat al (alleen bij status afgerond, alleen door een deelnemer,
// één per klus per kant via de unieke index klus+van_gebruiker).
//
// WAT DE HOOK DOET
// Na het AANMAKEN of WIJZIGEN van een hh_beoordelingen-record rekent hij de
// reputatie opnieuw uit en schrijft hem weg:
//   sterren_gemiddeld = gemiddelde van alle hh_beoordelingen met
//                       naar_gebruiker = die persoon, afgerond op 1 decimaal
//                       (0 als er nog geen beoordeling is)
//   klussen_aantal    = aantal hh_klussen met status afgerond waarin die
//                       persoon meedeed (als toegewezen jongere of als oudere)
// Beide gaan naar hh_users EN naar het hh_profielen-record van die persoon
// (dat laatste alleen als het bestaat; een oudere heeft er meestal geen).
// Rekenen gebeurt ALTIJD hier, nooit in de app.
//
// BEIDE DEELNEMERS worden bijgewerkt, niet alleen naar_gebruiker. Het
// gemiddelde van de gever verandert niet door zijn eigen beoordeling, maar zijn
// klussen_aantal wel: zo telt de klus ook mee voor wie als eerste beoordeelt.
//
// WAAROM EEN REQUEST-HOOK EN GEEN AFTER-SUCCESS-HOOK
// onRecordAfterUpdateSuccess is op deze gedeelde server gevoelig voor de
// hook-keten: één handler die geen e.next() aanroept legt alles stil wat ná
// hem geregistreerd is (memory reference_pb_jsvm_hooks punt 11 — dat is hier
// maanden stil misgegaan). onRecordCreateRequest/onRecordUpdateRequest is
// hetzelfde patroon dat hh_klussen.pb.js (M6) al gebruikt voor zijn logregels
// en dat daar werkt. Gevolg: een beoordeling die NIET via de API ontstaat
// (bijvoorbeeld door een ander script via $app) werkt de reputatie niet bij.
// Dat kan alleen een superuser, en die kan 22-beoordelingcheck draaien.
//
// FOUTEN HOUDEN NIETS TEGEN: mislukt het rekenen of schrijven, dan staat de
// beoordeling er wél. Een reputatiegetal mag nooit een beoordeling blokkeren;
// de fout komt in journalctl en de volgende beoordeling zet hem weer recht.
//
// Gotchas (memory reference_pb_jsvm_hooks): helpers BINNEN elke handler (de
// pool-runtime deelt geen scope, daarom staan ze twee keer), $app en niet
// e.app, e.next() op ELK pad, record.get() eerst naar String/Number dwingen,
// findRecordsByFilter met {:naam}-parameters (geen injectie), limit 0 = alles.
//
// DEPLOY: scripts/10-hook-deploy.sh (kopie naar /root/pb_hooks/, geen restart;
// PocketBase herlaadt hooks bij een bestandswijziging). ROLLBACK: het bestand
// weer verwijderen uit /root/pb_hooks/. Het laadt alfabetisch vóór main.pb.js,
// net als hh_klussen.pb.js.

// --------------------------------------------------------------------------
// Een NIEUWE beoordeling: eerst opslaan, dan pas rekenen (vóór e.next() heeft
// het record nog geen id en staat het nog niet in de telling).
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  e.next();

  try {
    werkReputatieBij(String(e.record.get("naar_gebruiker") || ""));
    werkReputatieBij(String(e.record.get("van_gebruiker") || ""));
  } catch (err) {
    console.log("[hh_beoordelingen] reputatie bijwerken na aanmaken mislukt:", String(err));
  }

  // ---- helpers, BINNEN de handler (pool-runtime deelt geen scope) ----

  /// Rekent sterren_gemiddeld en klussen_aantal van één persoon opnieuw uit
  /// en schrijft ze op hh_users en (als het bestaat) op hh_profielen.
  function werkReputatieBij(gebruikerId) {
    if (!gebruikerId) return;

    const beoordelingen = $app.findRecordsByFilter(
      "hh_beoordelingen",
      "naar_gebruiker = {:gebruiker}",
      "",
      0,
      0,
      { gebruiker: gebruikerId }
    );
    let som = 0;
    let geteld = 0;
    for (let i = 0; i < beoordelingen.length; i++) {
      const sterren = Number(beoordelingen[i].get("sterren") || 0);
      if (sterren > 0) {
        som += sterren;
        geteld++;
      }
    }
    // Eén decimaal, zoals in de app getoond wordt. Geen beoordelingen: 0.
    const gemiddeld = geteld === 0 ? 0 : Math.round((som / geteld) * 10) / 10;

    const klussen = $app.findRecordsByFilter(
      "hh_klussen",
      'status = "afgerond" && (toegewezen_jongere = {:gebruiker} || hulpvrager = {:gebruiker})',
      "",
      0,
      0,
      { gebruiker: gebruikerId }
    );
    const aantal = klussen.length;

    schrijf("hh_users", gebruikerId, gemiddeld, aantal);
    schrijfProfiel(gebruikerId, gemiddeld, aantal);
    console.log(
      `[hh_beoordelingen] reputatie ${gebruikerId}: ${gemiddeld} sterren uit ${geteld}, ${aantal} klussen`
    );
  }

  function schrijf(collectie, recordId, gemiddeld, aantal) {
    let record;
    try {
      record = $app.findRecordById(collectie, recordId);
    } catch (_) {
      return;
    }
    record.set("sterren_gemiddeld", gemiddeld);
    record.set("klussen_aantal", aantal);
    $app.save(record);
  }

  /// Het profiel van de jongere. Een oudere heeft er meestal geen; dan is er
  /// niets te doen.
  function schrijfProfiel(gebruikerId, gemiddeld, aantal) {
    let profiel;
    try {
      profiel = $app.findFirstRecordByFilter("hh_profielen", "gebruiker = {:gebruiker}", {
        gebruiker: gebruikerId,
      });
    } catch (_) {
      return;
    }
    if (!profiel) return;
    profiel.set("sterren_gemiddeld", gemiddeld);
    profiel.set("klussen_aantal", aantal);
    $app.save(profiel);
  }
}, "hh_beoordelingen");

// --------------------------------------------------------------------------
// Een GEWIJZIGDE beoordeling (de gever mag zijn sterren en tekst aanpassen;
// verwijderen mag alleen de coordinator). Zelfde herberekening, ná e.next().
// --------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  e.next();

  try {
    werkReputatieBij(String(e.record.get("naar_gebruiker") || ""));
    werkReputatieBij(String(e.record.get("van_gebruiker") || ""));
  } catch (err) {
    console.log("[hh_beoordelingen] reputatie bijwerken na wijzigen mislukt:", String(err));
  }

  // ---- helpers, BINNEN de handler (pool-runtime deelt geen scope) ----

  function werkReputatieBij(gebruikerId) {
    if (!gebruikerId) return;

    const beoordelingen = $app.findRecordsByFilter(
      "hh_beoordelingen",
      "naar_gebruiker = {:gebruiker}",
      "",
      0,
      0,
      { gebruiker: gebruikerId }
    );
    let som = 0;
    let geteld = 0;
    for (let i = 0; i < beoordelingen.length; i++) {
      const sterren = Number(beoordelingen[i].get("sterren") || 0);
      if (sterren > 0) {
        som += sterren;
        geteld++;
      }
    }
    const gemiddeld = geteld === 0 ? 0 : Math.round((som / geteld) * 10) / 10;

    const klussen = $app.findRecordsByFilter(
      "hh_klussen",
      'status = "afgerond" && (toegewezen_jongere = {:gebruiker} || hulpvrager = {:gebruiker})',
      "",
      0,
      0,
      { gebruiker: gebruikerId }
    );
    const aantal = klussen.length;

    schrijf("hh_users", gebruikerId, gemiddeld, aantal);
    schrijfProfiel(gebruikerId, gemiddeld, aantal);
    console.log(
      `[hh_beoordelingen] reputatie ${gebruikerId}: ${gemiddeld} sterren uit ${geteld}, ${aantal} klussen`
    );
  }

  function schrijf(collectie, recordId, gemiddeld, aantal) {
    let record;
    try {
      record = $app.findRecordById(collectie, recordId);
    } catch (_) {
      return;
    }
    record.set("sterren_gemiddeld", gemiddeld);
    record.set("klussen_aantal", aantal);
    $app.save(record);
  }

  function schrijfProfiel(gebruikerId, gemiddeld, aantal) {
    let profiel;
    try {
      profiel = $app.findFirstRecordByFilter("hh_profielen", "gebruiker = {:gebruiker}", {
        gebruiker: gebruikerId,
      });
    } catch (_) {
      return;
    }
    if (!profiel) return;
    profiel.set("sterren_gemiddeld", gemiddeld);
    profiel.set("klussen_aantal", aantal);
    $app.save(profiel);
  }
}, "hh_beoordelingen");

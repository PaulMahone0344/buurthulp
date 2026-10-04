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
// DE REKENREGEL staat in hh_reputatie.js (gewoon .js, geen hook), zodat
// hh_klussen.pb.js bij de overgang naar afgerond precies dezelfde telling
// gebruikt. Elke handler haalt hem BINNEN de handler op met require(): de
// pool-runtime deelt geen scope tussen handlers.
//
// Gotchas (memory reference_pb_jsvm_hooks): $app en niet e.app, e.next() op
// ELK pad, record.get() eerst naar String/Number dwingen, findRecordsByFilter
// met {:naam}-parameters (geen injectie), limit 0 = alles.
//
// B9: na de reputatie ook XP voor de helper die de beoordeling kreeg
// (hh_xp_hulp.js). DEPLOY sinds B9: scripts/143-hook-deploy.sh.
//
// DEPLOY (M7): scripts/23-hook-deploy.sh (kopie van dit bestand EN hh_reputatie.js
// naar /root/pb_hooks/, geen restart; PocketBase herlaadt hooks bij een
// bestandswijziging). 10-hook-deploy.sh kent alleen hh_klussen.pb.js.
// ROLLBACK: 23-hook-deploy.sh --rollback. Het laadt alfabetisch vóór
// main.pb.js, net als hh_klussen.pb.js.

// --------------------------------------------------------------------------
// Een NIEUWE beoordeling: eerst opslaan, dan pas rekenen (vóór e.next() heeft
// het record nog geen id en staat het nog niet in de telling).
// --------------------------------------------------------------------------
onRecordCreateRequest((e) => {
  e.next();

  try {
    const reputatie = require(`${__hooks}/hh_reputatie.js`);
    reputatie.werkReputatieBij($app, String(e.record.get("naar_gebruiker") || ""));
    reputatie.werkReputatieBij($app, String(e.record.get("van_gebruiker") || ""));
  } catch (err) {
    console.log("[hh_beoordelingen] reputatie bijwerken na aanmaken mislukt:", String(err));
  }

  // B9: XP van de helper die de beoordeling KREEG (alleen een jongere telt;
  // werkXpBij slaat een bewoner over). Na de reputatie: niveau Top kijkt
  // naar de sterren.
  try {
    const xp = require(`${__hooks}/hh_xp_hulp.js`);
    const env = { app: $app, Record: Record, nu: () => Date.now() };
    xp.beloningMelden(env, xp.werkXpBij(env, String(e.record.get("naar_gebruiker") || "")), String(e.record.get("klus") || ""));
  } catch (err) {
    console.log("[hh_beoordelingen] XP bijwerken na aanmaken mislukt:", String(err));
  }
}, "hh_beoordelingen");

// --------------------------------------------------------------------------
// Een GEWIJZIGDE beoordeling (de gever mag zijn sterren en tekst aanpassen;
// verwijderen mag alleen de coordinator). Zelfde herberekening, ná e.next().
// --------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  e.next();

  try {
    const reputatie = require(`${__hooks}/hh_reputatie.js`);
    reputatie.werkReputatieBij($app, String(e.record.get("naar_gebruiker") || ""));
    reputatie.werkReputatieBij($app, String(e.record.get("van_gebruiker") || ""));
  } catch (err) {
    console.log("[hh_beoordelingen] reputatie bijwerken na wijzigen mislukt:", String(err));
  }

  // B9: XP van de helper die de beoordeling KREEG (alleen een jongere telt;
  // werkXpBij slaat een bewoner over). Na de reputatie: niveau Top kijkt
  // naar de sterren.
  try {
    const xp = require(`${__hooks}/hh_xp_hulp.js`);
    const env = { app: $app, Record: Record, nu: () => Date.now() };
    xp.beloningMelden(env, xp.werkXpBij(env, String(e.record.get("naar_gebruiker") || "")), String(e.record.get("klus") || ""));
  } catch (err) {
    console.log("[hh_beoordelingen] XP bijwerken na wijzigen mislukt:", String(err));
  }
}, "hh_beoordelingen");

// HeitjeHulp M7 — hh_reputatie.js (hulpbestand, GEEN hook)
//
// Bewust .js en niet .pb.js: PocketBase laadt alleen *.pb.js als hook. Dit
// bestand wordt BINNEN een handler opgehaald met
//   const reputatie = require(`${__hooks}/hh_reputatie.js`);
// (de pool-runtime deelt geen scope tussen handlers, memory
// reference_pb_jsvm_hooks punt 1). Zo staat de rekenregel op één plek en
// gebruiken hh_beoordelingen.pb.js (na een beoordeling) en hh_klussen.pb.js
// (bij de overgang naar afgerond) precies dezelfde.
//
// De aanroeper geeft de app mee ($app of een txApp); dit bestand leunt niet
// op globals.
//
// WAT HET UITREKENT, voor één persoon:
//   sterren_gemiddeld = gemiddelde van alle hh_beoordelingen met
//                       naar_gebruiker = die persoon en NIET verborgen door
//                       de meldkamer (B9: verborgen_op leeg), op 1 decimaal
//                       (0 als er nog geen beoordeling is)
//   klussen_aantal    = aantal hh_klussen met status afgerond waarin die
//                       persoon meedeed (als toegewezen jongere of als oudere)
// en schrijft beide op hh_users EN op het hh_profielen-record van die persoon
// (dat laatste alleen als het bestaat; een oudere heeft er meestal geen).
//
// DEPLOY: samen met de hooks naar /root/pb_hooks/ (scripts/23-hook-deploy.sh).

/// Gemiddelde op één decimaal, zoals de app het toont. Geen sterren: 0.
/// Math.round rondt .5 naar boven af (4,25 wordt 4,3); de app spiegelt dat
/// alleen voor de weergave (lib/features/jongere/reputatie/domein).
function gemiddeldOpEenDecimaal(som, geteld) {
  if (!geteld) return 0;
  return Math.round((som / geteld) * 10) / 10;
}

/// Rekent de reputatie van [gebruikerId] opnieuw uit en schrijft hem weg.
/// Geeft { gemiddeld, geteld, aantal } terug (voor de logregel en tests), of
/// null zonder gebruiker. Gooit bij een fout; de aanroeper vangt die af.
function werkReputatieBij(app, gebruikerId) {
  const id = String(gebruikerId || "").trim();
  if (!id) return null;

  const beoordelingen = app.findRecordsByFilter(
    "hh_beoordelingen",
    // B9: een recensie die de meldkamer verborg, telt niet mee.
    'naar_gebruiker = {:gebruiker} && verborgen_op = ""',
    "",
    0,
    0,
    { gebruiker: id }
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
  const gemiddeld = gemiddeldOpEenDecimaal(som, geteld);

  const klussen = app.findRecordsByFilter(
    "hh_klussen",
    'status = "afgerond" && (toegewezen_jongere = {:gebruiker} || hulpvrager = {:gebruiker})',
    "",
    0,
    0,
    { gebruiker: id }
  );
  const aantal = klussen.length;

  schrijfGebruiker(app, id, gemiddeld, aantal);
  schrijfProfiel(app, id, gemiddeld, aantal);
  console.log(
    `[hh_reputatie] ${id}: ${gemiddeld} sterren uit ${geteld}, ${aantal} klussen`
  );
  return { gemiddeld: gemiddeld, geteld: geteld, aantal: aantal };
}

function schrijfGebruiker(app, gebruikerId, gemiddeld, aantal) {
  let record;
  try {
    record = app.findRecordById("hh_users", gebruikerId);
  } catch (_) {
    return;
  }
  record.set("sterren_gemiddeld", gemiddeld);
  record.set("klussen_aantal", aantal);
  app.save(record);
}

/// Het profiel van de jongere. Een oudere heeft er meestal geen; dan is er
/// niets te doen.
function schrijfProfiel(app, gebruikerId, gemiddeld, aantal) {
  let profiel;
  try {
    profiel = app.findFirstRecordByFilter("hh_profielen", "gebruiker = {:gebruiker}", {
      gebruiker: gebruikerId,
    });
  } catch (_) {
    return;
  }
  if (!profiel) return;
  profiel.set("sterren_gemiddeld", gemiddeld);
  profiel.set("klussen_aantal", aantal);
  app.save(profiel);
}

module.exports = {
  gemiddeldOpEenDecimaal: gemiddeldOpEenDecimaal,
  werkReputatieBij: werkReputatieBij,
};

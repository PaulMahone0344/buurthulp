// HeitjeHulp B5 — hh_reacties_teksten.js (hulpbestand, GEEN hook)
//
// Alle zichtbare teksten van B5 (reageren, ouder keurt per klus, kiezen,
// match, beoordelen, "Ik kan nu helpen") op één plek. Bewust .js en niet
// .pb.js: PocketBase laadt alleen *.pb.js als hook. hh_reacties_hulp.js haalt
// dit bestand op; de tests (backend/tests/hh_reacties_*.test.mjs) lezen het
// zonder server.
//
// Toon: helper en bewoner allebei met "je" (B1). De ouder-mail in gewone
// taal, zonder achternaam, geboortedatum of huisnummer.

var MELDING = {
  // reageren
  rol: "Alleen een strijder kan reageren op een klus.",
  geenwijk: "HeitjeHulp is nog niet in jouw buurt. We laten het je weten zodra we er zijn.",
  nietgoedgekeurd: "Je aanmelding is nog niet goedgekeurd. Je kunt nog niet reageren op klussen.",
  nietgevonden: "Deze klus bestaat niet meer.",
  bezet: "Deze klus heeft al een strijder.",
  wijk: "Deze klus ligt niet in jouw wijk.",
  nietgekeurd: "Deze klus wordt nog nagekeken door de meldkamer.",
  begonnen: "Deze klus is al begonnen.",
  algereageerd: "Je hebt al gereageerd op deze klus.",
  limiet: "Je hebt al 10 reacties open staan. Wacht tot een bewoner kiest, of trek een reactie in.",
  bericht: "Je berichtje mag hooguit 200 tekens zijn.",
  oudermee:
    "Dit is je eerste klus bij deze bewoner. Zet het vinkje \"Mijn ouder gaat mee\": je ouder gaat de eerste keer mee.",
  geenouder: "We kunnen je ouder niet mailen. Neem contact op met de meldkamer.",
  mail: "De mail aan je ouder kon niet worden verstuurd. Probeer het later opnieuw.",
  onder18:
    "Fijn dat je wilt helpen! Strijders onder de 18 kunnen nog even niet reageren. Binnenkort kan het wel: je krijgt dan een bericht.",
  verstuurd: "Je reactie is verstuurd. De bewoner kiest zelf een strijder.",
  verstuurdOuder:
    "Je reactie is verstuurd. Eerst kijkt je ouder of het goed is. Daarna ziet de bewoner je reactie.",
  // intrekken
  nietvanjou: "Deze reactie is niet van jou.",
  status: "Deze reactie kan niet meer worden ingetrokken.",
  ingetrokken: "Je reactie is ingetrokken.",
  // kiezen
  geenbewoner: "Alleen de bewoner van deze klus kan een strijder kiezen.",
  geenreactie: "Kies eerst een strijder.",
  reactieweg: "Deze strijder is niet meer beschikbaar. Kies iemand anders.",
  helperbezet: "Deze strijder heeft op dat moment al een andere klus. Kies iemand anders.",
  klusbezet: "Je hebt al een strijder gekozen voor deze klus.",
  match: "Het is een match!",
  // ouder (website)
  link: "Deze link werkt niet meer. Gebruik de link uit de nieuwste mail.",
  teveel: "Te veel pogingen. Probeer het over een uur opnieuw.",
  besluit: "Kies \"Goed\" of \"Liever niet\".",
  verlopen: "Deze vraag is verlopen: de klus is al begonnen of gaat niet meer door.",
  // accepteren (oude route, schakelaar b5_accepteren_dicht)
  reageren:
    "Een klus aannemen gaat nu anders: tik op \"Ik wil helpen\" en de bewoner kiest zelf. Zie je die knop niet? Werk de app dan bij.",
  // Ik kan nu helpen
  beschikbaarRol: "Alleen een strijder kan \"Ik kan nu helpen\" aanzetten.",
  geenprofiel: "Je profiel is nog niet klaar. Rond eerst je aanmelding af.",
  telRol: "Alleen een bewoner kan zien hoeveel strijders nu kunnen.",
  beschikbaarVeld: "\"Ik kan nu helpen\" zet je met de schakelaar in de app.",
};

/// Vraag van de geheime vraag, per kant (punt 11).
var GEHEIME_VRAAG = {
  hulpvrager: "Was alles in orde?",
  jongere: "Voelde je je veilig?",
};

function metHoofdletter(tekst) {
  var t = String(tekst || "").trim();
  return t ? t.charAt(0).toUpperCase() + t.slice(1) : "";
}

function ontsnap(tekst) {
  return String(tekst || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function zonderRegeleinden(tekst) {
  return String(tekst || "").replace(/[\r\n]+/g, " ").trim();
}

/// "Tuin" + "zaterdag 10 oktober om 10:00" -> "Tuin, zaterdag 10 oktober om 10:00".
function klusRegel(klussoort, wanneer) {
  var soort = metHoofdletter(klussoort) || "Een klus";
  return wanneer ? soort + ", " + wanneer : soort;
}

// ---------------------------------------------------------------- meldingen

/// Bewoner, gebundeld: één melding per klus zolang hij ongelezen is.
/// [namen] = voornamen van de helpers die nu reageerden (open), nieuwste eerst.
function reactieBewoner(namen, klussoort, wanneer) {
  var n = namen.length;
  var titel;
  if (n <= 1) titel = (namen[0] || "Een strijder") + " wil je helpen";
  else if (n === 2) titel = namen[0] + " en " + namen[1] + " willen je helpen";
  else titel = n + " strijders willen je helpen";
  return {
    titel: titel,
    tekst: "Voor " + klusRegel(klussoort, wanneer) + ". Kies zelf wie je helpt.",
  };
}

/// Helper: de bewoner koos iemand anders (vriendelijk).
function nietGekozen(klussoort, wanneer) {
  return {
    titel: "De bewoner koos iemand anders",
    tekst:
      "Bedankt voor je reactie op " + klusRegel(klussoort, wanneer) +
      ". Er komen vast nog andere klussen in je buurt.",
  };
}

/// Helper: de klus gaat niet door (bewoner annuleerde of meldkamer keurde af).
function klusGaatNietDoor(klussoort, wanneer) {
  return {
    titel: "Klus gaat niet door",
    tekst: klusRegel(klussoort, wanneer) + " gaat niet door. Je reactie is vervallen.",
  };
}

/// Helper: het besluit van de ouder.
function ouderBesluit(besluit, klussoort, wanneer) {
  if (besluit === "goed") {
    return {
      titel: "Je ouder vindt het goed",
      tekst: "De bewoner ziet nu je reactie op " + klusRegel(klussoort, wanneer) + ".",
    };
  }
  return {
    titel: "Je ouder koos \"liever niet\"",
    tekst: "Je reactie op " + klusRegel(klussoort, wanneer) + " gaat niet naar de bewoner.",
  };
}

/// Gekozen helper: "Het is een match!" (vervangt de M8-tekst "De
/// coordinator heeft je gekoppeld" bij een keuze van de bewoner).
function match(bewonerVoornaam, klussoort, wanneer) {
  var wie = bewonerVoornaam || "De bewoner";
  return {
    titel: MELDING.match,
    tekst: wie + " koos jou voor " + klusRegel(klussoort, wanneer) + ". Open de chat om af te spreken.",
  };
}

// ---------------------------------------------------------------- ouder-mail

/// De mail aan de ouder: wat, waar (straat zonder huisnummer), wanneer,
/// voornaam bewoner, en de link met de twee knoppen.
///   g = { helperVoornaam, klussoort, omschrijving, waar, wanneer,
///         bewonerVoornaam, ouderGaatMee, link }
function ouderKlusMail(g) {
  var kind = zonderRegeleinden(g.helperVoornaam) || "Je kind";
  var soort = metHoofdletter(g.klussoort) || "Een klus";
  var omschrijving = zonderRegeleinden(g.omschrijving);
  var waar = zonderRegeleinden(g.waar) || "In de buurt";
  var wanneer = zonderRegeleinden(g.wanneer) || "Nog niet bekend";
  var bewoner = zonderRegeleinden(g.bewonerVoornaam) || "een buurtbewoner";
  var onderwerp = kind + " wil helpen bij een klus. Vind je het goed?";
  var regels = [
    "Hallo,",
    "",
    kind + " wil helpen bij deze klus van " + bewoner + ":",
    "",
    "Wat: " + soort + (omschrijving ? " - " + omschrijving : ""),
    "Waar: " + waar,
    "Wanneer: " + wanneer,
  ];
  if (g.ouderGaatMee) regels.push("", "Dit is de eerste klus bij deze bewoner: " + kind + " heeft aangegeven dat jij meegaat.");
  regels.push(
    "",
    "Vind je het goed? Open deze link en kies \"Goed\" of \"Liever niet\": " + g.link,
    "Pas als jij \"Goed\" kiest, ziet de bewoner de reactie van " + kind + ".",
    "Deze vraag vervalt als de klus begint.",
    "",
    "Groet,",
    "HeitjeHulp"
  );
  var k = ontsnap(kind);
  var l = ontsnap(g.link);
  var rij = function (kop, waarde) {
    return '<tr><td style="padding:4px 12px 4px 0;color:#4A5754;vertical-align:top">' + kop +
      '</td><td style="padding:4px 0">' + ontsnap(waarde) + "</td></tr>";
  };
  var html =
    '<div style="font-family:Arial,sans-serif;font-size:16px;line-height:24px;color:#0B2A25;max-width:560px">' +
    "<p>Hallo,</p>" +
    "<p>" + k + " wil helpen bij deze klus van " + ontsnap(bewoner) + ":</p>" +
    '<table style="border-collapse:collapse;margin:8px 0 16px">' +
    rij("Wat", soort + (omschrijving ? " - " + omschrijving : "")) +
    rij("Waar", waar) +
    rij("Wanneer", wanneer) +
    "</table>" +
    (g.ouderGaatMee
      ? "<p>Dit is de eerste klus bij deze bewoner: " + k + " heeft aangegeven dat jij meegaat.</p>"
      : "") +
    '<p><a href="' + l + '" style="display:inline-block;background:#17453E;color:#FFFFFF;padding:12px 20px;border-radius:10px;text-decoration:none;font-weight:bold">Bekijk en kies</a></p>' +
    '<p style="font-size:14px;color:#4A5754">Werkt de knop niet? Open ' + l + "</p>" +
    "<p>Pas als jij \"Goed\" kiest, ziet de bewoner de reactie van " + k + ".<br>Deze vraag vervalt als de klus begint.</p>" +
    "<p>Groet,<br>HeitjeHulp</p>" +
    "</div>";
  return { onderwerp: onderwerp, tekst: regels.join("\n"), html: html };
}

// ---------------------------------------------------------------- incident

/// Omschrijving van het signaal (incident soort "signaal") bij "Nee" op de
/// geheime vraag.
var MERK_GEHEIM = "[geheime vraag]";
function geheimIncident(rol, toelichting) {
  var vraag = GEHEIME_VRAAG[rol] || GEHEIME_VRAAG.hulpvrager;
  var extra = zonderRegeleinden(toelichting);
  return (MERK_GEHEIM + " Na de klus: \"" + vraag + "\" Antwoord: nee." + (extra ? " " + extra : "")).slice(0, 1000);
}

module.exports = {
  MELDING: MELDING,
  GEHEIME_VRAAG: GEHEIME_VRAAG,
  MERK_GEHEIM: MERK_GEHEIM,
  metHoofdletter: metHoofdletter,
  ontsnap: ontsnap,
  klusRegel: klusRegel,
  reactieBewoner: reactieBewoner,
  nietGekozen: nietGekozen,
  klusGaatNietDoor: klusGaatNietDoor,
  ouderBesluit: ouderBesluit,
  match: match,
  ouderKlusMail: ouderKlusMail,
  geheimIncident: geheimIncident,
};

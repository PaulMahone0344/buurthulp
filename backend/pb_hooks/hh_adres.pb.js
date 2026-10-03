// HeitjeHulp ADRES — hh_adres.pb.js (PocketBase JS-hook, gedeelde prod-server)
//
// GET /api/hh/adres?postcode=4001MA&huisnummer=1&toevoeging=
//   De adres-suggestie "zoals bol.com" voor de app (aanmelden bewoner en
//   helper, Mijn gegevens) en het beheerpaneel (telefonische aanmelding).
//   PUBLIEK: ook nodig bij aanmelden, vóór er een account is.
//   Antwoorden (hh_adres_hulp.zoekAdres):
//     200 { gevonden: true, adressen: [{ straat, huisnummer, toevoeging,
//           postcode "4001 MA", plaats, gemeente, lat, lon, adres, weergave,
//           binnen_werkgebied }] }   (meerdere = keuzelijst)
//     200 { gevonden: false, reden: "nietgevonden" | "toevoeging" (met de
//           keuzes in adressen) | "dienst" (PDOK onbereikbaar), melding }
//     400 { gevonden: false, reden: "postcode" | "huisnummer" | "toevoeging", melding }
//     429 { gevonden: false, reden: "limiet", melding }
//   Rate-limit per IP per uur: anoniem 60, ingelogd 120, coordinator en
//   superuser geen grens ($app.store, zoals B3). PDOK: time-out 5 s, een
//   gevonden (of niet-gevonden) adres 10 minuten in de cache, zodat het
//   aanmelden daarna PDOK niet nog eens vraagt.
//
// Het opslaan zelf (de server is de waarheid) zit in hh_aanmelden.pb.js.
//
// Gotchas (PB 0.25 JSVM): helpers BINNEN de handler via require(); $app en
// niet e.app.
//
// DEPLOY: scripts/123-hook-deploy.sh (NIEUW bestand, samen met
// hh_adres_hulp.js). HH_PDOK_URL (omgeving) alleen voor een lokale proef.

routerAdd("GET", "/api/hh/adres", (e) => {
  const adres = require(`${__hooks}/hh_adres_hulp.js`);
  const aanmelden = require(`${__hooks}/hh_aanmelden_hulp.js`);
  const env = {
    url: $os.getenv("HH_PDOK_URL") || "",
    http: (req) => $http.send(req),
    nu: () => Date.now(),
    store: $app.store(),
    log: (...a) => console.log(...a),
    binnen: (punt) => !!aanmelden.werkgebiedVoorPunt(punt),
  };

  if (!adres.magZoeken(env, e.realIP(), adres.limietVoor(adres.wieIs(e.auth)))) {
    return e.json(429, { gevonden: false, reden: "limiet", melding: adres.MELDING.limiet });
  }

  const q = e.request.url.query();
  const uit = adres.zoekAdres(env, {
    postcode: String(q.get("postcode") || ""),
    huisnummer: String(q.get("huisnummer") || ""),
    toevoeging: String(q.get("toevoeging") || ""),
  });
  return e.json(uit.status, uit.body);
});

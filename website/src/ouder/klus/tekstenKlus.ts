// B5 — teksten van de ouder-kluspagina (je-vorm, rustig en duidelijk). Nooit
// een achternaam of huisnummer: de server stuurt alleen voornamen en de
// straat zonder nummer.

const hoofdletter = (t: string) => t.charAt(0).toUpperCase() + t.slice(1)
const kind = (n: string) => hoofdletter(n.trim() || 'je kind')

export const K = {
  kop: (n: string) => `${kind(n)} wil helpen bij een klus`,
  sub: 'Vind je het goed? Pas als jij "Goed" kiest, ziet de bewoner de reactie.',
  kaartKop: 'De klus',
  wat: 'Wat',
  waar: 'Waar',
  wanneer: 'Wanneer',
  bij: 'Bij',
  onbekend: 'Nog niet bekend',
  inDeBuurt: 'In de buurt',
  ouderMee: (n: string) => `Dit is de eerste klus bij deze bewoner. ${kind(n)} gaf aan dat jij meegaat.`,
  voet: 'Deze vraag vervalt als de klus begint. Het precieze adres hoort je kind pas als de bewoner kiest.',
  goed: 'Goed',
  lieverNiet: 'Liever niet',
  bezig: 'Even geduld…',
  laden: 'Laden…',
  goedKop: 'Dank je. Je koos "Goed".',
  goedTekst: (n: string) => `De bewoner ziet nu de reactie van ${kind(n)}. Kiest de bewoner ${kind(n)}, dan krijgt ${kind(n)} een melding in de app.`,
  nietKop: 'Helder. Je koos "Liever niet".',
  nietTekst: (n: string) => `${kind(n)} helpt niet bij deze klus. De bewoner ziet de reactie niet. ${kind(n)} krijgt een melding in de app.`,
  verlopenKop: 'Deze vraag is verlopen',
  verlopenTekst: 'De klus is al begonnen, of er is al iemand anders gekozen. Je hoeft niets meer te doen.',
  ingetrokkenKop: 'Deze reactie is ingetrokken',
  ingetrokkenTekst: (n: string) => `${kind(n)} trok de reactie zelf in. Je hoeft niets meer te doen.`,
  geenLink: 'Open de link uit de mail van HeitjeHulp opnieuw.',
}

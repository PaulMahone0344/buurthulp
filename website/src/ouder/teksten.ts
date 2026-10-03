// B3 — teksten van de ouder-pagina's (je-vorm, rustig en duidelijk).
// VOORLOPIG: "Wat je moet weten" (o.a. "Jij blijft verantwoordelijk") en de
// AVP-uitleg moeten nog langs de jurist (app/OPEN-PUNTEN-B3.txt).

/** De voornaam, of "je kind" als de server hem niet meegaf. */
export const naamOf = (voornaam: string) => voornaam.trim() || 'je kind'
const hoofdletter = (t: string) => t.charAt(0).toUpperCase() + t.slice(1)

export const T = {
  merk: 'heitjehulp',
  stap: (n: number) => `Stap ${n} van 2`,

  codeKop: 'Je kind wil helper worden bij HeitjeHulp',
  codeUitleg: [
    'HeitjeHulp brengt buren en helpers samen voor kleine klussen.',
    'Je kind doet kleine klussen in de buurt, zoals boodschappen of tuinwerk.',
    'Je kind kiest zelf welke klus het wordt.',
  ],
  codeSectie: 'Vul de code in die je kreeg',
  emailLabel: 'Je e-mailadres',
  emailUitleg: 'Het adres waarop je de mail van HeitjeHulp kreeg.',
  codeLegend: 'De code van 6 cijfers',
  cijfer: (i: number) => `Cijfer ${i}`,
  verder: 'Verder',
  bezig: 'Even geduld…',
  codeVoet: 'De code is 24 uur geldig. Geen code? Vraag je kind om hem opnieuw te sturen.',
  foutEmail: 'Vul je e-mailadres in.',
  foutCode: 'Vul de code van 6 cijfers in.',

  toestemmingKop: (n: string) => `Geef toestemming voor ${hoofdletter(n)}`,
  toestemmingSub: 'Lees de punten hieronder. Vul daarna je gegevens in.',
  wetenKop: 'Wat je moet weten',
  weten: (n: string) => [
    `${hoofdletter(n)} kiest zelf welke klussen hij of zij doet.`,
    `Jij blijft verantwoordelijk voor ${n}.`,
    'HeitjeHulp bemiddelt alleen; we zijn geen werkgever.',
    'Je kunt je toestemming altijd intrekken via de link in de mail.',
  ],
  ibanLabel: 'Rekeningnummer voor uitbetaling (IBAN)',
  ibanUitleg: (n: string) => `Hier komen de verdiensten van ${n} op. Mag ook de rekening van ${n} zelf zijn.`,
  ibanPlaceholder: 'NL00 BANK 0000 0000 00',
  naamLabel: 'Je naam',
  naamPlaceholder: 'Voor- en achternaam',
  akkoord: (n: string) => `Ik geef toestemming dat ${hoofdletter(n)} helper wordt`,
  avp: 'Ik heb een aansprakelijkheidsverzekering (AVP)',
  avpUitleg: (n: string) =>
    `Een AVP betaalt als ${n} per ongeluk iets kapotmaakt bij een ander. De meeste gezinnen hebben er een. Geen AVP? Je kunt toch toestemming geven.`,
  geven: 'Toestemming geven',
  foutAkkoord: 'Zet het vinkje om toestemming te geven.',
  foutNaam: 'Vul je naam in.',
  foutIban: 'Vul een geldig Nederlands rekeningnummer (IBAN) in.',

  bedanktKop: 'Bedankt! Je toestemming is binnen.',
  bedanktTekst: (n: string) =>
    `De meldkamer van HeitjeHulp kijkt de aanmelding van ${n} nog na. Daarna kan ${n} aan de slag.`,
  gegevenKop: (n: string) => `Je hebt toestemming gegeven voor ${hoofdletter(n)}`,
  gegevenOp: (datum: string) => `Gegeven op ${datum}.`,
  intrekkenVraag: 'Toestemming intrekken? Dat kan altijd via de link in de mail.',
  intrekken: 'Toestemming intrekken',
  intrekkenTitel: 'Toestemming intrekken?',
  intrekkenUitleg: (n: string) =>
    `${hoofdletter(n)} kan dan direct geen klussen meer aannemen. Je krijgt een bevestiging per mail.`,
  intrekkenJa: 'Ja, intrekken',
  intrekkenNee: 'Nee, terug',

  ingetrokkenKop: 'Je toestemming is ingetrokken',
  ingetrokkenTekst: (n: string) =>
    `${hoofdletter(n)} kan geen klussen meer aannemen. Wil je later toch toestemming geven? Dan kan ${n} je in de app een nieuwe code sturen.`,
  verlopenKop: 'Deze code is verlopen',
  verlopenTekst: (n: string) => `Een code is 24 uur geldig. Vraag ${n} om in de app een nieuwe code te sturen.`,
  laden: 'Laden…',
}

const NL_DATUM = new Intl.DateTimeFormat('nl-NL', { timeZone: 'Europe/Amsterdam', day: 'numeric', month: 'long', year: 'numeric' })

/** "2026-10-04 10:00:00.000Z" -> "4 oktober 2026"; leeg bij onzin. */
export function toonDatum(waarde = ''): string {
  const d = new Date(waarde.replace(' ', 'T'))
  return Number.isNaN(d.getTime()) ? '' : NL_DATUM.format(d)
}

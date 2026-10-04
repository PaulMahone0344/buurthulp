// Inhoud van de HeitjeHulp-voorpagina. Bron: besluit 3 okt 2026 (KEUZE-A-B-C,
// keuze B + wijzigingen collega): HeitjeHulp is een bedrijf dat bemiddelt
// tussen bewoners en helpers, geen werkgever.
// Bewust NIET publiek: bedragen en prijzen (volgen later), begroting,
// verdienmodel, namen van partners en concurrenten. Zie App.test.tsx, die dat bewaakt.

export interface NavLink {
  href: string
  label: string
}

export interface IconItem {
  icon: string
  title: string
  text: string
}

export type KaderKey = 'betalen' | 'ouders' | 'vog' | 'privacy'

export interface Kader {
  key: KaderKey
  icon: string
  tab: string
  title: string
  intro: string
  points: string[]
}

export interface Rol {
  icon: string
  rol: string
  kop: string
  items: { title: string; text: string }[]
}

export interface Vraag {
  vraag: string
  antwoord: string
}

export const SLOGAN = 'Heitje voor een karweitje, in jouw buurt.'

// Elke link heeft een eigen pagina; de adressen horen bij PAGINAS in LandingPage.tsx.
export const navLinks: NavLink[] = [
  { href: '/zo-werkt-het', label: 'Zo werkt het' },
  { href: '/voor-wie', label: 'Voor wie' },
  { href: '/helpers', label: 'Helpers' },
  { href: '/veiligheid', label: 'Veiligheid' },
  { href: '/partners', label: 'Partners' },
  { href: '/vragen', label: 'Vragen' },
]

export interface Wegwijzer {
  icon: string
  titel: string
  tekst: string
  href: string
}

// Voorpagina, blok "Voor de buurt": per groep de weg naar de eigen pagina.
export const wegwijzers: Wegwijzer[] = [
  { icon: 'House', titel: 'Bewoners', tekst: 'Plaats een klus en kies zelf je helper.', href: '/zo-werkt-het' },
  { icon: 'Sparkles', titel: 'Helpers', tekst: 'Verdien zakgeld in je eigen buurt.', href: '/helpers' },
  { icon: 'Users', titel: 'Ouders', tekst: 'Lees hoe we het veilig houden.', href: '/veiligheid' },
  { icon: 'Handshake', titel: 'Jongerenwerk', tekst: 'Word partner van HeitjeHulp.', href: '/partners' },
]

export const heroPoints: string[] = [
  'Plaats je klus met een foto',
  'Kies zelf je helper, op sterren en recensies',
  'Chat in de app, je nummer blijft verborgen',
]

export const introText: string[] = [
  'Je heg moet gesnoeid worden. Je hond moet uit. Of je wilt hulp met je nieuwe telefoon. Kleine klussen, maar ze blijven liggen. En vaak woont er iemand om de hoek die je graag helpt.',
  'HeitjeHulp brengt die twee bij elkaar. Jij plaatst een klus. Helpers uit je buurt reageren. Jij kiest wie het doet. HeitjeHulp regelt het contact, de betaling en de veiligheid.',
]

export const verhaal = {
  tekst:
    'Sanne zet een foto van haar voortuin in de app: het onkruid staat hoog. Drie helpers uit de buurt reageren. Ze kijkt naar hun sterren en leest de recensies. Ze kiest Daan (14). Zijn moeder gaf eerder al toestemming met een code. Daan komt zaterdag langs en de tuin is weer netjes. Sanne geeft hem vijf sterren. Daan krijgt zijn zakgeld en een nieuwe badge.',
  bijschrift: 'Een voorbeeld van hoe een klus verloopt',
}

export const processSteps: IconItem[] = [
  {
    icon: 'Camera',
    title: 'Klus plaatsen',
    text: 'Zeg wat er moet gebeuren en maak een foto. Kies de dag en de tijd. De prijs per klus zie je vooraf.',
  },
  {
    icon: 'MessageCircle',
    title: 'Reacties krijgen',
    text: 'Helpers uit je buurt zien je klus en reageren. Je kunt met ze chatten in de app.',
  },
  {
    icon: 'Star',
    title: 'Helper kiezen',
    text: 'Je ziet de sterren en recensies van elke helper. Jij kiest wie de klus doet.',
  },
  {
    icon: 'Wallet',
    title: 'Klaar en betalen',
    text: 'Je betaalt met saldo dat je vooraf oplaadt met iDEAL. Na de klus geef je de helper sterren en een recensie.',
  },
]

export const welDoen: string[] = [
  'Tuin, balkon of stoep bijhouden',
  'Boodschappen doen of iets ophalen',
  'Hond uitlaten, planten water geven',
  'Auto of fiets wassen',
  'Hulp met telefoon, tablet of computer',
  'Kleine klusjes in en om het huis',
]

export const rollen: Rol[] = [
  {
    icon: 'House',
    rol: 'Bewoners',
    kop: 'Hulp bij een klus in en om je huis',
    items: [
      { title: 'Voor iedereen', text: 'Iedere bewoner in Nederland kan een klus plaatsen. Jong of oud.' },
      { title: 'Jij kiest', text: 'Je ziet wie er reageert en kiest zelf op sterren en recensies.' },
      { title: 'Vaste hulp', text: 'Elke week of maand dezelfde klus? Dat kan met het abonnement Plus.' },
    ],
  },
  {
    icon: 'Sparkles',
    rol: 'Helpers',
    kop: 'Zakgeld verdienen in je eigen buurt',
    items: [
      { title: 'Vanaf 10 jaar', text: 'Er is geen maximum leeftijd. Scholieren, studenten en volwassenen zijn welkom.' },
      { title: 'Klussen dichtbij', text: 'Je ziet klussen in je buurt die passen bij je leeftijd.' },
      { title: 'Groeien', text: 'Je spaart XP en badges en stijgt in niveau.' },
    ],
  },
  {
    icon: 'Users',
    rol: 'Ouders',
    kop: 'Jij geeft toestemming',
    items: [
      { title: 'Met een code', text: 'Is je kind jonger dan 18? Dan krijg jij een code per e-mail of sms om toestemming te geven.' },
      { title: 'Eén keer', text: 'Daarna regelt je kind zijn klussen zelf in de app.' },
      { title: 'Vragen?', text: 'Neem contact op met de meldkamer van HeitjeHulp.' },
    ],
  },
  {
    icon: 'ClipboardCheck',
    rol: 'Meldkamer',
    kop: 'HeitjeHulp houdt een oogje in het zeil',
    items: [
      { title: 'Goedkeuren', text: 'De meldkamer keurt elke nieuwe helper goed voordat die kan reageren.' },
      { title: 'Helpen', text: 'Gaat er iets mis? De meldkamer helpt je verder.' },
      { title: 'Meldingen', text: 'Elke melding wordt bekeken en opgevolgd.' },
    ],
  },
]

export const helperSteps: IconItem[] = [
  {
    icon: 'UserPlus',
    title: 'Aanmelden',
    text: 'Download de app en maak een account. De meldkamer kijkt je aanmelding na.',
  },
  {
    icon: 'KeyRound',
    title: 'Jonger dan 18?',
    text: 'Je ouder krijgt een code per e-mail of sms. Met die code geeft je ouder toestemming.',
  },
  {
    icon: 'FileCheck2',
    title: '18 jaar of ouder?',
    text: 'Je hebt een VOG nodig: een Verklaring Omtrent het Gedrag. Zonder VOG kun je niet helpen.',
  },
]

export const helperBeloning: IconItem[] = [
  {
    icon: 'Coins',
    title: 'Zakgeld',
    text: 'Voor elke klus krijg je geld. HeitjeHulp betaalt het uit op je rekening.',
  },
  {
    icon: 'Trophy',
    title: 'XP en badges',
    text: 'Elke klus levert XP op. Bij bijzondere klussen verdien je een badge.',
  },
  {
    icon: 'TrendingUp',
    title: 'Niveaus',
    text: 'Hoe meer klussen en goede recensies, hoe hoger je niveau.',
  },
]

export const helperInApp: string[] = [
  'Klussen in je buurt die bij je leeftijd passen',
  'Je verdiensten per maand en per jaar',
  'Je sterren en recensies',
  'Je XP, badges en niveau',
]

export const safetyItems: IconItem[] = [
  {
    icon: 'ClipboardCheck',
    title: 'Meldkamer keurt goed',
    text: 'Elke nieuwe helper wordt eerst goedgekeurd door de meldkamer van HeitjeHulp.',
  },
  {
    icon: 'MessageCircle',
    title: 'Chat zonder nummers',
    text: 'Je chat in de app. Telefoonnummers blijven verborgen.',
  },
  {
    icon: 'ShieldAlert',
    title: 'Meldknop',
    text: 'Klopt er iets niet? Druk op de meldknop. De meldkamer kijkt mee en helpt.',
  },
  {
    icon: 'KeyRound',
    title: 'Toestemming ouder',
    text: 'Onder 18 helpt niemand zonder toestemming van een ouder, met een code.',
  },
]

export const gedragsregels: string[] = [
  'Alles loopt via de app, ook het betalen',
  'Geen contant geld',
  'Alleen de afgesproken klus doen',
  'Melden als er iets niet klopt',
]

export const kaders: Kader[] = [
  {
    key: 'betalen',
    icon: 'Wallet',
    tab: 'Betalen',
    title: 'Saldo vooraf, geen contant geld',
    intro: 'Je laadt saldo op met iDEAL. Als de klus klaar is, gaat het bedrag van je saldo af.',
    points: [
      'De prijs per klus zie je vooraf, voordat je een helper kiest.',
      'HeitjeHulp betaalt de helper uit. Je hoeft geen geld te geven.',
      'Herhaalklussen, zoals elke week de tuin, gaan met het abonnement Plus.',
    ],
  },
  {
    key: 'ouders',
    icon: 'KeyRound',
    tab: 'Ouders',
    title: 'Toestemming met een code',
    intro: 'Helpers jonger dan 18 hebben toestemming van een ouder nodig.',
    points: [
      'Je kind vult bij het aanmelden het e-mailadres of telefoonnummer van een ouder in.',
      'De ouder krijgt een code per e-mail of sms en geeft daarmee toestemming.',
      'Jonge helpers zien alleen klussen die passen bij hun leeftijd.',
    ],
  },
  {
    key: 'vog',
    icon: 'FileCheck2',
    tab: 'VOG',
    title: 'VOG voor helpers vanaf 18 jaar',
    intro: 'Ben je 18 jaar of ouder? Dan heb je een Verklaring Omtrent het Gedrag nodig.',
    points: [
      'Zonder geldige VOG kun je niet reageren op klussen.',
      'Onder 18 is geen VOG nodig. Dan geeft een ouder toestemming.',
      'De meldkamer keurt elke helper goed, jong of oud.',
    ],
  },
  {
    key: 'privacy',
    icon: 'Lock',
    tab: 'Privacy',
    title: 'Zo min mogelijk gegevens',
    intro: 'We vragen alleen wat nodig is om een klus goed te laten verlopen.',
    points: [
      'Telefoonnummers blijven verborgen. Je praat via de chat in de app.',
      // B11: de meldkamer kan elke chat lezen (besluit 4 okt).
      'De meldkamer kan chats lezen om helpers en bewoners veilig te houden.',
      'Je gegevens staan versleuteld op servers in Europa.',
    ],
  },
]

export const partnerPunten: IconItem[] = [
  {
    icon: 'Megaphone',
    title: 'Vertellen over HeitjeHulp',
    text: 'Jullie laten jongeren weten dat ze in hun buurt zakgeld kunnen verdienen.',
  },
  {
    icon: 'Handshake',
    title: 'Helpen bij de start',
    text: 'Samen helpen we jongeren op weg met hun eerste klus.',
  },
  {
    icon: 'MapPin',
    title: 'Dichtbij in de wijk',
    text: 'Jullie kennen de buurt. Zo komen bewoners en helpers sneller bij elkaar.',
  },
]

export const vragen: Vraag[] = [
  {
    vraag: 'Is HeitjeHulp de werkgever van de helpers?',
    antwoord:
      'Nee. HeitjeHulp is een bemiddelaar. We brengen bewoners en helpers bij elkaar en regelen de chat, de betaling en de veiligheid. De helper is niet bij ons in dienst.',
  },
  {
    vraag: 'Vanaf welke leeftijd kun je helpen?',
    antwoord:
      'Vanaf 10 jaar. Er is geen maximum. Ben je jonger dan 18? Dan geeft een ouder toestemming met een code. Ben je 18 of ouder? Dan heb je een VOG nodig.',
  },
  {
    vraag: 'Hoe kies ik een helper?',
    antwoord:
      'Helpers reageren op je klus. Je ziet hun sterren en recensies. Je kunt ook eerst met ze chatten. Daarna kies je er één.',
  },
  {
    vraag: 'Wat kost een klus?',
    antwoord:
      'De prijs per klus zie je vooraf in de app. Je betaalt met saldo dat je oplaadt met iDEAL. Je betaalt nooit contant.',
  },
  {
    vraag: 'Wat als er iets misgaat?',
    antwoord:
      'Druk op de meldknop in de app. De meldkamer van HeitjeHulp kijkt mee en helpt je verder.',
  },
  {
    vraag: 'Kan ik HeitjeHulp al gebruiken?',
    antwoord:
      'De app en de webapp komen binnenkort. Wil je een bericht als het zover is? Of wil je partner worden? Mail ons op info@heitjehulp.nl.',
  },
]

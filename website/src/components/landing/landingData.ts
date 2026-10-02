// Inhoud van de HeitjeHulp-voorpagina. Bron: pilotvoorstel v5 (kleine start,
// geen subsidie) en wat er in de app echt gebouwd is (M0-M10, M14).
// Bewust NIET publiek: bedragen, tarieven, begroting, verdienmodel, namen van
// partners en concurrenten. Zie App.test.tsx, die dat bewaakt.

export interface NavLink {
  href: string
  label: string
}

export interface Stat {
  value: string
  label: string
}

export interface IconItem {
  icon: string
  title: string
  text: string
}

export type KaderKey = 'juridisch' | 'vog' | 'verzekering' | 'avg'

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

export interface Fase {
  label: string
  title: string
  text: string
}

export interface Vraag {
  vraag: string
  antwoord: string
}

export const navLinks: NavLink[] = [
  { href: '#werkwijze', label: 'Werkwijze' },
  { href: '#voor-wie', label: 'Voor wie' },
  { href: '#veiligheid', label: 'Veiligheid' },
  { href: '#kaders', label: 'Vooraf geregeld' },
  { href: '#proef', label: 'De proef' },
  { href: '#vragen', label: 'Vragen' },
]

export const heroPoints: string[] = [
  'Jongeren van 16 t/m 20, volledig gescreend met VOG',
  'Aanmelden via app, website of telefoon',
  'Familie kan meekijken, de oudere houdt de regie',
]

export const problemText: string[] = [
  'Steeds meer ouderen wonen zelfstandig thuis, terwijl de kring die hen bij kleine dingen helpt kleiner wordt. Kinderen wonen verder weg, buren kennen elkaar minder en de druk op mantelzorgers en wijkteams loopt op. Juist de kleine dingen blijven liggen: te klein voor een indicatie, maar het verschil tussen zelfredzaam zijn en vastlopen.',
  'Tegelijk staan jongeren die iets willen betekenen voor hun buurt langs de zijlijn. Het vrijwilligersbestand vergrijst; jongeren zitten er nauwelijks in. HeitjeHulp verbindt die twee — veilig, lokaal en herleidbaar.',
]

export const helpTypes: string[] = [
  'Boodschappen en kleine praktische hulp',
  'Hulp met telefoon, tablet of computer',
  'Kleine klusjes in en om het huis',
  'Tuin of balkon bijhouden, afval wegbrengen',
  'Begeleiding naar een afspraak',
]

export const verhaal = {
  tekst:
    'Mevrouw Jansen (81) belt het aanmeldpunt: de lamp in haar keuken is kapot en ze durft de trap niet meer op. De hulpvraag wordt genoteerd en ze krijgt een bevestiging. Youssef (16), gescreend en uit dezelfde straat, ziet de klus in de app en komt na school langs. Hij vervangt de lamp, neemt de tijd voor een praatje en rondt de klus af. De volgende keer vraagt mevrouw Jansen gewoon weer naar Youssef.',
  bijschrift: 'Een voorbeeld van hoe een klus verloopt',
}

export const processSteps: IconItem[] = [
  {
    icon: 'PhoneCall',
    title: 'Aanmelden',
    text: 'De oudere meldt een hulpvraag aan via de app, de website of telefonisch — of een familielid, mantelzorger of het wijkteam doet het namens haar.',
  },
  {
    icon: 'MapPin',
    title: 'Oppakken',
    text: 'Een gescreende jongere uit dezelfde wijk ziet de klus en neemt hem aan. De oudere ziet vooraf wie er komt.',
  },
  {
    icon: 'HandHeart',
    title: 'Uitvoeren',
    text: 'De jongere laat weten dat hij onderweg is, doet de klus en rondt hem af. Elke stap wordt vastgelegd.',
  },
  {
    icon: 'Star',
    title: 'Beoordelen',
    text: 'Oudere en jongere beoordelen elkaar. Bij een goede ervaring vraagt de oudere dezelfde jongere opnieuw.',
  },
]

export const welDoen: string[] = [
  'Boodschappen doen',
  'Kleine klusjes in en om het huis',
  'Hulp met telefoon, tablet of computer',
  'Begeleiding naar een afspraak',
  'Tuin of balkon bijhouden, afval wegbrengen',
  'Een praatje bij elke klus',
]

export const nietDoen: string[] = [
  'Persoonlijke verzorging of medische handelingen',
  'Structurele huishoudelijke hulp',
  'Geld- of administratiebeheer',
  'Alles wat onder een Wmo-indicatie of zorgaanbod valt',
  'Georganiseerd gezelschap — daarvoor verwijzen we naar welzijn',
]

export const rollen: Rol[] = [
  {
    icon: 'Heart',
    rol: 'Ouderen',
    kop: 'Hulp vragen zonder gedoe',
    items: [
      { title: 'Groot en rustig', text: 'Grote knoppen, grote letters en weinig stappen. Geen cijfers of drukte op het scherm.' },
      { title: 'Zien wie er komt', text: 'Vooraf weten welke jongere komt, en een melding als hij onderweg is.' },
      { title: 'Zonder smartphone', text: 'Telefonisch aanmelden kan altijd; de meldkamer zet de hulpvraag in het systeem.' },
    ],
  },
  {
    icon: 'Users',
    rol: 'Familie',
    kop: 'Meekijken op afstand',
    items: [
      { title: 'Met toestemming', text: 'De oudere bepaalt wie meekijkt en wat die mag zien; toestemming intrekken kan altijd.' },
      { title: 'Namens aanmelden', text: 'Een familielid kan een hulpvraag plaatsen voor de oudere.' },
      { title: 'Op de hoogte', text: 'Meldingen bij de belangrijke momenten van een klus.' },
    ],
  },
  {
    icon: 'GraduationCap',
    rol: 'Jongeren',
    kop: 'Iets betekenen in je eigen buurt',
    items: [
      { title: 'Klussen in de buurt', text: 'Een kaart met open hulpvragen dichtbij; aannemen met één knop.' },
      { title: 'Stap voor stap', text: 'Onderweg, bezig, klaar — de app begeleidt elke klus en legt hem vast.' },
      { title: 'Altijd een achtervang', text: 'Een vaste knop om iets te melden dat niet klopt, en een vertrouwenspersoon.' },
    ],
  },
  {
    icon: 'ClipboardCheck',
    rol: 'Coördinator',
    kop: 'De meldkamer houdt overzicht',
    items: [
      { title: 'Alle hulpvragen', text: 'Zien welke klus te lang wacht, zelf koppelen, vrijgeven of annuleren.' },
      { title: 'Screening', text: 'Document, selfie, VOG en intake van elke jongere beoordelen, altijd met een notitie.' },
      { title: 'Meldingen opvolgen', text: 'Incidenten en signalen komen direct binnen en worden afgehandeld en vastgelegd.' },
    ],
  },
]

export const safetyItems: IconItem[] = [
  {
    icon: 'IdCard',
    title: 'Identiteit & selfie',
    text: 'Controle van een geldig identiteitsbewijs en een eenmalige selfie, handmatig beoordeeld. Geen gezichtsherkenning.',
  },
  {
    icon: 'FileCheck2',
    title: 'Geldige VOG',
    text: 'Verplicht voor elke jongere. Verloopt de VOG, dan kan de jongere niet meer gekoppeld worden.',
  },
  {
    icon: 'Users',
    title: 'Persoonlijke intake',
    text: 'Een kennismakingsgesprek met gedragsregels en uitleg over wat je doet als je iets ziet dat niet klopt.',
  },
  {
    icon: 'ShieldCheck',
    title: 'Meldknop & opvolging',
    text: 'Jongeren melden zorgen via een vaste knop. Wij beoordelen en schakelen waar nodig het wijkteam in.',
  },
]

export const gedragsregels: string[] = [
  'Nooit contant geld aannemen',
  'Alleen komen op de afgesproken tijd',
  'Alleen de afgesproken klus doen',
  'Alles melden wat afwijkt',
]

export const kaders: Kader[] = [
  {
    key: 'juridisch',
    icon: 'Scale',
    tab: 'Juridische vorm',
    title: 'Vrijwilligers van een stichting zonder winstoogmerk',
    intro:
      'De jongeren zijn vrijwilliger van Stichting HeitjeHulp. Zij krijgen een bescheiden vrijwilligersvergoeding binnen de wettelijke norm — aantoonbaar geen loon.',
    points: [
      'Geen dienstverband, geen zzp-constructie en geen werkgeversrol voor de gemeente.',
      'Het platform bewaakt de wettelijke maxima van de vrijwilligersvergoeding automatisch.',
      'Elke jongere tekent een deelnemersafspraak; bij minderjarigen tekenen de ouders mee.',
      'Bescherming van minderjarigen: geen inzet laat op de avond, school gaat altijd voor.',
    ],
  },
  {
    key: 'vog',
    icon: 'FileCheck2',
    tab: 'VOG & screening',
    title: 'Volledig gescreend vóór de eerste klus',
    intro: 'Geen enkele jongere wordt actief voordat de hele screening is doorlopen.',
    points: [
      'Identiteitsbewijs (BSN afgeschermd) en selfie, handmatig beoordeeld.',
      'Een geldige Verklaring Omtrent het Gedrag, aangevraagd door de stichting.',
      'Een persoonlijk intakegesprek met gedragsregels en instructie over signaleren.',
      'Bij twijfel wordt een match beëindigd, zonder discussie.',
    ],
  },
  {
    key: 'verzekering',
    icon: 'ShieldCheck',
    tab: 'Verzekering',
    title: 'Schade nooit op het bordje van de jongere',
    intro:
      'Klussen tellen alleen als ze via het platform zijn vastgelegd. Zo is elke klus herleidbaar en valt hij onder de verzekering die vóór de start geregeld wordt.',
    points: [
      'Uitgangspunt is de gemeentelijke vrijwilligersverzekering; anders sluit de stichting zelf een polis af.',
      'Schade wordt gemeld bij de stichting, nooit bij de jongere persoonlijk.',
      'Klussen buiten het platform om vallen er niet onder — dat staat in de gedragsregels.',
    ],
  },
  {
    key: 'avg',
    icon: 'Lock',
    tab: 'Privacy',
    title: 'Zo min mogelijk gegevens',
    intro: 'HeitjeHulp werkt met twee kwetsbare groepen. Privacy is daarom een ontwerpkeuze, geen sluitstuk.',
    points: [
      'Van ouderen: naam, adres, telefoon en de hulpvraag in neutrale woorden — geen medische redenen.',
      'Geen BSN, geen biometrie, geen gezondheidsgegevens.',
      'Servers binnen de EER, versleuteld; alleen wie het nodig heeft, kan erbij.',
      'Rapportages bevatten alleen totalen, nooit gegevens die naar een persoon te herleiden zijn.',
    ],
  },
]

export const proefStats: Stat[] = [
  { value: '5', label: 'ouderen' },
  { value: '5', label: 'jongeren' },
  { value: '1', label: 'wijk' },
  { value: '8', label: 'weken' },
]

export const fases: Fase[] = [
  {
    label: 'Stap 1',
    title: 'Proef',
    text: 'Vijf ouderen en vijf jongeren in één wijk, acht weken. Bewijzen dat aanmelden, oppakken, uitvoeren en beoordelen in de praktijk werken — ook voor een oudere zonder smartphone.',
  },
  {
    label: 'Stap 2',
    title: 'Uitbreiding',
    text: 'Alleen als de proef slaagt, groeien we voorzichtig door. Wat "geslaagd" betekent, spreken we vooraf af.',
  },
  {
    label: 'Stap 3',
    title: 'Structureel',
    text: 'Pas daarna bespreken we samen met partners of en hoe HeitjeHulp blijvend in de wijk past.',
  },
]

export const aanvullend: IconItem[] = [
  {
    icon: 'HandHeart',
    title: 'Aanvullend, niet vervangend',
    text: 'We pakken de kleine hulpvragen op die nu blijven liggen. Wat bij welzijn, zorg of de Wmo hoort, laten we daar.',
  },
  {
    icon: 'GraduationCap',
    title: 'Een nieuwe groep vrijwilligers',
    text: 'Jongeren van 16 t/m 20 zijn in het bestaande vrijwilligersbestand vrijwel afwezig. Wij vergroten de vijver.',
  },
  {
    icon: 'MapPin',
    title: 'Eigen wijk, vast gezicht',
    text: 'Hulp uit de eigen buurt, en bij een goede klik steeds dezelfde jongere. Dat bouwt vertrouwen.',
  },
]

export const results: string[] = [
  'Aantal en soort uitgevoerde hulpvragen',
  'Actieve ouderen en jongeren',
  'Hoeveel aanmeldingen telefonisch of namens de oudere binnenkwamen',
  'Tevredenheid van ouderen en jongeren',
  'Incidenten en hoe ze zijn opgevolgd',
]

export const vragen: Vraag[] = [
  {
    vraag: 'Wie zijn de jongeren?',
    antwoord:
      'Jongeren van 16 t/m 20 jaar uit de eigen wijk. Ze zijn vrijwilliger van Stichting HeitjeHulp, hebben een geldige VOG en een intakegesprek gehad, en worden begeleid door iemand met jarenlange ervaring in het jongerenwerk.',
  },
  {
    vraag: 'Mijn moeder heeft geen smartphone. Kan zij meedoen?',
    antwoord:
      'Ja. Aanmelden kan telefonisch, en een familielid, mantelzorger of het wijkteam kan ook namens haar een hulpvraag plaatsen. Zij krijgt altijd een bevestiging.',
  },
  {
    vraag: 'Kan ik als familielid meekijken?',
    antwoord:
      'Ja, als de oudere daar toestemming voor geeft. Zij bepaalt wat u mag zien en kan de toestemming altijd weer intrekken.',
  },
  {
    vraag: 'Wat als er iets misgaat?',
    antwoord:
      'Jongeren melden alles wat afwijkt via een vaste knop in de app. De meldkamer volgt elke melding op en schakelt waar nodig het wijkteam in. Schade wordt bij de stichting gemeld, nooit bij de jongere persoonlijk.',
  },
  {
    vraag: 'Wat kost het?',
    antwoord:
      'De oudere betaalt een kleine bijdrage per klus. Daarvan krijgt de jongere een vrijwilligersvergoeding binnen de wettelijke norm. Het precieze tarief hoort u bij de aanmelding; HeitjeHulp maakt geen winst.',
  },
  {
    vraag: 'Is HeitjeHulp al te gebruiken?',
    antwoord:
      'De app is gebouwd en een eerste kleine proef is in voorbereiding. Wilt u meedoen als oudere, jongere of partnerorganisatie? Neem contact met ons op.',
  },
]

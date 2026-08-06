// Inhoud van de BuurtHulp-landingspagina, afgeleid van het gemeentelijke
// pilotvoorstel (v2). Eén bron voor alle teksten zodat de pagina-opbouw
// in LandingPage.tsx zuiver presentatie blijft.

export interface NavLink {
  href: string
  label: string
}

export interface Stat {
  value: string
  label: string
}

export interface ProcessStep {
  icon: string
  title: string
  text: string
}

export interface SafetyItem {
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
  footnote?: string
}

export interface BudgetPost {
  label: string
  detail: string
  amount: string
}

export interface DeliveryItem {
  title: string
  text: string
}

export interface CompetitorItem {
  name: string
  text: string
}

export interface Differentiator {
  icon: string
  title: string
  text: string
}

export interface FeatureGroup {
  audience: string
  icon: string
  items: { title: string; text: string }[]
}

export const navLinks: NavLink[] = [
  { href: '#oplossing', label: 'Oplossing' },
  { href: '#werkwijze', label: 'Werkwijze' },
  { href: '#veiligheid', label: 'Veiligheid' },
  { href: '#kaders', label: 'Vooraf geregeld' },
  { href: '#begroting', label: 'Begroting' },
  { href: '#functies', label: 'Functies' },
  { href: '#pilot', label: 'Pilot' },
]

export const heroPoints: string[] = [
  'Gescreende jongeren met VOG',
  'Telefonisch aanmeldpunt voor niet-digitale ouderen',
  'Juridisch, verzekerd en AVG-proof vooraf dichtgetimmerd',
]

export const problemText: string[] = [
  'Steeds meer ouderen wonen langer zelfstandig thuis, terwijl de kring die hen helpt kleiner wordt. Juist de kleine dingen blijven liggen — een zware boodschappentas, een lamp die te hoog hangt, een digitaal formulier, een tuin die dichtgroeit. Te klein voor een zorgindicatie, te veel om steeds aan familie te vragen.',
  'Tegelijk staan veel jongeren langs de zijlijn. Ze willen iets betekenen, werkervaring opdoen en bijverdienen, maar vinden moeilijk een ingang. BuurtHulp verbindt die behoefte en die energie — veilig, lokaal en meetbaar.',
]

export const pilotStats: Stat[] = [
  { value: '100', label: 'deelnemende ouderen' },
  { value: '50', label: 'gescreende jongeren' },
  { value: '500', label: 'hulpvragen als doel' },
  { value: '6', label: 'maanden looptijd' },
]

export const helpTypes: string[] = [
  'Boodschappen en kleine praktische hulp',
  'Digitale hulp met telefoon, tablet of computer',
  'Kleine klusjes in en rondom het huis',
  'Gezelschap en begeleiding',
]

export const processSteps: ProcessStep[] = [
  {
    icon: 'PhoneCall',
    title: 'Aanmelden',
    text: 'De oudere meldt een hulpvraag aan via de app, de website of het telefonisch aanmeldpunt — ook via familie, mantelzorger of wijkteam.',
  },
  {
    icon: 'MapPin',
    title: 'Matchen',
    text: 'Een gescreende jongere uit dezelfde wijk ziet de hulpvraag en pakt hem op. Koppeling op wijkniveau, geen vreemde van ver weg.',
  },
  {
    icon: 'HandHeart',
    title: 'Uitvoeren',
    text: 'De jongere voert de klus uit tegen een eerlijke vergoeding. Elke klus is geregistreerd, verzekerd en herleidbaar.',
  },
  {
    icon: 'Star',
    title: 'Beoordelen',
    text: 'Oudere en jongere beoordelen elkaar. Bij een goede klik komt dezelfde vertrouwde helper terug.',
  },
]

export const safetyItems: SafetyItem[] = [
  {
    icon: 'IdCard',
    title: 'Identiteit & selfie',
    text: 'Controle op een geldig identiteitsbewijs met eenmalige selfie-verificatie — geen biometrisch profiel.',
  },
  {
    icon: 'Phone',
    title: 'Telefoon & bank',
    text: 'Verificatie van telefoonnummer en bankrekening voordat een jongere actief wordt.',
  },
  {
    icon: 'FileCheck2',
    title: 'Geldige VOG',
    text: 'Verklaring Omtrent het Gedrag verplicht voor iedereen die bij ouderen thuiskomt.',
  },
  {
    icon: 'Users',
    title: 'Intake & reviews',
    text: 'Persoonlijk intakegesprek, wederzijdse beoordeling per klus en een heldere meld- en klachtenprocedure.',
  },
]

export const kaders: Kader[] = [
  {
    key: 'juridisch',
    icon: 'Scale',
    tab: 'Juridische vorm',
    title: 'Onbelaste vrijwilligersvergoeding, met harde drempelbewaking',
    intro:
      'De juridische status van de jongeren is bewust het eerste wat is dichtgetimmerd. Tijdens de pilot werkt BuurtHulp uitsluitend met de onbelaste vrijwilligersvergoeding — de eenvoudigste en fiscaal meest robuuste vorm.',
    points: [
      'Maxima 2026: € 220 per maand, € 2.200 per jaar, € 3,40 per uur (onder 21 jaar). Het platform bewaakt deze grenzen automatisch.',
      'Geen dienstverband en geen ZZP-constructie — dus geen schijnzelfstandigheid en geen werkgeversrol of fiscaal risico voor de gemeente.',
      'Minimumleeftijd 16 jaar; de Arbeidstijdenwet wordt vrijwillig als kader voor de inroostering aangehouden.',
      'De vergoeding wordt expliciet als onkostenvergoeding vormgegeven, niet als loon per klus; waar gewenst vraagt BuurtHulp de Belastingdienst om vooroverleg.',
    ],
    footnote:
      'Bedragen op basis van de meest actuele bekendmakingen; definitieve 2026-tarieven worden vóór de start bij de Belastingdienst geverifieerd.',
  },
  {
    key: 'vog',
    icon: 'FileCheck2',
    tab: 'VOG & screening',
    title: 'Volledig gescreend vóór de eerste hulpvraag',
    intro:
      'Geen enkele jongere wordt actief gezet voordat de complete screening is doorlopen. De VOG-fase wordt volledig vóór de operationele start gepland, met buffer voor de doorlooptijd.',
    points: [
      'VOG digitaal € 33,85 per aanvraag (50 × € 33,85 = € 1.692,50), verwerkt in de begroting. Balieroute € 41,35 als bovengrens.',
      'Doorlooptijd 1 tot 4 weken; BuurtHulp plant met de bovengrens, zodat de pilot vanaf dag één met gescreende jongeren start.',
      'Via een reeds toegelaten welzijns- of vrijwilligerspartner kan de Regeling Gratis VOG de kosten tot vrijwel nul terugbrengen.',
      'Naast de VOG: identiteits-, selfie-, telefoon- en bankrekeningverificatie plus een persoonlijk intakegesprek.',
    ],
  },
  {
    key: 'verzekering',
    icon: 'ShieldCheck',
    tab: 'Verzekering',
    title: 'Platformbrede dekking, vooraf geregeld',
    intro:
      'Hulp aan huis kan misgaan — dat is het grootste reële risico. Daarom regelt BuurtHulp zelf een sluitende, platformbrede dekking voor elke geregistreerde klus, vergelijkbaar met hoe Charly Cares dit met verzekeraar Aon opzette.',
    points: [
      'Bedrijfsaansprakelijkheid (AVB): zaak- en letselschade bij de oudere thuis wordt via de polis van BuurtHulp afgewikkeld, niet via de jongere persoonlijk.',
      'Collectieve ongevallenverzekering voor de jongere, met een 24/7 medische assistentielijn bij een incident.',
      'Rechtsbijstand bij geschillen, zodat niemand met juridische kosten blijft zitten.',
      'De gemeente draagt geen aansprakelijkheid en hoeft haar eigen vrijwilligersverzekering hier niet voor in te zetten.',
    ],
  },
  {
    key: 'avg',
    icon: 'Lock',
    tab: 'Privacy (AVG)',
    title: 'Privacy by design voor een kwetsbare doelgroep',
    intro:
      'BuurtHulp verwerkt gegevens van twee groepen die de wetgever als kwetsbaar aanmerkt. Privacy is geen sluitstuk maar een ontwerpprincipe: dataminimalisatie en privacy by design en by default.',
    points: [
      'Alleen strikt noodzakelijke gegevens; geen profilering, geen geautomatiseerde besluiten, geen verkoop aan derden.',
      'Opslag binnen de EER, versleuteld in transit en at rest, toegang op basis van least privilege met logging.',
      'Verwerkersovereenkomst conform het VNG-model én een DPIA worden vóór de start opgeleverd en met de gemeente gedeeld.',
      'Korte bewaartermijnen en eenvoudig uit te oefenen rechten — ook telefonisch of via een familielid.',
    ],
  },
]

export const budgetTotal = '€ 5.602,50'
export const budgetPerMonth = '€ 934'
export const budgetToFinance = '€ 4.102,50'

export const budgetPosts: BudgetPost[] = [
  { label: 'VOG-screening', detail: '50 × € 33,85 (mogelijk € 0 via Gratis VOG)', amount: '€ 1.692,50' },
  { label: 'Verzekering', detail: 'aansprakelijkheid + ongevallen, 6 mnd', amount: '€ 1.500' },
  { label: 'Communicatiemateriaal', detail: 'flyers, wijkbrieven, materiaal wijkteams/scholen', amount: '€ 1.500' },
  { label: 'Onvoorzien (±10%)', detail: 'marge voor extra VOG’s, toegankelijkheid, kleine bijstellingen', amount: '€ 510' },
  { label: 'Overige verificatie', detail: 'identiteit, selfie, telefoon, bank — ca. € 8 p.p.', amount: '€ 400' },
  { label: 'Platform & coördinatie', detail: 'matching, planning, screening-flow en rapportage — geautomatiseerd, kosteloos', amount: '€ 0' },
  { label: 'Telefonisch aanmeldpunt', detail: 'opzet en bemensing — kosteloos door de initiatiefnemer', amount: '€ 0' },
]

export const budgetHonesty: string[] = [
  'De coördinatie loopt grotendeels via het platform: matching, planning, screening-workflow, drempelbewaking, reviews, meldingen-triage en de rapportage aan de gemeente gebeuren geautomatiseerd. De menselijke begeleiding — intakegesprekken, incident-opvolging en contact met ouderen en families — verzorgen de initiatiefnemer en een klein team van 2 à 3 vrijwilligers, tijdens de pilot kosteloos. Daardoor vervalt de dure coördinatorpost en daalt de begroting naar € 5.602,50, zonder in te leveren op de menselijke maat.',
  'De hulpvrager betaalt de kluskosten: van een bruto klusbedrag (voorbeeld € 20) gaat € 17 als forfaitaire onkostenvergoeding naar de jongere en houdt BuurtHulp € 3 commissie. Bij 500 klussen is dat circa € 1.500, dat in mindering komt op de gevraagde bijdrage.',
  'Na aftrek van die commissie resteert een te financieren bedrag van circa € 4.102,50 over 6 maanden. Met gratis VOG via een welzijnspartner (− € 1.692,50) en de VNG Vrijwilligersverzekering (− ± € 1.500) kan de gevraagde gemeentebijdrage richting nul gaan.',
]

export const buurthulpDelivers: DeliveryItem[] = [
  { title: 'Platform & aanmeldpunt — gratis', text: 'App, website, backend én het telefonisch aanmeldpunt worden kosteloos door de initiatiefnemer verzorgd; deze posten staan op € 0 in de begroting.' },
  { title: 'Geautomatiseerde coördinatie', text: 'Matching, planning, screening-flow, drempelbewaking, reviews en rapportage lopen via het platform — geen betaalde coördinator nodig.' },
  { title: 'Menselijke begeleiding door vrijwilligers', text: 'De initiatiefnemer en 2 à 3 vrijwilligers doen intake, incident-opvolging en contact met ouderen en families — onbetaald tijdens de pilot.' },
  { title: 'Veiligheid, privacy & rapportage', text: 'Compleet screenings- en veiligheidsprotocol, AVG-kader en een eindrapportage met onderbouwd opschalingsadvies.' },
]

export const municipalityDelivers: DeliveryItem[] = [
  { title: 'Cofinanciering', text: `Na aftrek van eigen inkomsten resteert een te financieren bedrag van circa ${budgetToFinance} over 6 maanden; verdeling stellen we samen vast.` },
  { title: 'Toegang & introductie', text: 'Verbinding met wijkteams, jongerenwerk, scholen en welzijnsorganisaties, plus een pilotwijk.' },
  { title: 'Communicatie', text: 'Ondersteuning richting ouderen en mantelzorgers via gemeentekanalen, wijkbladen en buurtnetwerken.' },
]

export const competitors: CompetitorItem[] = [
  { name: 'BUUV', text: 'Buurtmarktplaats voor wederkerige, onbetaalde burenhulp tussen bewoners.' },
  { name: 'WeHelpen', text: 'Landelijk platform voor informele hulp en mantelzorg, met een credits-systeem.' },
  { name: 'Vrijwilligerscentrales', text: 'Lokale bemiddeling, maar met een overwegend vergrijzend vrijwilligersbestand.' },
  { name: 'Helpling / Charly Cares', text: 'Betaalde, gescreende platforms — maar gericht op één dienst en een digitaal publiek.' },
]

export const differentiators: Differentiator[] = [
  { icon: 'BadgeCheck', title: 'Gescreende jongeren met VOG', text: 'Complete screening gekoppeld aan een brede waaier van kleine hulpvragen — het vertrouwensniveau dat hulp aan huis vraagt.' },
  { icon: 'Banknote', title: 'Betaald werk voor jongeren', text: 'Een betrouwbare vergoeding verbreedt de groep naar een leeftijd die in het vrijwilligersbestand juist ontbreekt.' },
  { icon: 'PhoneCall', title: 'Telefonisch aanmeldpunt', text: 'Bereikt de niet-digitale ouderen die bij puur digitale platforms buiten beeld blijven.' },
  { icon: 'GraduationCap', title: 'Jongerenparticipatie als doel', text: 'Eén pilot dient twee beleidsterreinen: ouderenhulp én werkervaring voor jongeren.' },
  { icon: 'MapPin', title: 'Eigen wijk, vast gezicht', text: 'Koppeling op wijkniveau met herhaalde inzet van dezelfde jongere versterkt vertrouwen en verbinding.' },
]

export const featureGuardrail =
  'Gamificatie kan averechts werken als beloningen aan snelheid of aantallen hangen — jongeren gaan dan optimaliseren op volume, ten koste van kwetsbare ouderen. Daarom geldt voor álle functies één onwrikbaar principe: beloningen hangen aan kwaliteit, niet aan kwantiteit. De beoordeling van de oudere weegt structureel zwaarder dan het aantal klussen.'

export const featureGroups: FeatureGroup[] = [
  {
    audience: 'Voor jongeren',
    icon: 'Trophy',
    items: [
      { title: 'Punten & niveaus', text: 'Van Buurthelper naar Wijkheld naar Buurtlegende — doorgroeien lukt alleen met aanhoudend hoge beoordelingen.' },
      { title: 'Badges & reeksen', text: 'Erkenning voor terugkerende ouderen, uitstekende reviews en betrouwbare, regelmatige inzet.' },
      { title: 'Bonus voor lastige klussen', text: 'Klussen die anders blijven liggen leveren extra punten op — en lossen zo het matchingprobleem op.' },
      { title: 'Verzilverbare punten', text: 'In te wisselen voor een cadeaubon, lokaal tegoed of een donatie aan een goed doel.' },
      { title: 'Werkervaringscertificaat', text: 'Een door de gemeente erkend certificaat voor het cv, gekoppeld aan kwaliteit en betrouwbaarheid.' },
    ],
  },
  {
    audience: 'Voor ouderen',
    icon: 'Heart',
    items: [
      { title: 'Vaste favoriete helper', text: 'Na een goede ervaring dezelfde jongere instellen, zodat vertrouwen en bekendheid groeien.' },
      { title: 'Toegankelijkheidsmodus', text: 'Grote knoppen, groot lettertype en eenvoudige stappen — het telefoonnummer blijft altijd alternatief.' },
      { title: 'Gezelschap als categorie', text: 'Een praatje krijgt een eigen, gelijkwaardige plek; precies de kern van eenzaamheidsbestrijding.' },
      { title: 'Bevestiging voor familie', text: 'Met toestemming een korte bevestiging en foto na afloop, voor gemoedsrust bij familie op afstand.' },
    ],
  },
  {
    audience: 'Voor wijk & gemeente',
    icon: 'LineChart',
    items: [
      { title: 'Live wijk-impactdashboard', text: 'Actueel, geaggregeerd beeld van hulpvragen en verbinding — geschikt voor verantwoording en beleid.' },
      { title: 'Team-uitdagingen met scholen', text: 'Klassen zetten zich als team in voor de wijk, met doelen die op kwaliteit sturen.' },
      { title: 'Seizoensacties', text: 'Thema-acties zoals tuin winterklaar maken of extra aandacht rond de feestdagen.' },
      { title: 'Verhalenmuur', text: 'Positieve ervaringen van ouderen en jongeren maken de menselijke waarde zichtbaar.' },
    ],
  },
]

export const results: string[] = [
  'Aantal uitgevoerde hulpvragen (doel: 500) en het type hulp',
  'Aantal actief deelnemende ouderen en jongeren',
  'Tevredenheid van ouderen en jongeren via wederzijdse beoordelingen',
  'Aandeel ouderen dat terugkeert naar dezelfde, vertrouwde helper',
  'Doorlooptijd tussen aanmelding en uitvoering van een hulpvraag',
  'Bereik via het telefonisch aanmeldpunt onder niet-digitale ouderen',
  'Aantal en type incidenten, en hoe deze zijn afgehandeld',
  'Indicatoren rond eenzaamheid en sociale verbinding (begin- en eindmeting)',
  'Jongerenparticipatie: opgedane werkervaring en behaalde certificaten',
]

export const nextSteps: string[] = [
  'Een oriënterend gesprek met de betrokken beleidsmedewerker(s).',
  'Samen de pilotwijk, de cofinancieringsverdeling en een contactpersoon vaststellen.',
  'Afspraken sluiten: pilotovereenkomst, verwerkersovereenkomst en DPIA vóór de start.',
  'Voorbereiding: werving en screening van jongeren, inrichting aanmeldpunt en communicatie.',
  'Start van de pilot, met vaste evaluatiemomenten en een eindrapportage met opschalingsadvies.',
]

export const visionText =
  'BuurtHulp wil uitgroeien tot een vertrouwd platform dat in elke wijk gescreende jongeren en kwetsbare ouderen veilig verbindt — waar een oudere weet dat er altijd een bekend, betrouwbaar gezicht langskomt, en een jongere ervaart wat het betekent om iets voor een ander en de eigen buurt te doen.'

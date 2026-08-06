export type HelpRequestStatus = 'Nieuw' | 'Gematcht' | 'In uitvoering' | 'Afgerond'
export type ScreeningStatus = 'Compleet' | 'VOG nodig' | 'Intake gepland'
export type IncidentSeverity = 'Laag' | 'Middel' | 'Hoog'
export type IncidentStatus = 'Open' | 'In behandeling' | 'Afgehandeld'
export type HelperJobStatus = 'Geaccepteerd' | 'Onderweg' | 'Afgerond'

export type HelpRequest = {
  id: string
  resident: string
  type: string
  neighborhood: string
  status: HelpRequestStatus
  requestedAt: string
  priority: 'Normaal' | 'Hoog'
  helper?: string
}

export type HelperProfile = {
  id: string
  name: string
  age: number
  neighborhood: string
  screening: ScreeningStatus
  completedJobs: number
  rating: string
}

export type ActivityItem = {
  id: string
  label: string
  meta: string
}

export type Incident = {
  id: string
  summary: string
  neighborhood: string
  severity: IncidentSeverity
  status: IncidentStatus
  reportedAt: string
}

export type ReportMetric = {
  label: string
  value: number
  target: number
  unit?: string
}

export type Opportunity = {
  id: string
  title: string
  type: string
  time: string
  distance: string
  fee: string
  points: number
  bonus?: boolean
}

export type HelperJob = {
  id: string
  title: string
  resident: string
  time: string
  fee: string
  points: number
  status: HelperJobStatus
}

export type Badge = {
  id: string
  label: string
  icon: string
  earned: boolean
}

export type ResidentRequest = {
  id: string
  title: string
  type: string
  date: string
  status: HelpRequestStatus
  helper?: string
  rated?: boolean
}

/* ---------- ADMIN ---------- */

export const adminStats = [
  { label: 'Nieuwe hulpvragen', value: '18', change: '+6 deze week' },
  { label: 'Actieve jongeren', value: '42', change: '12 volledig gescreend' },
  { label: 'Afgeronde klussen', value: '317', change: '96% tevredenheid' },
  { label: 'Open meldingen', value: '2', change: '1 opvolging vandaag' },
]

export const helpRequests: HelpRequest[] = [
  { id: 'HV-1042', resident: 'Mevrouw De Vries', type: 'Boodschappen', neighborhood: 'Centrum', status: 'Nieuw', requestedAt: 'Vandaag 09:20', priority: 'Normaal' },
  { id: 'HV-1041', resident: 'Meneer Aksoy', type: 'Smartphonehulp', neighborhood: 'Oost', status: 'Nieuw', requestedAt: 'Vandaag 08:45', priority: 'Hoog' },
  { id: 'HV-1040', resident: 'Mevrouw Visser', type: 'Gezelschap', neighborhood: 'Centrum', status: 'Gematcht', requestedAt: 'Vandaag 08:10', priority: 'Normaal', helper: 'Nora Bakker' },
  { id: 'HV-1038', resident: 'Mevrouw Jansen', type: 'Tuin opruimen', neighborhood: 'Noord', status: 'In uitvoering', requestedAt: 'Gisteren 16:10', priority: 'Normaal', helper: 'Yassine de Jong' },
  { id: 'HV-1035', resident: 'Meneer Bakker', type: 'Lamp vervangen', neighborhood: 'West', status: 'In uitvoering', requestedAt: 'Gisteren 14:30', priority: 'Hoog', helper: 'Samir El Amrani' },
  { id: 'HV-1030', resident: 'Mevrouw Smit', type: 'Afval wegbrengen', neighborhood: 'Oost', status: 'Afgerond', requestedAt: 'Gisteren 11:00', priority: 'Normaal', helper: 'Yassine de Jong' },
]

export const helpers: HelperProfile[] = [
  { id: 'J-221', name: 'Yassine de Jong', age: 19, neighborhood: 'Centrum', screening: 'Compleet', completedJobs: 24, rating: '4.9' },
  { id: 'J-219', name: 'Nora Bakker', age: 18, neighborhood: 'Oost', screening: 'VOG nodig', completedJobs: 7, rating: '4.8' },
  { id: 'J-214', name: 'Samir El Amrani', age: 20, neighborhood: 'Noord', screening: 'Intake gepland', completedJobs: 0, rating: '-' },
  { id: 'J-210', name: 'Fleur Hendriks', age: 17, neighborhood: 'West', screening: 'Compleet', completedJobs: 15, rating: '5.0' },
  { id: 'J-208', name: 'Daan Visser', age: 16, neighborhood: 'Centrum', screening: 'VOG nodig', completedJobs: 3, rating: '4.7' },
]

export const activityItems: ActivityItem[] = [
  { id: 'A-1', label: 'Nieuwe hulpvraag aangemeld via telefoonlijn', meta: 'Centrum · 12 minuten geleden' },
  { id: 'A-2', label: 'VOG-status bijgewerkt voor jongere', meta: 'Oost · 43 minuten geleden' },
  { id: 'A-3', label: 'Klus afgerond met positieve review', meta: 'Noord · 1 uur geleden' },
  { id: 'A-4', label: 'Jongere gekoppeld aan terugkerende oudere', meta: 'Centrum · 2 uur geleden' },
]

export const incidents: Incident[] = [
  { id: 'M-31', summary: 'Klus afgezegd door jongere, oudere telefonisch opgevangen', neighborhood: 'Oost', severity: 'Laag', status: 'In behandeling', reportedAt: 'Vandaag 10:05' },
  { id: 'M-30', summary: 'Lichte schade aan deurklink gemeld, verzekeraar ingelicht', neighborhood: 'Noord', severity: 'Middel', status: 'Open', reportedAt: 'Gisteren 15:40' },
  { id: 'M-28', summary: 'Misverstand over afgesproken tijd, opgelost', neighborhood: 'Centrum', severity: 'Laag', status: 'Afgehandeld', reportedAt: '2 dagen geleden' },
]

export const reportMetrics: ReportMetric[] = [
  { label: 'Uitgevoerde hulpvragen', value: 317, target: 500 },
  { label: 'Actief deelnemende ouderen', value: 78, target: 100 },
  { label: 'Gescreende jongeren', value: 42, target: 50 },
  { label: 'Tevredenheid ouderen', value: 96, target: 100, unit: '%' },
  { label: 'Terugkerende koppelingen', value: 61, target: 100, unit: '%' },
]

/* ---------- HELPER (jongeren) ---------- */

export const helperProfile = {
  level: 'Wijkheld',
  nextLevel: 'Buurtlegende',
  points: 640,
  nextLevelPoints: 800,
  earnings: 'EUR 238',
  rating: '4.9',
  completed: 24,
  streak: 5,
}

export const helperBadges: Badge[] = [
  { id: 'b1', label: 'Eerste klus', icon: 'Sparkles', earned: true },
  { id: 'b2', label: 'Terugkerende oudere', icon: 'Heart', earned: true },
  { id: 'b3', label: 'Digitale held', icon: 'Smartphone', earned: true },
  { id: 'b4', label: '10 × 5 sterren', icon: 'Star', earned: true },
  { id: 'b5', label: 'Tuinkampioen', icon: 'Trophy', earned: false },
  { id: 'b6', label: '50 klussen', icon: 'Award', earned: false },
]

export const helperOpportunities: Opportunity[] = [
  { id: 'O-51', title: 'Boodschappen doen', type: 'Boodschappen', time: 'Vandaag 14:00', distance: '650 m', fee: 'EUR 12', points: 20 },
  { id: 'O-52', title: 'Tablet instellen', type: 'Digitale hulp', time: 'Morgen 10:30', distance: '1,2 km', fee: 'EUR 18', points: 25 },
  { id: 'O-53', title: 'Afval wegbrengen', type: 'Klusje', time: 'Vandaag 17:00', distance: '400 m', fee: 'EUR 8', points: 15 },
  { id: 'O-54', title: 'Gezelschap & praatje', type: 'Gezelschap', time: 'Woensdag 11:00', distance: '900 m', fee: 'EUR 14', points: 35, bonus: true },
  { id: 'O-55', title: 'Tuin onkruid wieden', type: 'Tuin', time: 'Donderdag 09:00', distance: '1,5 km', fee: 'EUR 20', points: 40, bonus: true },
]

export const helperJobs: HelperJob[] = [
  { id: 'K-44', title: 'Lamp vervangen', resident: 'Mevrouw Jansen', time: 'Vandaag 15:30', fee: 'EUR 10', points: 18, status: 'Geaccepteerd' },
  { id: 'K-43', title: 'Begeleiding naar afspraak', resident: 'Meneer Aksoy', time: 'Vandaag 13:00', fee: 'EUR 16', points: 22, status: 'Onderweg' },
  { id: 'K-40', title: 'Boodschappen', resident: 'Mevrouw Smit', time: 'Gisteren 11:00', fee: 'EUR 12', points: 20, status: 'Afgerond' },
]

/* ---------- RESIDENT (hulpvrager) ---------- */

export const residentRequests: ResidentRequest[] = [
  { id: 'R-08', title: 'Boodschappen', type: 'Boodschappen', date: 'Vandaag', status: 'Nieuw' },
  { id: 'R-07', title: 'Gezelschap & praatje', type: 'Gezelschap', date: 'Morgen 14:00', status: 'Gematcht', helper: 'Yassine de Jong' },
  { id: 'R-05', title: 'Tuin opruimen', type: 'Tuin', date: 'Gisteren', status: 'In uitvoering', helper: 'Fleur Hendriks' },
  { id: 'R-02', title: 'Telefoon instellen', type: 'Digitale hulp', date: '3 dagen geleden', status: 'Afgerond', helper: 'Yassine de Jong', rated: false },
]

export const residentFavorite = {
  name: 'Yassine de Jong',
  neighborhood: 'Centrum',
  rating: '4.9',
  jobsTogether: 4,
}

export const requestTypeOptions: string[] = [
  'Boodschappen',
  'Digitale hulp (telefoon/tablet/computer)',
  'Klein klusje in huis',
  'Tuin of balkon',
  'Afval wegbrengen',
  'Begeleiding naar een afspraak',
  'Gezelschap & praatje',
]

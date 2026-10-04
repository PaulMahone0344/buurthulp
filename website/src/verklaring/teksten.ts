// B9 — teksten van de verklaring-pagina. Iedereen krijgt "je".

const MAANDEN = ['januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus', 'september', 'oktober', 'november', 'december']

/** "2026-10-01" (of een PocketBase-moment) -> "1 oktober 2026"; leeg blijft leeg. */
export function dag(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso)
  if (!m) return ''
  return `${Number(m[3])} ${MAANDEN[Number(m[2]) - 1]} ${m[1]}`
}

export const V = {
  titel: 'Verklaring van inzet',
  laden: 'Verklaring ophalen…',
  invulKop: 'Een verklaring nakijken',
  invulSub: 'Vul de controlecode in die op de verklaring staat.',
  codeLabel: 'Controlecode',
  nakijken: 'Nakijken',
  ongeldig: 'Een controlecode heeft 10 tekens, bijvoorbeeld ABCDE-FGH23.',
  zin: (voornaam: string, klussen: number) =>
    `${voornaam} hielp buren via HeitjeHulp met ${klussen === 1 ? '1 klus' : `${klussen} klussen`}.`,
  periode: (van: string, tot: string) => (van === tot ? `Op ${dag(van)}` : `Van ${dag(van)} tot ${dag(tot)}`),
  uren: (uren: number) => `Ongeveer ${String(uren).replace('.', ',')} uur`,
  niveau: (niveau: string) => `Niveau: ${niveau}`,
  badgesKop: 'Behaald en gecontroleerd',
  echtKop: 'Echt',
  echt: (code: string, op: string) => `Deze verklaring met code ${code} is uitgegeven door HeitjeHulp${op ? ` op ${dag(op)}` : ''}.`,
  print: 'Printen of opslaan als pdf',
  andere: 'Andere code nakijken',
  voet: 'HeitjeHulp brengt buren en strijders bij elkaar. Vragen? Mail info@heitjehulp.nl.',
}

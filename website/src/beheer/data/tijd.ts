// M14 — datumrekening voor het beheerpaneel. De server bewaart alles in UTC;
// de meldkamer denkt in Nederlandse kalenderdagen. Intl kent de tijdzone, dus
// zomer- en wintertijd gaan vanzelf goed.

const NL_DAG = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Amsterdam',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
})

const NL_WEERGAVE = new Intl.DateTimeFormat('nl-NL', {
  timeZone: 'Europe/Amsterdam',
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
})

const NL_DATUM = new Intl.DateTimeFormat('nl-NL', {
  timeZone: 'Europe/Amsterdam',
  day: 'numeric',
  month: 'long',
  year: 'numeric',
})

/** PocketBase schrijft "2026-09-19 12:00:00.000Z"; maak er ISO 8601 van. */
export function naarIso(waarde: string | undefined | null): string {
  const tekst = String(waarde || '').trim()
  if (!tekst) return ''
  return tekst.includes('T') ? tekst : tekst.replace(' ', 'T')
}

function alsDatum(waarde: string | Date): Date | null {
  const d = waarde instanceof Date ? waarde : new Date(naarIso(waarde))
  return Number.isNaN(d.getTime()) ? null : d
}

/** De Nederlandse kalenderdag als "JJJJ-MM-DD", of "" bij een lege datum. */
export function nlDag(waarde: string | Date): string {
  const d = alsDatum(waarde)
  return d ? NL_DAG.format(d) : ''
}

/** De Nederlandse maand als "JJJJ-MM". */
export function nlMaand(waarde: string | Date): string {
  return nlDag(waarde).slice(0, 7)
}

/** Aantal dagen tussen twee kalenderdagen "JJJJ-MM-DD" (b - a). */
export function dagenTussen(a: string, b: string): number {
  const [ja, ma, da] = a.split('-').map(Number)
  const [jb, mb, db] = b.split('-').map(Number)
  return Math.round((Date.UTC(jb, mb - 1, db) - Date.UTC(ja, ma - 1, da)) / 86_400_000)
}

/** "19 sep. 14:00" in Nederlandse tijd, of "" bij een lege datum. */
export function toonMoment(waarde: string): string {
  const d = alsDatum(waarde)
  return d ? NL_WEERGAVE.format(d) : ''
}

/** "19 september 2026", of "" bij een lege datum. */
export function toonDatum(waarde: string): string {
  const d = alsDatum(waarde)
  return d ? NL_DATUM.format(d) : ''
}

/** Centen als "€ 12,50". */
export function toonBedrag(centen: number): string {
  return new Intl.NumberFormat('nl-NL', { style: 'currency', currency: 'EUR' }).format(
    (Number(centen) || 0) / 100,
  )
}

/**
 * Een datum ("JJJJ-MM-DD") en tijd ("UU:MM") in Nederlandse tijd als ISO 8601
 * in UTC. De meldkamer vult Nederlandse tijden in, de server bewaart UTC.
 */
export function nlTijdNaarIso(datum: string, tijd: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(datum) || !/^\d{2}:\d{2}$/.test(tijd)) return ''
  const [j, m, d] = datum.split('-').map(Number)
  const [u, min] = tijd.split(':').map(Number)
  const gewenst = Date.UTC(j, m - 1, d, u, min)
  // Twee rondes: de verschuiving (1 of 2 uur) hangt af van het moment zelf.
  let gok = gewenst
  for (let i = 0; i < 2; i++) {
    gok = gewenst - (alsNlKlok(gok) - gok)
  }
  return new Date(gok).toISOString()
}

const NL_DELEN = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Europe/Amsterdam',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
})

/** Het moment `ms` zoals de Nederlandse klok het toont, als UTC-getal. */
function alsNlKlok(ms: number): number {
  const delen = Object.fromEntries(NL_DELEN.formatToParts(new Date(ms)).map((p) => [p.type, p.value]))
  return Date.UTC(+delen.year, +delen.month - 1, +delen.day, +delen.hour, +delen.minute)
}

// M14 — een foutmelding of bevestiging boven een lijst of formulier.

export function Foutmelding({ melding }: { melding: string }) {
  if (!melding) return null
  return (
    <p className="form-error" role="alert">
      {melding}
    </p>
  )
}

export function Gelukt({ melding }: { melding: string }) {
  if (!melding) return null
  return (
    <p className="form-ok" role="status">
      {melding}
    </p>
  )
}

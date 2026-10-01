// M14 — een tegel uit het tegelgrid van het bestaande AdminDashboard
// (.admin-stat-card). Het label is ook de toegankelijke naam.

export function Tegel({ label, waarde, uitleg }: { label: string; waarde: number; uitleg?: string }) {
  return (
    <article className="admin-stat-card" aria-label={label}>
      <span>{label}</span>
      <strong>{waarde}</strong>
      {uitleg ? <p>{uitleg}</p> : null}
    </article>
  )
}

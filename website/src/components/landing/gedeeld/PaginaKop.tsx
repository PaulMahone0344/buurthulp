interface PaginaKopProps {
  label: string
  kop: string
  sub?: string
}

// De groene band bovenaan elke pagina behalve de voorpagina.
export function PaginaKop({ label, kop, sub }: PaginaKopProps) {
  return (
    <div className="lp-paginakop">
      <span className="lp-paginakop__lijn" aria-hidden="true" />
      <div className="lp-wrap">
        <span className="lp-label">{label}</span>
        <h1 className="lp-h1">{kop}</h1>
        {sub ? <p className="lp-lead">{sub}</p> : null}
      </div>
    </div>
  )
}

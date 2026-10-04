import type { BeeldBron } from '../beelden'

/** voorrang = het grote beeld bovenaan; meteen = klein beeld bovenaan; lui = pas bij scrollen */
type Laden = 'voorrang' | 'meteen' | 'lui'

interface BeeldProps {
  bron: BeeldBron
  className?: string
  laden?: Laden
}

// De foto's zijn sfeerbeelden (voorwerpen en plekken) en dragen geen
// informatie, daarom een lege alt.
export function Beeld({ bron, className, laden = 'lui' }: BeeldProps) {
  return (
    <img
      className={className}
      src={bron.src}
      width={bron.breedte}
      height={bron.hoogte}
      alt=""
      decoding="async"
      loading={laden === 'lui' ? 'lazy' : 'eager'}
      fetchPriority={laden === 'voorrang' ? 'high' : undefined}
    />
  )
}

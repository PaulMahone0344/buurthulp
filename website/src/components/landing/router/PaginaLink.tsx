import type { AnchorHTMLAttributes, MouseEvent } from 'react'
import { navigeer } from './pad'

interface PaginaLinkProps extends Omit<AnchorHTMLAttributes<HTMLAnchorElement>, 'href'> {
  naar: string
}

// Een gewone link met een echt adres; alleen een gewone linkerklik wisselt
// zonder de pagina opnieuw te laden. Nieuw tabblad (cmd/ctrl-klik) blijft werken.
export function PaginaLink({ naar, onClick, children, ...rest }: PaginaLinkProps) {
  const opKlik = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event)
    const isGewoneKlik =
      event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey
    if (event.defaultPrevented || !isGewoneKlik) return
    event.preventDefault()
    navigeer(naar)
  }

  return (
    <a href={naar} onClick={opKlik} {...rest}>
      {children}
    </a>
  )
}

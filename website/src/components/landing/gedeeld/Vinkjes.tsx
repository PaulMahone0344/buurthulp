import { CheckCircle2 } from 'lucide-react'

interface VinkjesProps {
  punten: string[]
  className?: string
}

export function Vinkjes({ punten, className }: VinkjesProps) {
  return (
    <ul className={className ? `lp-vinkjes ${className}` : 'lp-vinkjes'}>
      {punten.map((punt) => (
        <li key={punt}>
          <CheckCircle2 size={19} />
          <span>{punt}</span>
        </li>
      ))}
    </ul>
  )
}

import type { IconItem } from '../landingData'
import { Icon } from './Icon'

interface StappenProps {
  stappen: IconItem[]
}

export function Stappen({ stappen }: StappenProps) {
  return (
    <ol className="lp-kaarten">
      {stappen.map((stap, i) => (
        <li className="lp-kaart" key={stap.title}>
          <div className="lp-kaart__boven">
            <span className="lp-kaart__icoon">
              <Icon name={stap.icon} size={22} />
            </span>
            <span className="lp-kaart__num" aria-hidden="true">
              {String(i + 1).padStart(2, '0')}
            </span>
          </div>
          <h2 className="lp-kaart__titel">{stap.title}</h2>
          <p>{stap.text}</p>
        </li>
      ))}
    </ol>
  )
}

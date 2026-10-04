import { CheckCircle2 } from 'lucide-react'
import { beelden } from '../beelden'
import { Beeld } from '../gedeeld/Beeld'
import { Stappen } from '../gedeeld/Stappen'
import { processSteps, welDoen } from '../landingData'

export function Werkwijze() {
  return (
    <section className="lp-sectie" aria-label="De vier stappen">
      <div className="lp-wrap">
        <Stappen stappen={processSteps} />
      </div>
    </section>
  )
}

export function WatKanEr() {
  return (
    <section className="lp-sectie lp-sectie--diep" id="wat-kan-er" aria-labelledby="kop-wat-kan-er">
      <div className="lp-wrap lp-kanwel">
        <div className="lp-kanwel__beeld" aria-hidden="true">
          <Beeld bron={beelden.groente} />
        </div>
        <div>
          <span className="lp-label">Klussen</span>
          <h2 className="lp-h2" id="kop-wat-kan-er">
            Wat kan er
          </h2>
          <ul className="lp-rijen">
            {welDoen.map((klus) => (
              <li key={klus}>
                <CheckCircle2 size={20} />
                {klus}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}

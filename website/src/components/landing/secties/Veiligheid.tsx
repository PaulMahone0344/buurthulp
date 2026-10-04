import { Icon } from '../gedeeld/Icon'
import { Vinkjes } from '../gedeeld/Vinkjes'
import { gedragsregels, safetyItems } from '../landingData'

export function Veiligheid() {
  return (
    <section className="lp-sectie" aria-label="Zo houden we het veilig">
      <div className="lp-wrap">
        <ul className="lp-kaarten">
          {safetyItems.map((item) => (
            <li className="lp-kaart" key={item.title}>
              <div className="lp-kaart__boven">
                <span className="lp-kaart__icoon">
                  <Icon name={item.icon} size={22} />
                </span>
              </div>
              <h2 className="lp-kaart__titel">{item.title}</h2>
              <p>{item.text}</p>
            </li>
          ))}
        </ul>
        <div className="lp-regels">
          <div>
            <h2 className="lp-regels__titel">Afspraken voor iedereen</h2>
            <p>Houdt iemand zich er niet aan? Dan kan de meldkamer het account stoppen.</p>
          </div>
          <Vinkjes punten={gedragsregels} className="lp-vinkjes--twee" />
        </div>
      </div>
    </section>
  )
}

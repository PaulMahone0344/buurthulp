import { beelden } from '../beelden'
import { Beeld } from '../gedeeld/Beeld'
import { Icon } from '../gedeeld/Icon'
import { Stappen } from '../gedeeld/Stappen'
import { Vinkjes } from '../gedeeld/Vinkjes'
import { helperBeloning, helperInApp, helperSteps } from '../landingData'

export function HelperStappen() {
  return (
    <section className="lp-sectie" aria-label="Zo word je strijder">
      <div className="lp-wrap">
        <Stappen stappen={helperSteps} />
      </div>
    </section>
  )
}

export function Beloning() {
  return (
    <section className="lp-sectie lp-sectie--aansluitend" aria-labelledby="kop-beloning">
      <div className="lp-wrap lp-beloning">
        <div className="lp-beloning__beeld" aria-hidden="true">
          <Beeld bron={beelden.huis} />
          {/* voorbeeld van hoe de app het laat zien, geen echte cijfers */}
          <div className="lp-widget">
            <span className="lp-widget__regel">Voorbeeld uit de app</span>
            <b>320 XP</b>
            <small>Deze week verdiend met klussen</small>
          </div>
        </div>
        <div>
          <span className="lp-label">Wat je krijgt</span>
          <h2 className="lp-h2" id="kop-beloning">
            Zakgeld, XP, badges en niveaus.
          </h2>
          <ul className="lp-beloningen">
            {helperBeloning.map((item) => (
              <li key={item.title}>
                <span className="lp-chip lp-chip--zacht">
                  <Icon name={item.icon} size={20} />
                </span>
                <div>
                  <h3 className="lp-beloningen__titel">{item.title}</h3>
                  <p>{item.text}</p>
                </div>
              </li>
            ))}
          </ul>
          <div className="lp-inapp">
            <p className="lp-inapp__label">Dit zie je in de app</p>
            <Vinkjes punten={helperInApp} className="lp-vinkjes--twee" />
          </div>
        </div>
      </div>
    </section>
  )
}

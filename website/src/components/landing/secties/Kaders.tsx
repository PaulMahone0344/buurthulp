import { useRef, useState, type KeyboardEvent } from 'react'
import { Icon } from '../gedeeld/Icon'
import { Vinkjes } from '../gedeeld/Vinkjes'
import { kaders, type KaderKey } from '../landingData'

const LAATSTE = kaders.length - 1

// Tabbladen volgens het vaste toetsenbordpatroon: pijltjes wisselen, Home en
// End springen naar het eerste en laatste tabblad.
const VOLGENDE_INDEX: Record<string, (index: number) => number> = {
  ArrowRight: (index) => (index === LAATSTE ? 0 : index + 1),
  ArrowLeft: (index) => (index === 0 ? LAATSTE : index - 1),
  Home: () => 0,
  End: () => LAATSTE,
}

export function Kaders() {
  const [actief, setActief] = useState<KaderKey>('betalen')
  const tabRefs = useRef<Partial<Record<KaderKey, HTMLButtonElement | null>>>({})
  const huidig = kaders.find((kader) => kader.key === actief) ?? kaders[0]

  const opToets = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const bepaal = VOLGENDE_INDEX[event.key]
    if (!bepaal) return
    event.preventDefault()
    const doel = kaders[bepaal(index)]
    setActief(doel.key)
    tabRefs.current[doel.key]?.focus()
  }

  return (
    <section className="lp-sectie lp-sectie--groen" aria-labelledby="kop-kaders">
      <div className="lp-wrap">
        <div className="lp-kopblok">
          <span className="lp-label">Goed om te weten</span>
          <h2 className="lp-h2" id="kop-kaders">
            Betalen, ouders, VOG en privacy.
          </h2>
        </div>

        <div className="lp-tabs" role="tablist" aria-label="Goed om te weten">
          {kaders.map((kader, index) => (
            <button
              key={kader.key}
              ref={(knop) => {
                tabRefs.current[kader.key] = knop
              }}
              id={`tab-${kader.key}`}
              role="tab"
              type="button"
              aria-selected={actief === kader.key}
              aria-controls="kader-paneel"
              tabIndex={actief === kader.key ? 0 : -1}
              className={actief === kader.key ? 'lp-tab is-actief' : 'lp-tab'}
              onClick={() => setActief(kader.key)}
              onKeyDown={(event) => opToets(event, index)}
            >
              <Icon name={kader.icon} size={18} />
              <span>{kader.tab}</span>
            </button>
          ))}
        </div>

        <div
          className="lp-tabpaneel"
          role="tabpanel"
          id="kader-paneel"
          aria-labelledby={`tab-${huidig.key}`}
          tabIndex={0}
        >
          <div>
            <h3 className="lp-tabpaneel__titel">{huidig.title}</h3>
            <p className="lp-tabpaneel__intro">{huidig.intro}</p>
          </div>
          <Vinkjes punten={huidig.points} />
        </div>
      </div>
    </section>
  )
}

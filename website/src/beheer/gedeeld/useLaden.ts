// M14 — laadt een lijst via de data-laag en houdt fout en "geladen" bij.
// herlaad() is veilig om vaak aan te roepen (realtime); een oud antwoord
// overschrijft nooit een nieuwer.

import { useCallback, useEffect, useRef, useState } from 'react'

export function useLaden<T>(laad: () => Promise<T>, beginwaarde: T) {
  const [waarde, setWaarde] = useState<T>(beginwaarde)
  const [fout, setFout] = useState('')
  const [geladen, setGeladen] = useState(false)
  const volgnummer = useRef(0)

  const verwerk = useCallback((belofte: Promise<T>) => {
    const mijnNummer = ++volgnummer.current
    return belofte.then(
      (nieuw) => {
        if (mijnNummer !== volgnummer.current) return
        setWaarde(nieuw)
        setFout('')
        setGeladen(true)
      },
      (e: unknown) => {
        if (mijnNummer !== volgnummer.current) return
        setFout(e instanceof Error ? e.message : String(e))
        setGeladen(true)
      },
    )
  }, [])

  const herlaad = useCallback(() => verwerk(laad()), [verwerk, laad])

  useEffect(() => {
    void verwerk(laad())
  }, [verwerk, laad])

  return { waarde, fout, geladen, herlaad }
}

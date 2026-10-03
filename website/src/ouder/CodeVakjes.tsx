// B3 — zes vakjes voor de code. Een cijfer typen springt door, Backspace
// in een leeg vakje gaat terug, plakken van de hele code (ook "482 913")
// vult alle vakjes.

import { useRef, type ClipboardEvent, type KeyboardEvent } from 'react'
import { T } from './teksten'

export const CODE_LENGTE = 6

type Props = {
  waarde: string[]
  opWijzig: (cijfers: string[]) => void
  beschrijving?: string
}

export function CodeVakjes({ waarde, opWijzig, beschrijving }: Props) {
  const vakjes = useRef<(HTMLInputElement | null)[]>([])
  const focus = (i: number) => vakjes.current[Math.max(0, Math.min(CODE_LENGTE - 1, i))]?.focus()

  function zet(i: number, invoer: string) {
    const cijfer = invoer.replace(/\D/g, '').slice(-1)
    if (!cijfer && invoer) return
    opWijzig(waarde.map((c, j) => (j === i ? cijfer : c)))
    if (cijfer) focus(i + 1)
  }

  function opToets(i: number, e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Backspace' && !waarde[i] && i > 0) {
      e.preventDefault()
      opWijzig(waarde.map((c, j) => (j === i - 1 ? '' : c)))
      focus(i - 1)
    } else if (e.key === 'ArrowLeft') focus(i - 1)
    else if (e.key === 'ArrowRight') focus(i + 1)
  }

  function opPlak(i: number, e: ClipboardEvent<HTMLInputElement>) {
    const cijfers = e.clipboardData.getData('text').replace(/\D/g, '')
    if (!cijfers) return
    e.preventDefault()
    const start = cijfers.length >= CODE_LENGTE ? 0 : i
    const nieuw = [...waarde]
    for (let k = 0; k < cijfers.length && start + k < CODE_LENGTE; k++) nieuw[start + k] = cijfers[k]
    opWijzig(nieuw)
    focus(Math.min(start + cijfers.length, CODE_LENGTE - 1))
  }

  return (
    <div className="ouder-vakjes">
      {waarde.map((c, i) => (
        <input
          key={i}
          ref={(el) => {
            vakjes.current[i] = el
          }}
          className="ouder-vakje"
          aria-label={T.cijfer(i + 1)}
          aria-describedby={beschrijving}
          inputMode="numeric"
          autoComplete={i === 0 ? 'one-time-code' : 'off'}
          pattern="[0-9]*"
          maxLength={2}
          value={c}
          data-gevuld={c ? '' : undefined}
          onChange={(e) => zet(i, e.target.value)}
          onKeyDown={(e) => opToets(i, e)}
          onPaste={(e) => opPlak(i, e)}
          onFocus={(e) => e.target.select()}
        />
      ))}
    </div>
  )
}

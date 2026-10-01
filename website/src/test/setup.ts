import '@testing-library/jest-dom/vitest'
import { vi } from 'vitest'

Object.defineProperty(window, 'scrollTo', {
  value: vi.fn(),
  writable: true,
})

// Node 25 heeft een eigen (lege) localStorage die die van jsdom overschaduwt;
// dan ontbreken removeItem/clear. Vervang hem door een eenvoudige geheugenopslag.
if (typeof window.localStorage?.clear !== 'function') {
  const opslag = new Map<string, string>()
  const geheugen: Storage = {
    get length() {
      return opslag.size
    },
    clear: () => opslag.clear(),
    getItem: (sleutel) => opslag.get(sleutel) ?? null,
    key: (i) => [...opslag.keys()][i] ?? null,
    removeItem: (sleutel) => {
      opslag.delete(sleutel)
    },
    setItem: (sleutel, waarde) => {
      opslag.set(sleutel, String(waarde))
    },
  }
  Object.defineProperty(globalThis, 'localStorage', { value: geheugen, configurable: true })
  Object.defineProperty(window, 'localStorage', { value: geheugen, configurable: true })
}

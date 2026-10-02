// M14 — ingang van het beheerpaneel. Apart bestand zodat App.tsx het paneel
// lazy kan laden: bezoekers van de voorpagina krijgen deze code niet binnen.

import { useState } from 'react'
import { createPocketBaseClient } from '../domain/pocketbase'
import { BeheerApp } from './BeheerApp'
import { maakPocketbaseBeheerData } from './data/pocketbaseBeheerData'

export default function BeheerIngang() {
  const [data] = useState(() => maakPocketbaseBeheerData(createPocketBaseClient()))
  return <BeheerApp data={data} />
}

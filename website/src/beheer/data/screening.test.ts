import { describe, expect, it } from 'vitest'
import { besluitBody, controleerBesluit } from './screening'
import type { Screeningbesluit } from './types'

const besluit: Screeningbesluit = {
  verificatiestatus: 'goedgekeurd',
  notitie: 'ID en selfie kloppen, VOG binnen.',
  vogStatus: 'goedgekeurd',
  vogGeldigTot: '2027-09-01',
  ibanGeverifieerd: true,
  intakeOp: '2026-10-01',
}

describe('controleerBesluit', () => {
  it('eist een notitie, ook bij afkeuren', () => {
    expect(controleerBesluit(besluit)).toBe('')
    expect(controleerBesluit({ ...besluit, notitie: '  ' })).not.toBe('')
    expect(controleerBesluit({ ...besluit, verificatiestatus: 'afgewezen', notitie: '' })).not.toBe('')
  })

  it('eist een geldig-tot-datum bij een goedgekeurde VOG', () => {
    expect(controleerBesluit({ ...besluit, vogGeldigTot: '' })).not.toBe('')
  })
})

describe('besluitBody', () => {
  it('zet de screeningvelden en de notitie', () => {
    expect(besluitBody(besluit)).toEqual({
      verificatiestatus: 'goedgekeurd',
      screening_notitie: 'ID en selfie kloppen, VOG binnen.',
      vog_status: 'goedgekeurd',
      vog_geldig_tot: '2027-09-01 12:00:00.000Z',
      iban_geverifieerd: true,
      intake_op: '2026-10-01 12:00:00.000Z',
    })
  })

  it('laat een lege intakedatum leeg (nog geen intake)', () => {
    expect(besluitBody({ ...besluit, intakeOp: '' }).intake_op).toBe('')
  })

  it('laat een lege VOG-datum leeg', () => {
    expect(besluitBody({ ...besluit, vogGeldigTot: '' }).vog_geldig_tot).toBe('')
  })
})

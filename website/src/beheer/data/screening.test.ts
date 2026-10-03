import { describe, expect, it } from 'vitest'
import { besluitBody, controleerBesluit } from './screening'
import type { Screeningbesluit } from './types'

const besluit: Screeningbesluit = {
  verificatiestatus: 'goedgekeurd',
  notitie: 'ID klopt, VOG gezien.',
  vogStatus: 'goedgekeurd',
  vogGeldigTot: '2027-09-01',
  ibanGeverifieerd: true,
  vogGezienOp: '2026-10-01',
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
      screening_notitie: 'ID klopt, VOG gezien.',
      vog_status: 'goedgekeurd',
      vog_geldig_tot: '2027-09-01 12:00:00.000Z',
      iban_geverifieerd: true,
      vog_gezien_op: '2026-10-01 12:00:00.000Z',
    })
  })

  it('laat een lege VOG-gezien-datum leeg (nog niet gezien)', () => {
    expect(besluitBody({ ...besluit, vogGezienOp: '' }).vog_gezien_op).toBe('')
  })

  it('laat een lege VOG-datum leeg', () => {
    expect(besluitBody({ ...besluit, vogGeldigTot: '' }).vog_geldig_tot).toBe('')
  })
})

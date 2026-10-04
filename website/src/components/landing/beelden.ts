// Foto's van de voorpagina. Alleen voorwerpen en plekken, geen mensen of dieren.
// Bron: Unsplash (lijst met makers in app-plan/mockups-website/BEELDEN-PROMPTS.txt).
import gereedschap from '../../assets/landing/gereedschap.webp'
import groente from '../../assets/landing/groente.webp'
import heroBoodschappen from '../../assets/landing/hero-boodschappen.webp'
import heroStraat from '../../assets/landing/hero-straat.webp'
import heroVoordeur from '../../assets/landing/hero-voordeur.webp'
import huis from '../../assets/landing/huis.webp'
import kruiwagen from '../../assets/landing/kruiwagen.webp'

export interface BeeldBron {
  src: string
  breedte: number
  hoogte: number
}

export const beelden = {
  heroBoodschappen: { src: heroBoodschappen, breedte: 880, hoogte: 1100 },
  heroStraat: { src: heroStraat, breedte: 200, hoogte: 140 },
  heroVoordeur: { src: heroVoordeur, breedte: 300, hoogte: 190 },
  kruiwagen: { src: kruiwagen, breedte: 900, hoogte: 1050 },
  gereedschap: { src: gereedschap, breedte: 720, hoogte: 1080 },
  groente: { src: groente, breedte: 760, hoogte: 1030 },
  huis: { src: huis, breedte: 900, hoogte: 880 },
} satisfies Record<string, BeeldBron>

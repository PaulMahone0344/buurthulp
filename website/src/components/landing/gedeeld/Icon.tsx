import type { ComponentType } from 'react'
import {
  Camera,
  CheckCircle2,
  ClipboardCheck,
  Coins,
  FileCheck2,
  Handshake,
  House,
  KeyRound,
  Lock,
  MapPin,
  Megaphone,
  MessageCircle,
  ShieldAlert,
  Sparkles,
  Star,
  TrendingUp,
  Trophy,
  UserPlus,
  Users,
  Wallet,
} from 'lucide-react'

// De namen komen uit landingData.ts.
const iconMap: Record<string, ComponentType<{ size?: number; strokeWidth?: number }>> = {
  Camera,
  CheckCircle2,
  ClipboardCheck,
  Coins,
  FileCheck2,
  Handshake,
  House,
  KeyRound,
  Lock,
  MapPin,
  Megaphone,
  MessageCircle,
  ShieldAlert,
  Sparkles,
  Star,
  TrendingUp,
  Trophy,
  UserPlus,
  Users,
  Wallet,
}

interface IconProps {
  name: string
  size?: number
  strokeWidth?: number
}

export function Icon({ name, size = 22, strokeWidth = 2 }: IconProps) {
  const Cmp = iconMap[name] ?? CheckCircle2
  return <Cmp size={size} strokeWidth={strokeWidth} />
}

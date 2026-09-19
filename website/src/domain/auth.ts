export type UserRole = 'admin' | 'helper' | 'resident'

export type AppView = 'home' | 'login' | 'admin' | 'helper' | 'resident'

export type DemoUser = {
  id: string
  name: string
  email: string
  password: string
  role: UserRole
  neighborhood: string
}

export type UserSession = Omit<DemoUser, 'password'>

export type LoginInput = {
  email: string
  password: string
  role: UserRole
}

export type AuthResult =
  | {
      ok: true
      user: UserSession
    }
  | {
      ok: false
      message: string
    }

export const roleLabels: Record<UserRole, string> = {
  admin: 'Admin',
  helper: 'Jongere / buurtbewoner',
  resident: 'Hulpvragende',
}

export const roleHomeViews: Record<UserRole, AppView> = {
  admin: 'admin',
  helper: 'helper',
  resident: 'resident',
}

export const demoUsers: DemoUser[] = [
  {
    id: 'demo-admin',
    name: 'Gemeente Admin',
    email: 'admin@heitjehulp.local',
    password: 'heitjehulp-admin',
    role: 'admin',
    neighborhood: 'Pilotwijk Centrum',
  },
  {
    id: 'demo-helper',
    name: 'Yassine de Jong',
    email: 'jongere@heitjehulp.local',
    password: 'heitjehulp-jongere',
    role: 'helper',
    neighborhood: 'Pilotwijk Centrum',
  },
  {
    id: 'demo-resident',
    name: 'Mevrouw De Vries',
    email: 'hulp@heitjehulp.local',
    password: 'heitjehulp-hulp',
    role: 'resident',
    neighborhood: 'Pilotwijk Centrum',
  },
]

export function authenticateDemoUser(input: LoginInput): AuthResult {
  const normalizedEmail = input.email.trim().toLowerCase()
  const user = demoUsers.find((demoUser) => demoUser.email === normalizedEmail)

  if (!user || user.password !== input.password) {
    return {
      ok: false,
      message: 'Controleer je e-mail en wachtwoord.',
    }
  }

  if (user.role !== input.role) {
    return {
      ok: false,
      message: 'Dit account hoort bij een andere rol.',
    }
  }

  const sessionUser: UserSession = {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    neighborhood: user.neighborhood,
  }

  return {
    ok: true,
    user: sessionUser,
  }
}

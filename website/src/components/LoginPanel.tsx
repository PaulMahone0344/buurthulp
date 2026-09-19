import { useMemo, useState, type FormEvent } from 'react'
import { ArrowRight, LockKeyhole, UsersRound } from 'lucide-react'
import {
  authenticateDemoUser,
  demoUsers,
  roleLabels,
  type UserRole,
  type UserSession,
} from '../domain/auth'

type LoginPanelProps = {
  onLogin: (user: UserSession) => void
  onCancel: () => void
}

const roleOrder: UserRole[] = ['admin', 'helper', 'resident']

export function LoginPanel({ onLogin, onCancel }: LoginPanelProps) {
  const [role, setRole] = useState<UserRole>('admin')
  const selectedDemoUser = useMemo(
    () => demoUsers.find((user) => user.role === role) ?? demoUsers[0],
    [role],
  )
  const [email, setEmail] = useState(selectedDemoUser.email)
  const [password, setPassword] = useState(selectedDemoUser.password)
  const [error, setError] = useState('')

  function handleRoleChange(nextRole: UserRole) {
    const nextUser = demoUsers.find((user) => user.role === nextRole)
    setRole(nextRole)
    setEmail(nextUser?.email ?? '')
    setPassword(nextUser?.password ?? '')
    setError('')
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const result = authenticateDemoUser({ email, password, role })

    if (!result.ok) {
      setError(result.message)
      return
    }

    onLogin(result.user)
  }

  return (
    <section className="auth-shell" aria-label="HeitjeHulp inloggen">
      <div className="auth-panel">
        <button className="ghost-button auth-panel__back" type="button" onClick={onCancel}>
          Terug naar homepage
        </button>
        <div className="auth-panel__intro">
          <span className="auth-icon">
            <LockKeyhole size={24} />
          </span>
          <p className="section-label">Inloggen</p>
          <h1>Kies je rol en ga naar je HeitjeHulp omgeving.</h1>
          <p>
            Deze eerste versie gebruikt veilige demo-accounts. De koppeling met
            PocketBase staat klaar voor echte accounts zodra de collecties zijn
            aangemaakt.
          </p>
        </div>

        <form className="login-card" onSubmit={handleSubmit}>
          <fieldset className="role-choice">
            <legend>Rol</legend>
            {roleOrder.map((roleName) => (
              <label className="role-option" key={roleName}>
                <input
                  checked={role === roleName}
                  name="role"
                  onChange={() => handleRoleChange(roleName)}
                  type="radio"
                />
                <span>
                  <UsersRound size={18} />
                  {roleLabels[roleName]}
                </span>
              </label>
            ))}
          </fieldset>

          <label className="field">
            <span>E-mail</span>
            <input
              autoComplete="email"
              onChange={(event) => setEmail(event.target.value)}
              type="email"
              value={email}
            />
          </label>

          <label className="field">
            <span>Wachtwoord</span>
            <input
              autoComplete="current-password"
              onChange={(event) => setPassword(event.target.value)}
              type="password"
              value={password}
            />
          </label>

          {error ? <p className="form-error">{error}</p> : null}

          <button className="button button--primary login-submit" type="submit">
            Inloggen als {roleLabels[role]}
            <ArrowRight size={18} />
          </button>
        </form>
      </div>
    </section>
  )
}

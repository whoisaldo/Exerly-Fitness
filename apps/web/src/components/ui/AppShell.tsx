import type { ReactNode } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { signOutSession } from '../../lib/sessionNetwork';
import { clearSessionCache } from '../../hooks/useSession';

const NAV = [
  { to: '/dashboard', label: 'Home' },
  { to: '/dashboard/diary', label: 'Diary' },
  { to: '/dashboard/weight', label: 'Weight' },
  { to: '/dashboard/program', label: 'Program' },
  { to: '/dashboard/activities', label: 'Activity' },
  { to: '/dashboard/sleep', label: 'Sleep' },
  { to: '/dashboard/ai-coach', label: 'Coach' },
];

interface AppShellProps {
  children: ReactNode;
  wide?: boolean;
}

export function AppShell({ children, wide = false }: AppShellProps) {
  const { pathname } = useLocation();
  const navigate = useNavigate();

  function signOut() {
    void signOutSession();
    clearSessionCache();
    navigate('/');
  }

  return (
    <div className="min-h-dvh bg-deep">
      <header className="nav-blur sticky top-0 z-40">
        <div
          className={`mx-auto flex items-center gap-1 px-4 py-3 ${wide ? 'max-w-7xl' : 'max-w-5xl'}`}
        >
          <Link to="/dashboard" className="mr-3 text-sm font-bold tracking-tight text-slate-50">
            Exerly
          </Link>

          <nav className="flex flex-1 items-center gap-0.5 overflow-x-auto">
            {NAV.map((item) => {
              // Exact match for Home; prefix match elsewhere so a nested route
              // still highlights its section.
              const active =
                item.to === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(item.to);
              return (
                <Link
                  key={item.to}
                  to={item.to}
                  className={`inline-flex min-h-11 items-center whitespace-nowrap rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
                    active
                      ? 'bg-primary/12 text-primary'
                      : 'text-slate-400 hover:bg-white/[0.06] hover:text-slate-100'
                  }`}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <Link
            to="/dashboard/profile"
            className="inline-flex min-h-11 items-center rounded-lg px-3 text-sm text-slate-300"
          >
            Profile
          </Link>

          <button
            type="button"
            onClick={signOut}
            className="ml-2 min-h-11 whitespace-nowrap rounded-lg px-3 py-1.5 text-sm text-slate-500 transition-colors hover:bg-white/[0.06] hover:text-slate-200"
          >
            Sign out
          </button>
        </div>
      </header>

      <main className={`mx-auto px-4 py-6 ${wide ? 'max-w-7xl' : 'max-w-5xl'}`}>{children}</main>
    </div>
  );
}

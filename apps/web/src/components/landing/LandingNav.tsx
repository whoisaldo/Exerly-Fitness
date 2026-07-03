import { useNavigate } from 'react-router-dom';
import { ActionButton, ExerlyMark } from '../ui';

export function scrollToSection(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
}

export function LandingNav() {
  const navigate = useNavigate();

  return (
    <nav className="nav-blur sticky top-0 z-50">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <ExerlyMark />
        <div className="flex items-center gap-1 sm:gap-3">
          <button
            onClick={() => scrollToSection('features')}
            className="hidden cursor-pointer border-none bg-transparent px-3 py-2 text-sm font-medium text-slate-400 transition-colors hover:text-slate-100 sm:block"
          >
            Features
          </button>
          <button
            onClick={() => scrollToSection('platforms')}
            className="hidden cursor-pointer border-none bg-transparent px-3 py-2 text-sm font-medium text-slate-400 transition-colors hover:text-slate-100 sm:block"
          >
            Platforms
          </button>
          <ActionButton variant="ghost" onClick={() => navigate('/login')}>
            Sign in
          </ActionButton>
          <ActionButton variant="primary" onClick={() => navigate('/login')}>
            Get started
          </ActionButton>
        </div>
      </div>
    </nav>
  );
}

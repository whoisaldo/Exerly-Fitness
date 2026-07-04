import { useNavigate } from 'react-router-dom';
import { ExerlyMark } from '../ui';
import { scrollToSection } from './LandingNav';

const linkClass =
  'cursor-pointer border-none bg-transparent p-0 text-left text-sm text-slate-500 transition-colors hover:text-slate-100';

export function Footer() {
  const navigate = useNavigate();

  return (
    <footer className="border-t border-white/[0.08] bg-surface-1">
      <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6 lg:px-8">
        <div className="grid gap-10 md:grid-cols-3">
          {/* Brand */}
          <div>
            <ExerlyMark className="mb-4" />
            <p className="max-w-xs text-sm leading-relaxed text-slate-500">
              Precision fitness tracking — activities, nutrition, sleep, and goals in one clear
              picture.
            </p>
          </div>

          {/* Product */}
          <div>
            <h4 className="label mb-4">Product</h4>
            <div className="flex flex-col gap-2.5">
              <button onClick={() => scrollToSection('features')} className={linkClass}>
                Features
              </button>
              <button onClick={() => scrollToSection('platforms')} className={linkClass}>
                Platforms
              </button>
              <button onClick={() => navigate('/login')} className={linkClass}>
                Sign in
              </button>
              <button onClick={() => navigate('/status-check')} className={linkClass}>
                Status
              </button>
            </div>
          </div>

          {/* Company */}
          <div>
            <h4 className="label mb-4">Company</h4>
            <div className="flex flex-col gap-2.5">
              <button onClick={() => navigate('/credits')} className={linkClass}>
                About
              </button>
              <a
                href="https://eternalreverse.dev"
                target="_blank"
                rel="noopener noreferrer"
                className={linkClass}
              >
                Eternal Reverse
              </a>
              <button onClick={() => navigate('/maintenance-history')} className={linkClass}>
                Maintenance history
              </button>
            </div>
          </div>
        </div>

        <div className="mt-12 border-t border-white/[0.08] pt-6 text-center">
          <p className="text-xs text-slate-500">
            &copy; 2026 Exerly &mdash; An{' '}
            <a
              href="https://eternalreverse.dev"
              target="_blank"
              rel="noopener noreferrer"
              className="text-slate-400 transition-colors hover:text-slate-100"
            >
              Eternal Reverse
            </a>{' '}
            product.
          </p>
        </div>
      </div>
    </footer>
  );
}

import { useState } from 'react';
import { Link } from 'react-router-dom';

export default function MaintenanceIcon() {
  const [isVisible, setIsVisible] = useState(true);

  if (!isVisible) return null;

  return (
    <div className="group fixed bottom-4 right-4 z-50">
      <Link
        to="/maintenance-history"
        title="Maintenance History"
        aria-label="Maintenance history"
        className="flex h-11 w-11 items-center justify-center rounded-full border border-white/[0.1] bg-surface-3 text-slate-300 shadow-glow transition-colors hover:border-white/[0.2] hover:text-slate-50"
      >
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path
            d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76Z"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </Link>
      <button
        onClick={() => setIsVisible(false)}
        title="Close"
        aria-label="Hide maintenance shortcut"
        className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full border border-white/[0.1] bg-surface-2 text-slate-500 opacity-0 transition-opacity hover:text-slate-200 group-hover:opacity-100"
      >
        <svg width="8" height="8" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path
            d="M18 6 6 18M6 6l12 12"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
          />
        </svg>
      </button>
    </div>
  );
}

import type { ReactNode } from 'react';

interface EmptyStateProps {
  icon?: ReactNode;
  title: string;
  message?: string;
  action?: { label: string; onClick: () => void };
  className?: string;
}

export function EmptyState({ icon, title, message, action, className = '' }: EmptyStateProps) {
  return (
    <div className={`flex flex-col items-center justify-center py-16 text-center ${className}`}>
      {icon && (
        <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          {icon}
        </div>
      )}
      <h3 className="text-lg font-semibold text-slate-200">{title}</h3>
      {message && <p className="mt-1 max-w-xs text-sm text-slate-400">{message}</p>}
      {action && (
        <button
          onClick={action.onClick}
          className="mt-5 rounded-xl bg-gradient-primary px-5 py-2.5 text-sm font-semibold text-white shadow-glow-primary transition-shadow hover:shadow-glow-lg"
        >
          {action.label}
        </button>
      )}
    </div>
  );
}

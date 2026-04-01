import type { ReactNode } from 'react';

interface PageHeaderProps {
  title: string;
  subtitle?: string;
  action?: ReactNode;
  className?: string;
}

export function PageHeader({ title, subtitle, action, className = '' }: PageHeaderProps) {
  return (
    <header className={`flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between ${className}`}>
      <div>
        <h1 className="text-display-sm text-slate-50">{title}</h1>
        {subtitle && (
          <p className="mt-1 text-base text-slate-400">{subtitle}</p>
        )}
      </div>
      {action && <div className="mt-3 sm:mt-0">{action}</div>}
    </header>
  );
}

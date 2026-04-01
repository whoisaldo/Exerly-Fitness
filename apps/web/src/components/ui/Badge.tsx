import type { ReactNode } from 'react';

type BadgeVariant = 'intensity' | 'meal' | 'status' | 'severity';

interface BadgeProps {
  children: ReactNode;
  variant?: BadgeVariant;
  className?: string;
}

const variantStyles: Record<BadgeVariant, string> = {
  intensity: 'bg-primary/15 text-primary-bright border-primary/20',
  meal: 'bg-warning/15 text-warning border-warning/20',
  status: 'bg-success/15 text-success border-success/20',
  severity: 'bg-error/15 text-error border-error/20',
};

export function Badge({ children, variant = 'status', className = '' }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium ${variantStyles[variant]} ${className}`}
    >
      {children}
    </span>
  );
}

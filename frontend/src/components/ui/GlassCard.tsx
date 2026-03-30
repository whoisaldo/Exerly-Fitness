import type { ReactNode } from 'react';

interface GlassCardProps {
  children: ReactNode;
  className?: string;
  elevated?: boolean;
  hover?: boolean;
  as?: 'div' | 'section' | 'article';
}

export function GlassCard({
  children,
  className = '',
  elevated = false,
  hover = true,
  as: Tag = 'div',
}: GlassCardProps) {
  const base = elevated ? 'glass-elevated' : 'glass';
  const hoverClasses = hover
    ? 'transition-all duration-300 hover:border-violet-500/40 hover:shadow-glow-primary'
    : '';

  return (
    <Tag className={`${base} p-5 ${hoverClasses} ${className}`}>
      {children}
    </Tag>
  );
}

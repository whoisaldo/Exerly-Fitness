/**
 * Exerly Fitness — Design Tokens
 *
 * Canonical color values for programmatic use in React components
 * (SVG fills, Framer Motion styles, canvas, inline style fallbacks).
 *
 * Tailwind classes are the primary styling method — use these tokens
 * only when you need raw hex/rgba values in JS/TS.
 *
 * Mobile equivalent: mobile/src/theme/colors.js
 */

export const colors = {
  primary: '#8b5cf6',
  primaryBright: '#a78bfa',
  primaryGlow: 'rgba(139,92,246,0.15)',
  secondary: '#a855f7',
  accent: '#ec4899',
  accentGlow: 'rgba(236,72,153,0.15)',

  deep: '#080810',
  surface1: '#0f0f1a',
  surface2: '#161625',
  surface3: '#1e1e32',
  dark: '#1e1b4b',

  borderSubtle: 'rgba(255,255,255,0.06)',
  borderAccent: 'rgba(139,92,246,0.4)',

  success: '#10b981',
  warning: '#f59e0b',
  error: '#ef4444',

  textPrimary: '#f8fafc',
  textSecondary: '#94a3b8',
  textMuted: '#475569',

  glass: {
    base: 'rgba(255,255,255,0.03)',
    elevated: 'rgba(255,255,255,0.06)',
    border: 'rgba(255,255,255,0.06)',
    borderElevated: 'rgba(139,92,246,0.2)',
    glow: 'rgba(139,92,246,0.08)',
  },
} as const;

export const gradients = {
  primary: ['#8b5cf6', '#a855f7'] as const,
  accent: ['#ec4899', '#a855f7'] as const,
  surface: ['#0f0f1a', '#080810'] as const,
  card: ['rgba(139,92,246,0.08)', 'rgba(236,72,153,0.04)'] as const,
  page: ['#080810', '#0f0f1a', '#1e1b4b'] as const,
} as const;

export type Colors = typeof colors;
export type Gradients = typeof gradients;

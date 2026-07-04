/**
 * Exerly Fitness — Design Tokens
 *
 * Canonical color values for programmatic use in React components
 * (SVG fills, Framer Motion styles, canvas, inline style fallbacks).
 *
 * Tailwind classes are the primary styling method — use these tokens
 * only when you need raw hex/rgba values in JS/TS.
 *
 * iOS equivalent: apps/ios/Exerly/Theme/Colors.swift
 */

export const colors = {
  primary: '#8b5cf6',
  primaryBright: '#a78bfa',
  primaryGlow: 'rgba(139,92,246,0.10)',
  secondary: '#a855f7',
  accent: '#ec4899',
  accentGlow: 'rgba(236,72,153,0.10)',

  deep: '#0a0a0f',
  surface1: '#101016',
  surface2: '#15151d',
  surface3: '#1b1b24',
  dark: '#101016',

  borderSubtle: 'rgba(255,255,255,0.08)',
  borderStrong: 'rgba(255,255,255,0.12)',
  borderAccent: 'rgba(139,92,246,0.4)',

  success: '#10b981',
  warning: '#f59e0b',
  error: '#ef4444',

  textPrimary: '#e9ebf1',
  textSecondary: '#9aa3b5',
  textMuted: '#626c80',

  glass: {
    base: '#15151d',
    elevated: '#1b1b24',
    border: 'rgba(255,255,255,0.08)',
    borderElevated: 'rgba(255,255,255,0.10)',
    glow: 'rgba(0,0,0,0.35)',
  },
} as const;

export const gradients = {
  primary: ['#8b5cf6', '#7c4ff0'] as const,
  accent: ['#a78bfa', '#8b5cf6'] as const,
  surface: ['#101016', '#0a0a0f'] as const,
  card: ['rgba(255,255,255,0.02)', 'rgba(255,255,255,0)'] as const,
  page: ['#0a0a0f', '#101016'] as const,
} as const;

export type Colors = typeof colors;
export type Gradients = typeof gradients;

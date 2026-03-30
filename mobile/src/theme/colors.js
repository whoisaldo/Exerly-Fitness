/**
 * Exerly Fitness — Mobile Design Tokens
 *
 * All color values match the locked brand scheme.
 * Web equivalent: frontend/src/theme/colors.ts
 */

export const colors = {
  // Brand
  primary: '#8b5cf6',
  primaryBright: '#a78bfa',
  primaryGlow: 'rgba(139,92,246,0.15)',
  secondary: '#a855f7',
  accent: '#ec4899',
  accentGlow: 'rgba(236,72,153,0.15)',

  // Backgrounds & surfaces
  deep: '#080810',
  surface1: '#0f0f1a',
  surface2: '#161625',
  surface3: '#1e1e32',
  dark: '#1e1b4b',

  // Borders
  borderSubtle: 'rgba(255,255,255,0.06)',
  borderAccent: 'rgba(139,92,246,0.4)',

  // Status
  success: '#10b981',
  successGlow: 'rgba(16,185,129,0.15)',
  warning: '#f59e0b',
  warningGlow: 'rgba(245,158,11,0.15)',
  error: '#ef4444',
  errorGlow: 'rgba(239,68,68,0.15)',

  // Text
  textPrimary: '#f8fafc',
  textSecondary: '#94a3b8',
  textMuted: '#475569',

  // Glassmorphism (RN approximation)
  glassBg: 'rgba(255,255,255,0.03)',
  glassElevated: 'rgba(255,255,255,0.06)',
  glassBorder: 'rgba(255,255,255,0.06)',
  glassBorderElevated: 'rgba(139,92,246,0.2)',

  // Activity-specific (charts, category badges)
  workout: '#10b981',
  nutrition: '#f59e0b',
  sleep: '#8b5cf6',
  goals: '#ec4899',
};

// Gradient arrays for expo-linear-gradient
export const gradients = {
  primary: ['#8b5cf6', '#a855f7'],
  accent: ['#ec4899', '#a855f7'],
  surface: ['#0f0f1a', '#080810'],
  page: ['#080810', '#0f0f1a', '#1e1b4b'],
  card: ['rgba(139,92,246,0.08)', 'rgba(236,72,153,0.04)'],
};

// Spacing scale (points)
export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  '2xl': 48,
  '3xl': 64,
};

// Border radius scale
export const radii = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  '2xl': 24,
  full: 9999,
};

// Type scale
export const fontSize = {
  xs: 11,
  sm: 13,
  base: 15,
  md: 17,
  lg: 20,
  xl: 24,
  '2xl': 30,
  '3xl': 36,
  display: 48,
};

// Font weights (string for RN StyleSheet)
export const fontWeight = {
  light: '300',
  normal: '400',
  medium: '500',
  semibold: '600',
  bold: '700',
  extrabold: '800',
};

export default {
  colors,
  gradients,
  spacing,
  radii,
  fontSize,
  fontWeight,
};

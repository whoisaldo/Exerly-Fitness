// Exerly Fitness - Theme Colors
// Matches the web app's purple and dark theme exactly

export const colors = {
  // Primary Purple Palette
  primary: '#8b5cf6',
  primaryDark: '#7c3aed',
  secondary: '#a855f7',
  accent: '#ec4899',
  
  // Background Colors
  darkBg: '#1e1b4b',
  darkerBg: '#312e81',
  deepPurple: '#4338ca',
  
  // Card Styles
  cardBg: 'rgba(139, 92, 246, 0.08)',
  cardBgSolid: '#2d2a5e', // Solid fallback for RN
  cardBorder: 'rgba(139, 92, 246, 0.12)',
  cardBorderSolid: '#4c4785',
  
  // Glass Effect (approximation for RN)
  glassBg: 'rgba(255, 255, 255, 0.05)',
  glassBorder: 'rgba(255, 255, 255, 0.1)',
  
  // Text Colors
  textPrimary: '#ffffff',
  textSecondary: '#c4b5fd',
  textMuted: '#a78bfa',
  
  // Status Colors
  success: '#10b981',
  successLight: 'rgba(16, 185, 129, 0.1)',
  error: '#ef4444',
  errorLight: 'rgba(239, 68, 68, 0.1)',
  warning: '#f59e0b',
  warningLight: 'rgba(245, 158, 11, 0.1)',
  
  // Activity-specific colors (matching web)
  workout: '#00b894',
  workoutSecondary: '#00cec9',
  burned: '#e17055',
  burnedSecondary: '#d63031',
  consumed: '#fdcb6e',
  sleep: '#6c5ce7',
  sleepSecondary: '#a29bfe',
  
  // Gradients (as array for LinearGradient)
  gradientPrimary: ['#8b5cf6', '#a855f7'],
  gradientSecondary: ['#ec4899', '#f59e0b'],
  gradientBackground: ['#1e1b4b', '#312e81', '#4338ca'],
  gradientWorkout: ['#00b894', '#00cec9'],
  gradientBurned: ['#e17055', '#d63031'],
  gradientSleep: ['#6c5ce7', '#a29bfe'],
  
  // Shadows
  shadowColor: 'rgba(139, 92, 246, 0.3)',
};

// Spacing scale
export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

// Border radius scale
export const borderRadius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  full: 9999,
};

// Font sizes
export const fontSize = {
  xs: 12,
  sm: 14,
  md: 16,
  lg: 18,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  display: 40,
};

// Font weights
export const fontWeight = {
  normal: '400',
  medium: '500',
  semibold: '600',
  bold: '700',
  extrabold: '800',
};

export default {
  colors,
  spacing,
  borderRadius,
  fontSize,
  fontWeight,
};


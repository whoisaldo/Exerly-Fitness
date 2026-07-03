import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#8b5cf6',
          bright: '#a78bfa',
          glow: 'rgba(139,92,246,0.10)',
        },
        secondary: '#a855f7',
        accent: {
          DEFAULT: '#ec4899',
          glow: 'rgba(236,72,153,0.10)',
        },
        deep: '#0a0a0f',
        'deep-bg': '#0a0a0f',
        surface: {
          1: '#101016',
          2: '#15151d',
          3: '#1b1b24',
        },
        dark: '#101016',
        'border-subtle': 'rgba(255,255,255,0.08)',
        'border-strong': 'rgba(255,255,255,0.12)',
        'border-accent': 'rgba(139,92,246,0.4)',
        success: '#10b981',
        warning: '#f59e0b',
        error: '#ef4444',
        slate: {
          50: '#f7f8fa',
          100: '#e9ebf1',
          200: '#d4d8e2',
          300: '#b8becc',
          400: '#9aa3b5',
          500: '#808a9e',
          600: '#626c80',
          700: '#474e60',
          800: '#2e3340',
          900: '#1d2028',
          950: '#131519',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
      },
      fontSize: {
        'display-xl': ['4.5rem', { lineHeight: '1', letterSpacing: '-0.025em', fontWeight: '800' }],
        display: ['3rem', { lineHeight: '1.1', letterSpacing: '-0.025em', fontWeight: '800' }],
        'display-sm': [
          '2.25rem',
          { lineHeight: '1.15', letterSpacing: '-0.02em', fontWeight: '700' },
        ],
        stat: ['2rem', { lineHeight: '1', letterSpacing: '-0.01em', fontWeight: '700' }],
        label: ['0.6875rem', { lineHeight: '1', letterSpacing: '0.1em', fontWeight: '500' }],
      },
      boxShadow: {
        glow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.35)',
        'glow-sm': 'inset 0 1px 0 rgba(255,255,255,0.03), 0 4px 12px rgba(0,0,0,0.3)',
        'glow-primary': '0 4px 16px rgba(139,92,246,0.18)',
        'glow-accent': '0 8px 24px rgba(0,0,0,0.35)',
        'glow-lg': '0 16px 48px rgba(0,0,0,0.45)',
        'inner-glow': 'inset 0 1px 0 rgba(255,255,255,0.06)',
      },
      backgroundImage: {
        'gradient-primary': 'linear-gradient(135deg, #8b5cf6, #7c4ff0)',
        'gradient-accent': 'linear-gradient(135deg, #a78bfa, #8b5cf6)',
      },
      animation: {
        'slide-up': 'slide-up 0.5s cubic-bezier(0.16,1,0.3,1)',
        'fade-in': 'fade-in 0.4s ease-out',
        'pulse-draw': 'pulse-draw 1.6s cubic-bezier(0.65,0,0.35,1) forwards',
      },
      keyframes: {
        'slide-up': {
          '0%': { transform: 'translateY(16px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'pulse-draw': {
          '0%': { 'stroke-dashoffset': '1' },
          '100%': { 'stroke-dashoffset': '0' },
        },
      },
      backdropBlur: {
        xs: '2px',
      },
      screens: {
        xs: '475px',
      },
    },
  },
  plugins: [],
} satisfies Config;

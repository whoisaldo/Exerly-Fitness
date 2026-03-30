import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#8b5cf6',
          bright: '#a78bfa',
          glow: 'rgba(139,92,246,0.15)',
        },
        secondary: '#a855f7',
        accent: {
          DEFAULT: '#ec4899',
          glow: 'rgba(236,72,153,0.15)',
        },
        deep: '#080810',
        'deep-bg': '#080810',
        surface: {
          1: '#0f0f1a',
          2: '#161625',
          3: '#1e1e32',
        },
        dark: '#1e1b4b',
        'border-subtle': 'rgba(255,255,255,0.06)',
        'border-accent': 'rgba(139,92,246,0.4)',
        success: '#10b981',
        warning: '#f59e0b',
        error: '#ef4444',
      },
      fontFamily: {
        sans: [
          'Inter',
          'system-ui',
          '-apple-system',
          'BlinkMacSystemFont',
          'sans-serif',
        ],
      },
      fontSize: {
        'display-xl': [
          '4.5rem',
          { lineHeight: '1', letterSpacing: '-0.025em', fontWeight: '800' },
        ],
        display: [
          '3rem',
          { lineHeight: '1.1', letterSpacing: '-0.025em', fontWeight: '800' },
        ],
        'display-sm': [
          '2.25rem',
          { lineHeight: '1.15', letterSpacing: '-0.02em', fontWeight: '700' },
        ],
        stat: [
          '2rem',
          { lineHeight: '1', letterSpacing: '-0.01em', fontWeight: '700' },
        ],
        label: [
          '0.6875rem',
          { lineHeight: '1', letterSpacing: '0.1em', fontWeight: '500' },
        ],
      },
      boxShadow: {
        glow: '0 0 40px rgba(139,92,246,0.08)',
        'glow-sm': '0 0 20px rgba(139,92,246,0.06)',
        'glow-primary': '0 8px 32px rgba(139,92,246,0.15)',
        'glow-accent': '0 8px 32px rgba(236,72,153,0.12)',
        'glow-lg': '0 16px 64px rgba(139,92,246,0.25)',
        'inner-glow': 'inset 0 1px 0 rgba(255,255,255,0.06)',
      },
      backgroundImage: {
        'gradient-primary': 'linear-gradient(135deg, #8b5cf6, #a855f7)',
        'gradient-accent': 'linear-gradient(135deg, #ec4899, #a855f7)',
        'gradient-surface': 'linear-gradient(180deg, #0f0f1a 0%, #080810 100%)',
        'gradient-card':
          'linear-gradient(135deg, rgba(139,92,246,0.08) 0%, rgba(236,72,153,0.04) 100%)',
        'gradient-page':
          'linear-gradient(180deg, #080810 0%, #0f0f1a 50%, #1e1b4b 100%)',
      },
      animation: {
        float: 'float 8s ease-in-out infinite',
        'float-delayed': 'float 8s ease-in-out 4s infinite',
        'pulse-glow': 'pulse-glow 3s ease-in-out infinite',
        'slide-up': 'slide-up 0.5s cubic-bezier(0.16,1,0.3,1)',
        'fade-in': 'fade-in 0.4s ease-out',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0) scale(1)' },
          '50%': { transform: 'translateY(-20px) scale(1.05)' },
        },
        'pulse-glow': {
          '0%, 100%': { opacity: '0.4' },
          '50%': { opacity: '0.8' },
        },
        'slide-up': {
          '0%': { transform: 'translateY(16px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
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

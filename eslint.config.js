// Flat ESLint config for the Exerly monorepo.
// - apps/api  → Node.js + CommonJS
// - apps/web  → TypeScript + React (browser, ESM)
// - apps/ios  → handled by SwiftLint, ignored here
//
// Rules start intentionally lenient (noisy rules at "warn") so CI is green on the
// existing codebase. Ratchet rules up to "error" over time.
const js = require('@eslint/js');
const globals = require('globals');
const tseslint = require('typescript-eslint');
const react = require('eslint-plugin-react');
const reactHooks = require('eslint-plugin-react-hooks');
const prettier = require('eslint-config-prettier');

module.exports = tseslint.config(
  // ---- Global ignores ----
  {
    ignores: [
      '**/node_modules/**',
      'apps/web/dist/**',
      'apps/web/build/**',
      '**/*.tsbuildinfo',
      '.deriveddata/**',
      'apps/ios/**',
      'coverage/**',
    ],
  },

  // ---- Base JS recommended (all JS/TS files) ----
  js.configs.recommended,

  // ---- API: Node.js + CommonJS ----
  {
    files: ['apps/api/**/*.js'],
    languageOptions: {
      sourceType: 'commonjs',
      ecmaVersion: 2022,
      globals: { ...globals.node },
    },
    rules: {
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      'no-empty': ['error', { allowEmptyCatch: true }],
    },
  },

  // ---- Web: TypeScript + React ----
  ...tseslint.configs.recommended.map((c) => ({
    ...c,
    files: ['apps/web/**/*.{ts,tsx,js,jsx}'],
  })),
  {
    files: ['apps/web/**/*.{ts,tsx,js,jsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: { ...globals.browser },
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    plugins: { react, 'react-hooks': reactHooks },
    settings: { react: { version: 'detect' } },
    rules: {
      ...(react.configs.flat?.recommended?.rules ?? {}),
      // TypeScript handles undefined identifiers; ESLint's no-undef false-positives on types.
      'no-undef': 'off',
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
      'react/no-unescaped-entities': 'warn',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      '@typescript-eslint/no-unused-vars': [
        'warn',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/no-explicit-any': 'warn',
      'no-empty': ['error', { allowEmptyCatch: true }],
    },
  },

  // ---- Config files: allow Node globals ----
  {
    files: ['**/*.config.{js,ts,cjs,mjs}', 'eslint.config.js'],
    languageOptions: { globals: { ...globals.node } },
  },

  // ---- Disable stylistic rules that conflict with Prettier (keep last) ----
  prettier
);

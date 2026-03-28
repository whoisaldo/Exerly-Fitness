# Exerly-Fitness — Structural Audit & Cleanup Report

**Date:** 2026-03-28
**Branch:** `main`

---

## Table of Contents

1. [What Was Wrong (Before)](#1-what-was-wrong-before)
2. [What Was Deleted & Why](#2-what-was-deleted--why)
3. [What Was Changed & Why](#3-what-was-changed--why)
4. [New Project Structure](#4-new-project-structure)
5. [Backend Architecture](#5-backend-architecture)
6. [Frontend Architecture](#6-frontend-architecture)
7. [Mobile Architecture](#7-mobile-architecture)
8. [Environment Variables](#8-environment-variables)
9. [Scripts & Commands](#9-scripts--commands)
10. [Security Fixes](#10-security-fixes)
11. [What Was NOT Changed](#11-what-was-not-changed)

---

## 1. What Was Wrong (Before)

The repository had accumulated significant structural debt:

### Root-Level Chaos
```
Exerly-Fitness/          ← repo root
├── asset-manifest.json  ← CRA build output leaked to root
├── favicon.ico          ← CRA build output
├── index.html           ← CRA build output
├── logo192.png          ← CRA build output
├── logo512.png          ← CRA build output
├── manifest.json        ← CRA build output
├── robots.txt           ← CRA build output
├── LICENSE              ← stale
├── package-lock.json    ← root lockfile
├── node_modules/        ← 3.3 MB root node_modules committed
```

### Duplicate Directories
| Directory | Size | Problem |
|-----------|------|---------|
| `Exerly-Fitness/` | 9.8 MB | **Nested full duplicate** of the entire repo (no `.git`). Contained older snapshots of all code plus dozens of `" 2"` space-in-name conflict files. |
| `web/` | 12 MB | **Full duplicate** of `frontend/` with additional `" 2"` space-in-name conflict copies of nearly every file. Root `package.json` pointed here but the maintained source was in `frontend/`. |
| `static/` | 4.1 MB | Multiple generations of CRA build output (minified JS/CSS bundles). Not source code. |
| `v17/` | 17 KB | Visual Studio IDE workspace layout files (`.wsuo`, `DocumentLayout.json`). Zero value. |

### Backend File Proliferation
```
backend/
├── .git/                              ← SEPARATE nested git repo (Heroku remote)
├── .env                               ← Committed secrets (JWT_SECRET!)
├── index.js                           (1032 lines — production, MongoDB)
├── index-local.js                     (771 lines — local dev, SQLite)
├── index-local 2.js                   (771 lines — EXACT byte-identical duplicate)
├── index-postgres-sqlite-backup.js    (864 lines — hybrid variant)
├── index-postgres-sqlite-backup 2.js  (864 lines — EXACT byte-identical duplicate)
├── Procfile                           ← redundant (root Procfile existed too)
```

The `" 2"` files were created by macOS/iCloud file conflict resolution. They were confirmed byte-identical to their originals via `diff`.

### Mobile Duplicates
```
mobile/
├── App 2.js             ← duplicate
├── app 2.json           ← duplicate
├── index 2.js           ← duplicate
├── package 2.json       ← duplicate
├── .gitignore 2         ← duplicate
├── src/config 2.js      ← duplicate
├── assets/*icon 2.png   ← duplicates (4 files)
```

### Frontend Issues
- `frontend/src/Components/` — uppercase `C`, non-standard for React projects
- `frontend/static/` — build output leaked into source tree
- `frontend/asset-manifest.json`, `favicon.ico`, `index.html`, etc. — build artifacts duplicating `public/`
- `frontend/.env` and `frontend/.env.local` — committed to git with real API URLs
- `frontend/src/Components/.DS_Store` — macOS junk

### Security
- `backend/.env` committed with `JWT_SECRET` and `ADMIN_EMAILS`
- `frontend/.env` committed with production Heroku API URL
- `frontend/.env.local` committed with admin email addresses

---

## 2. What Was Deleted & Why

### Entire Directories Removed
| Deleted | Size | Reason |
|---------|------|--------|
| `Exerly-Fitness/` | 9.8 MB | Full nested duplicate, no unique code |
| `web/` | 12 MB | Duplicate of `frontend/` with extra clutter |
| `static/` | 4.1 MB | Root-level CRA build output, not source |
| `v17/` | 17 KB | Visual Studio IDE layout files |
| `node_modules/` (root) | 3.3 MB | Should never be committed |
| `backend/.git/` | ~2 MB | Nested git repo (was used for Heroku deploys) |
| `frontend/static/` | ~1 MB | Build output leaked into source tree |

### Individual Files Removed
| File | Reason |
|------|--------|
| `asset-manifest.json` (root) | CRA build artifact |
| `favicon.ico` (root) | CRA build artifact |
| `index.html` (root) | CRA build artifact |
| `logo192.png` (root) | CRA build artifact |
| `logo512.png` (root) | CRA build artifact |
| `manifest.json` (root) | CRA build artifact |
| `robots.txt` (root) | CRA build artifact |
| `LICENSE` (root) | Stale, no longer tracked |
| `package-lock.json` (root) | Will regenerate on `npm install` |
| `frontend/asset-manifest.json` | Build artifact duplicate |
| `frontend/favicon.ico` | Duplicate of `frontend/public/` |
| `frontend/index.html` | Duplicate of `frontend/public/` |
| `frontend/logo192.png` | Duplicate of `frontend/public/` |
| `frontend/logo512.png` | Duplicate of `frontend/public/` |
| `frontend/manifest.json` | Duplicate of `frontend/public/` |
| `frontend/robots.txt` | Duplicate of `frontend/public/` |
| `frontend/src/Components/.DS_Store` | macOS junk |
| `backend/index-local 2.js` | Byte-identical duplicate of `index-local.js` |
| `backend/index-postgres-sqlite-backup.js` | Unused hybrid variant |
| `backend/index-postgres-sqlite-backup 2.js` | Byte-identical duplicate of above |
| `backend/Procfile` | Redundant (root Procfile handles this) |
| `mobile/App 2.js` | iCloud conflict duplicate |
| `mobile/app 2.json` | iCloud conflict duplicate |
| `mobile/index 2.js` | iCloud conflict duplicate |
| `mobile/package 2.json` | iCloud conflict duplicate |
| `mobile/.gitignore 2` | iCloud conflict duplicate |
| `mobile/src/config 2.js` | iCloud conflict duplicate |
| `mobile/assets/*icon 2.png` (×4) | iCloud conflict duplicates |

---

## 3. What Was Changed & Why

### 3.1 Backend Entry Point Merge

**Before:** Two separate files — `index.js` (MongoDB/production) and `index-local.js` (SQLite/dev).

**After:** Single entry point `index.js` with an env-flag guard at the top:

```javascript
require('dotenv').config();

if (process.env.DB_MODE === 'local') {
  return require('./server-local');
}

// ... rest of MongoDB production server
```

- `index-local.js` was renamed to `server-local.js` (no longer a direct entry point)
- `backend/package.json` scripts updated to use `DB_MODE=local` env flag
- Running `npm start` → MongoDB (production)
- Running `npm run dev` → SQLite (local dev, no external services needed)

### 3.2 Frontend Directory Rename

`frontend/src/Components/` → `frontend/src/components/` (lowercase)

All import paths updated across:
- `frontend/src/App.js` (20 imports updated)
- `frontend/src/components/Dashboard/Profile.jsx`
- `frontend/src/components/Dashboard/Food.jsx`
- `frontend/src/components/Dashboard/Dashboard.jsx`
- `frontend/src/components/Dashboard/Calories.jsx`
- `frontend/src/components/Dashboard/Activities.jsx`
- `frontend/src/components/Admin/Admin.jsx`
- `frontend/src/components/Dashboard/Profile.css`

### 3.3 Root `package.json`

- Workspaces changed from `["backend", "web", "mobile"]` to `["backend", "frontend", "mobile"]`
- All scripts updated: `web` → `frontend` throughout
- Package name changed from `exerly-fitness-monorepo` to `exerly-fitness`

### 3.4 `Procfile`

**Before:** `web: npm start` (ambiguous — runs root package.json)
**After:** `web: cd backend && npm start` (explicit — runs the backend server)

### 3.5 `.gitignore`

Rewritten to properly ignore:
- `node_modules/` at any depth
- `frontend/build/` (CRA output)
- `mobile/.expo/` and `mobile/dist/`
- All `.env` variants
- `*.db` (SQLite databases)
- OS files (`.DS_Store`, `Thumbs.db`)
- IDE files (`.idea/`, `.vscode/`)
- VS layout artifacts (`*.wsuo`, `DocumentLayout.json`)
- Mobile native dirs (`mobile/ios/`, `mobile/android/`)

### 3.6 `.env.example` Files Created

`backend/.env.example`:
```
PORT=3001
JWT_SECRET=your-jwt-secret-here
ADMIN_EMAILS=admin@example.com
MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/exerly
AI_API_KEY=your-gemini-api-key
# DB_MODE=local
```

`frontend/.env.example`:
```
REACT_APP_API_URL=http://localhost:3001
REACT_APP_ADMIN_EMAILS=admin@example.com
REACT_APP_ENV=development
```

---

## 4. New Project Structure

```
Exerly-Fitness/
├── .gitignore
├── package.json                    # Monorepo root (workspaces: backend, frontend, mobile)
├── Procfile                        # Heroku: cd backend && npm start
├── README.md
│
├── backend/                        # Express.js API server
│   ├── .env                        # Local secrets (gitignored)
│   ├── .env.example                # Template for env vars
│   ├── package.json
│   ├── package-lock.json
│   ├── index.js                    # Unified entry point (MongoDB or SQLite via DB_MODE)
│   ├── server-local.js             # SQLite local dev server (loaded by index.js when DB_MODE=local)
│   ├── routes/
│   │   └── ai.js                   # Gemini AI coach routes
│   └── utils/
│       └── errorLogger.js          # AI error logging (Mongoose model + static methods)
│
├── frontend/                       # React 19 SPA (Create React App)
│   ├── .env                        # Local env (gitignored)
│   ├── .env.local                  # Local overrides (gitignored)
│   ├── .env.example                # Template for env vars
│   ├── package.json
│   ├── package-lock.json
│   ├── public/
│   │   ├── ExerlyLogo.png
│   │   ├── index.html
│   │   ├── logo192.png
│   │   ├── logo512.png
│   │   ├── manifest.json
│   │   └── robots.txt
│   └── src/
│       ├── App.js                  # Root component with React Router
│       ├── App.css                 # Global styles
│       ├── config.js               # API URL auto-detection (local vs production)
│       ├── index.js                # ReactDOM entry point
│       ├── index.css
│       ├── ExerlyLogo.jpg
│       ├── reportWebVitals.js
│       ├── setupTests.js
│       ├── App.test.js
│       └── components/             # ← lowercase (was Components/)
│           ├── Admin/
│           │   ├── Admin.jsx/css
│           │   └── AIErrorManager.jsx/css
│           ├── AICoach/
│           │   ├── AICoach.jsx/css
│           │   ├── CreditBadge.jsx/css
│           │   ├── CustomQuestion.jsx/css
│           │   ├── QuickActions.jsx/css
│           │   └── SavedPlans.jsx/css
│           ├── Assets/             # Static images and SVGs
│           ├── Dashboard/
│           │   ├── Activities.jsx/css
│           │   ├── AICoach.jsx/css
│           │   ├── Calories.jsx/css
│           │   ├── Dashboard.jsx/css
│           │   ├── Food.jsx/css
│           │   ├── Goals.jsx/css
│           │   ├── Profile.jsx/css
│           │   ├── Sleep.jsx/css
│           │   └── Workouts.jsx/css
│           ├── LoginSignup/
│           │   └── LoginSignup.jsx/css
│           ├── Onboarding/
│           │   └── Onboarding.jsx/css
│           ├── AdminStatusChecker.jsx/css
│           ├── AIMaintenanceNotice.jsx/css
│           ├── Credits.jsx/css
│           ├── LandingPage.jsx/css
│           ├── MaintenanceHistory.jsx/css
│           ├── MaintenanceIcon.jsx/css
│           ├── MaintenanceNotice.jsx/css
│           └── StatusCheck.jsx/css
│
└── mobile/                         # Expo / React Native app
    ├── .gitignore
    ├── App.js                      # Root Expo component
    ├── app.json                    # Expo config
    ├── index.js                    # Entry point
    ├── package.json
    ├── assets/                     # App icons and splash images
    │   ├── adaptive-icon.png
    │   ├── favicon.png
    │   ├── icon.png
    │   └── splash-icon.png
    └── src/
        ├── api/
        │   ├── auth.js             # Auth API calls
        │   ├── client.js           # HTTP client setup
        │   └── index.js            # API barrel export
        ├── config.js               # Backend URL config
        ├── context/
        │   └── AuthContext.js       # React Context for auth state
        ├── screens/
        │   ├── DashboardScreen.js
        │   ├── HomeScreen.js
        │   ├── LogActivityScreen.js
        │   ├── LogFoodScreen.js
        │   ├── LoginScreen.js
        │   ├── LogSleepScreen.js
        │   ├── SignupScreen.js
        │   └── WelcomeScreen.js
        └── theme/
            ├── colors.js
            └── index.js
```

**Total source files:** 98 (down from 2,866+ including all junk and .git objects)

---

## 5. Backend Architecture

### Database Strategy

| Mode | Trigger | Database | AI | Use Case |
|------|---------|----------|-----|----------|
| **Production** | `DB_MODE` unset | MongoDB Atlas (Mongoose) | Gemini 2.0 Flash Lite | Heroku, live users |
| **Local Dev** | `DB_MODE=local` | SQLite (`fitness-local.db`) | Mock responses | Offline development, no API keys needed |

### Entry Point Flow

```
node index.js
  ├── DB_MODE=local? → require('./server-local') → SQLite + mock AI
  └── DB_MODE unset? → MongoDB connection → Mongoose models → Gemini AI routes
```

### API Routes (both modes)

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| `GET` | `/ping` | No | Health ping |
| `GET` | `/api/health` | No | Detailed health check |
| `POST` | `/signup` | No | Create account |
| `POST` | `/login` | No | Get JWT token |
| `GET/POST` | `/api/profile` | JWT | User profile CRUD |
| `POST` | `/api/user/onboarding` | JWT | Complete onboarding |
| `GET/POST/PUT/DELETE` | `/api/activities` | JWT | Activity CRUD |
| `GET/POST/PUT/DELETE` | `/api/food` | JWT | Food log CRUD |
| `GET/POST/PUT/DELETE` | `/api/sleep` | JWT | Sleep log CRUD |
| `GET/POST` | `/api/goals` | JWT | Goals CRUD |
| `GET/POST/PUT/DELETE` | `/api/workouts` | JWT | Workout CRUD |
| `GET` | `/api/recent` | JWT | Today's combined logs |
| `POST` | `/api/reset-today` | JWT | Clear today's data |
| `GET` | `/api/dashboard-data` | JWT | Aggregated dashboard |
| `GET` | `/api/ai/credits` | JWT | AI credit balance |
| `GET/POST/DELETE` | `/api/ai/plans` | JWT | Saved AI plans |
| `POST` | `/api/ai/coach` | JWT | Generate AI response (production only) |
| `GET` | `/api/admin/users` | Admin | List all users |
| `GET` | `/api/admin/user/:email/entries` | Admin | User's entries |
| `POST` | `/api/admin/user/:email/reset-today` | Admin | Reset user's today |
| `GET/PUT/DELETE` | `/api/admin/ai-errors/*` | Admin | AI error management |

### MongoDB Schemas (Production)

- **User** — name, email, hash, profile, admin flag, onboarding fields, AI credit system
- **Activity** — email, activity, duration, calories, intensity, type, date
- **Food** — email, name, calories, protein, sugar, carbs, fat, meal type, date
- **Sleep** — email, hours, quality, bedtime, wake time, date
- **Goals** — email, target values (calories, workouts, steps, weight, sleep, water)
- **Workout** — email, name, exercises (JSON array), timestamps
- **AIPlan** — userId (ref), type, prompt, response, credits snapshot
- **AIError** — error tracking with severity, status, admin notes

---

## 6. Frontend Architecture

- **React 19** with Create React App
- **React Router** for client-side routing
- **JWT stored in localStorage** for auth
- **API auto-detection** via `config.js`:
  - `localhost` → `http://localhost:3001`
  - Production → env var or Heroku URL
- **CSS-only styling** (no Tailwind/Styled Components)
- **Glassmorphism design** with purple/dark theme

### Key Routes

| Path | Component | Description |
|------|-----------|-------------|
| `/` | `LandingPage` | Public landing page |
| `/login` | `LoginSignup` | Auth form |
| `/onboarding` | `Onboarding` | New user setup |
| `/dashboard` | `Dashboard` | Main dashboard |
| `/dashboard/activities` | `Activities` | Activity tracking |
| `/dashboard/food` | `Food` | Nutrition logging |
| `/dashboard/sleep` | `Sleep` | Sleep tracking |
| `/dashboard/goals` | `Goals` | Goal setting |
| `/dashboard/workouts` | `Workouts` | Workout management |
| `/dashboard/profile` | `Profile` | User profile |
| `/dashboard/calories` | `Calories` | Calorie overview |
| `/dashboard/ai-coach` | `AICoach` | AI fitness coach |
| `/dashboard/admin` | `Admin` | Admin panel |
| `/credits` | `Credits` | Credit system info |

---

## 7. Mobile Architecture

- **Expo SDK** (React Native)
- **React Navigation** (assumed from screen structure)
- **Shared backend** with the web frontend
- **Screens:** Welcome, Login, Signup, Home, Dashboard, LogActivity, LogFood, LogSleep
- **Custom theme** system (`src/theme/`)
- **Auth context** (`src/context/AuthContext.js`)
- **API client** (`src/api/client.js`)

---

## 8. Environment Variables

### Backend (`backend/.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No (default: 3001) | Server port |
| `JWT_SECRET` | **Yes** | JWT signing secret |
| `ADMIN_EMAILS` | No | Comma-separated admin emails |
| `MONGODB_URI` | Yes (production) | MongoDB Atlas connection string |
| `AI_API_KEY` | Yes (production) | Google Gemini API key |
| `DB_MODE` | No | Set to `local` for SQLite mode |
| `HOST` | No (default: 0.0.0.0) | Server bind address |

### Frontend (`frontend/.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `REACT_APP_API_URL` | No | Backend API URL (auto-detected if not set) |
| `REACT_APP_ADMIN_EMAILS` | No | Admin email(s) for client-side checks |
| `REACT_APP_ENV` | No | Environment name |

---

## 9. Scripts & Commands

### Root (monorepo)

```bash
npm run dev              # Start backend + frontend concurrently
npm run dev:all          # Start backend + frontend + mobile
npm run local            # Start backend (SQLite) + frontend
npm run dev:backend      # Backend only
npm run dev:frontend     # Frontend only
npm run dev:mobile       # Mobile (Expo) only
npm run build:frontend   # Production build of frontend
npm run install:all      # Install deps for all workspaces
npm run ios              # Start Expo iOS
npm run android          # Start Expo Android
```

### Backend

```bash
cd backend
npm start                # Production (MongoDB)
npm run dev              # Local dev (SQLite, mock AI)
npm run start:local      # Same as dev
```

### Frontend

```bash
cd frontend
npm start                # Dev server on :3000
npm run build            # Production build
npm run deploy           # Build + deploy to GitHub Pages
```

---

## 10. Security Fixes

| Issue | Fix |
|-------|-----|
| `backend/.env` committed with `JWT_SECRET` | Removed from git tracking via `git rm --cached`. File remains locally but is now gitignored. |
| `frontend/.env` committed with Heroku URL | Removed from git tracking. |
| `frontend/.env.local` committed with admin emails | Removed from git tracking. |
| No `.env.example` files | Created `backend/.env.example` and `frontend/.env.example` with key names only (no values). |
| Backend had its own `.git/` with Heroku remote | Deleted. Backend deploys should be managed from the root repo. |

**Action Required:** You should rotate your `JWT_SECRET` since it was previously committed to git history. The old value is still in git history even though the file is now untracked.

---

## 11. What Was NOT Changed

Per the hard rules:

- **Zero component logic changes** — no `.jsx` file behavior was altered
- **Zero API route changes** — all endpoints work identically
- **Zero CSS changes** — no visual changes at all
- **Zero database schema changes** — MongoDB schemas and SQLite tables untouched
- **Zero dependency version changes** — `package.json` deps are identical
- **The `mobile/` directory is preserved** — it's real code, only `" 2"` duplicates were cleaned

The only changes to `.jsx`/`.js`/`.css` files were:
1. Import path casing: `Components/` → `components/` (directory rename)
2. File-header comment casing to match
3. `backend/index.js` got a 5-line env-flag guard at the top
4. `backend/package.json` scripts updated to use `DB_MODE` env flag

# Exerly

**A cross-platform fitness companion that helps you track workouts, nutrition, and sleep — with AI-powered coaching built in.**

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Web-blue)](#)
[![Node](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)](https://nodejs.org)
[![License](https://img.shields.io/badge/license-proprietary-red)](LICENSE)

---

## What is Exerly?

Exerly is a fitness platform designed for people who want one place to manage their health. Instead of juggling separate apps for workouts, food, and sleep, Exerly combines everything into a single experience across iOS and web.

The iOS app is built natively in SwiftUI with deep Apple ecosystem integration — HealthKit syncing, barcode scanning for food logging, and a personalized onboarding flow that builds a custom plan based on your body, goals, and schedule. The web dashboard gives you a broader view of your data with admin tools and analytics.

An AI coaching assistant (powered by Google Gemini) can generate workout plans, nutrition advice, and progress analysis based on your logged data.

---

## Core Features

**Tracking**
- Log workouts from 30+ activity types (gym exercises, sports, cardio) with intensity and calorie estimation
- Scan food barcodes with the camera — nutritional data pulled from FatSecret and Open Food Facts APIs
- Track sleep with bedtime/wake time and quality ratings
- Set daily and weekly goals with progress monitoring

**Intelligence**
- 12-step onboarding wizard that calculates BMI, TDEE, macro targets, and generates a weekly plan
- AI coach that answers fitness questions, builds workout plans, and analyzes progress
- Auto-detects metric/imperial units from device locale

**Health Integration**
- Apple HealthKit: reads steps and active calories, writes workouts
- Progress photo tracking with compare mode (stored per-user on device)

**Admin**
- Admin panel on both iOS and web for user management and system monitoring
- Toggle admin privileges, view aggregate stats, manage AI error logs

---

## Architecture

```
Exerly-Fitness/
├── apps/
│   ├── api/        Express backend (Node.js)
│   ├── web/        React dashboard (Vite + TypeScript + Tailwind)
│   └── ios/        Native iOS app (SwiftUI)
├── .do/            DigitalOcean deployment spec
├── Procfile        Process definition for DO App Platform
└── package.json    Monorepo workspace root
```

The backend runs a single Express server that connects to MongoDB Atlas in production and SQLite for local development — controlled by the `DB_MODE` environment variable. The iOS app and web frontend both communicate with the same REST API.

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS | SwiftUI, HealthKit, AVFoundation, SwiftData |
| Web | React 19, TypeScript, Vite, Tailwind CSS, Framer Motion |
| API | Node.js, Express 5, Mongoose, JWT, bcrypt |
| Database | MongoDB Atlas (production), SQLite (local dev) |
| AI | Google Gemini 2.0 Flash |
| Food Data | FatSecret API (primary), Open Food Facts (fallback) |
| Hosting | DigitalOcean App Platform (API), GitHub Pages (web) |

---

## Getting Started

### Prerequisites

- Node.js >= 18
- Xcode >= 15 (for iOS)

### Install and run

```bash
git clone https://github.com/whoisaldo/Exerly-Fitness.git
cd Exerly-Fitness
npm run install:all
npm run local
```

This starts the API on `localhost:3001` and web dashboard on `localhost:3000` using SQLite — no external services needed.

### iOS

Open `apps/ios/Exerly.xcodeproj` in Xcode, select your device or simulator, and run.

### Production

The API auto-deploys to DigitalOcean App Platform on every push to `main`. Environment variables (`MONGODB_URI`, `JWT_SECRET`, `ADMIN_EMAILS`, `GEMINI_API_KEY`) are configured in the DO dashboard.

---

## Scripts

| Command | What it does |
|---|---|
| `npm run local` | API + web in local mode (SQLite, no external deps) |
| `npm run dev` | API + web in production mode (MongoDB) |
| `npm run dev:api` | API only |
| `npm run dev:web` | Web only |
| `npm run build:web` | Production build of web dashboard |
| `npm run ios:build` | Build iOS via CLI |

---

## License

Copyright 2025 Ali Younes. All rights reserved.

This repository is publicly viewable for evaluation purposes. You may clone and run it locally to review functionality. Copying, distributing, modifying, or using this code in any other project without written permission is prohibited.

Contact: [aliyounes@eternalreverse.com](mailto:aliyounes@eternalreverse.com)

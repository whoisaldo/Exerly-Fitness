# Exerly

**Your all-in-one fitness platform.** Track workouts, nutrition, sleep, and goals — across iOS and web.

[![License](https://img.shields.io/badge/license-proprietary-red)](LICENSE)
[![Node](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)](https://nodejs.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Web-blue)](#)

---

## Overview

Exerly is a cross-platform fitness tracking application built for people who take their health seriously. The platform combines a native iOS experience with a full-featured web dashboard, powered by a shared backend API.

**Platform targets:**
- **iOS** — Native SwiftUI app with HealthKit integration, barcode food scanning, and an AI coaching assistant
- **Web** — React dashboard for in-depth analytics and account management
- **API** — Node.js/Express backend supporting both local development (SQLite) and production (MongoDB)

---

## Repository Structure

```
Exerly-Fitness/
├── apps/
│   ├── ios/          Native iOS app (SwiftUI)
│   ├── web/          Web dashboard (React + Vite + TypeScript)
│   └── api/          Backend API (Node.js + Express)
├── package.json      Monorepo workspace root
└── README.md
```

---

## Getting Started

### Prerequisites

- Node.js >= 18
- Xcode >= 15 (for iOS development)
- No database setup required for local development — SQLite is used automatically

### Install

```bash
git clone https://github.com/whoisaldo/Exerly-Fitness.git
cd Exerly-Fitness
npm run install:all
```

### Run locally

```bash
npm run local
```

Starts the API on `http://localhost:3001` and the web dashboard on `http://localhost:3000` concurrently, using SQLite with no external dependencies.

### iOS

Open `apps/ios/Exerly.xcodeproj` in Xcode and run on a simulator or device.

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS | SwiftUI, HealthKit, AVFoundation |
| Web | React 19, TypeScript, Vite, Tailwind CSS, Framer Motion |
| API | Node.js, Express 5, JWT, bcrypt |
| Database (prod) | MongoDB Atlas |
| Database (local) | SQLite |
| AI | Google Gemini |

---

## Key Features

- Workout logging with intensity tracking and exercise library
- Nutrition tracking with macro breakdown and barcode food scanner
- Sleep logging with bedtime/wake time tracking
- AI coaching assistant (Gemini-powered)
- 12-step onboarding wizard with personalized goal recommendations
- HealthKit integration (iOS)
- Social features and achievement system
- Admin panel for user and data management

---

## Development Scripts

| Command | Description |
|---|---|
| `npm run local` | Start API + web in local SQLite mode |
| `npm run dev` | Start API + web in production mode |
| `npm run dev:api` | API only |
| `npm run dev:web` | Web only |
| `npm run build:web` | Build web for production |
| `npm run ios:build` | Build iOS (CLI) |

---

## Contact

For bug reports or inquiries: [aliyounes@eternalreverse.com](mailto:aliyounes@eternalreverse.com)

---

## License

© 2025 Ali Younes. All rights reserved.

This repository is publicly viewable for evaluation purposes only. You may clone and run it locally to review functionality. Copying, distributing, modifying, or using this code in any other project without express written permission is prohibited.

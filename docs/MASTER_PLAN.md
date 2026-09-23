# Exerly master plan: from demo app to MacroFactor replacement

Written 2026-08-29. Baseline commit `7ffe51af`.

## Why this document exists

The goal is narrow and concrete. Aldo should be able to delete MacroFactor and use
Exerly instead, every day, without losing anything he relies on.

That goal is useful because it turns a vague "fix everything" into a pass/fail test.
A feature either serves the daily loop (weigh in, log food, hit macros, adjust weekly)
or it does not.

The honest summary of where the codebase stands: the scaffolding is good. Auth works,
CI is green, the design system is consistent, the iOS app is real SwiftUI rather than a
wrapper. But the app cannot currently replace MacroFactor, and it is not close. Three
things block it outright, and each is a missing capability rather than a bug.

## Blocking gaps

### 1. You cannot log a weight

There is no weight entity anywhere on the server. `User.weight` is one number that gets
overwritten. The iOS app has a `Measurement` SwiftData model with a weight chart, but it
never leaves the device, so it dies with the app install and the web app cannot see it.

Weight history is the input to everything MacroFactor does. Without it there is no trend,
no expenditure estimate, and no target adjustment.

### 2. You cannot log to any day except today

Every log endpoint hardcodes `entry_date: getTodayUTC()`. The client cannot send a date
and the server would ignore it if it did.

Two consequences. You cannot fix yesterday's forgotten dinner. And "today" means UTC
today, so logging dinner at 8pm in Michigan (UTC-4) files it under tomorrow. Six months
of data would be quietly skewed.

### 3. There are no macro targets and no adaptive expenditure

`Goals` stores `daily_calories` and nothing else. No protein, no fat, no carbs. TDEE is
computed with Mifflin-St Jeor times a self-reported activity multiplier, which is a
starting guess, not a measurement.

MacroFactor's entire value is that it stops guessing after week one. It measures your
actual expenditure from what you ate and how your trend weight moved, then moves your
targets. That algorithm does not exist here.

## Structural problem underneath all of it

`apps/api/index.js` (1435 lines, MongoDB) and `apps/api/server-local.js` (1263 lines,
SQLite) are two independent implementations of the same API. They have already drifted:

- `server-local.js` still uses `ADMIN_EMAIL` (singular) while `index.js` moved to `ADMIN_EMAILS`
- The local `food` table declares `sugar REAL NOT NULL`; Mongo makes it optional
- Local mode has no barcode cache, no `AIError` model, no admin AI-error routes
- Local mode's `/api/admin/*` set is one endpoint out of eight

Every feature in this plan would have to be written twice, and the second copy would rot.
So the first real work is a storage adapter: one implementation of the logic, two drivers
underneath. I considered just deleting SQLite mode and requiring Mongo everywhere. That is
less code, but it means no offline development and no fast test suite, so the adapter wins.

## Bug inventory

Found by reading the code, not by running it. Severity is my judgment.

### Correctness

| #   | Where                                                   | Problem                                                                                                                                          |
| --- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| B1  | all log routes                                          | `entry_date` forced to UTC today. Wrong day for anyone west of Greenwich; backdating impossible                                                  |
| B2  | `index.js` `/api/activities`, `/api/food`, `/api/sleep` | return the user's entire history with no date filter, limit, or paging. Grows without bound                                                      |
| B3  | `index.js:1421`                                         | `app.listen()` runs before Mongo connects. Requests in that window fail with buffering timeouts                                                  |
| B4  | `index.js` `POST /api/goals`                            | `dailyCalories \|\| null` turns a legitimate `0` into null                                                                                       |
| B5  | `server-local.js` food table                            | `sugar REAL NOT NULL` rejects rows Mongo accepts                                                                                                 |
| B6  | `server-local.js:12`                                    | reads `ADMIN_EMAIL`; the rest of the app uses `ADMIN_EMAILS`                                                                                     |
| B7  | `index.js` `POST /api/food`                             | `protein` is required, so a calories-only quick add is impossible                                                                                |
| B8  | `index.js` `PUT /api/profile`                           | writes `updates.weight` but never appends to any history                                                                                         |
| B9  | `routes/ai.js:113`                                      | `checkRateLimit` stores only `resetTime`, so the comment's "one per 10s" is right but the map key is `user._id` in one place and email elsewhere |
| B10 | `dateUtils.weekdayLabel`                                | correct, but every caller labels UTC days as if they were local days                                                                             |

### Security

| #   | Where                     | Problem                                                               |
| --- | ------------------------- | --------------------------------------------------------------------- |
| S1  | `/login`, `/signup`       | no rate limit. Unlimited password guessing                            |
| S2  | all error handlers        | `error: err.message` returned to the client leaks internals           |
| S3  | `app.use(express.json())` | no size limit. A large body can exhaust memory                        |
| S4  | everywhere                | no `helmet`, so no `X-Content-Type-Options`, `HSTS`, or frame guards  |
| S5  | JWT                       | 12 hour expiry with no refresh. You get logged out mid-day, every day |
| S6  | `/api/admin/toggle-admin` | an admin can demote themselves and lock everyone out                  |
| S7  | password rules            | six character minimum on change, none at all on signup                |
| S8  | account recovery          | no forgot-password flow at all                                        |

### Product friction

| #   | Problem                                                                                                                          |
| --- | -------------------------------------------------------------------------------------------------------------------------------- |
| P1  | No food search. Barcode or manual entry only, which means most meals are manual                                                  |
| P2  | No serving quantity. `serving_size` is a display string; you cannot log 1.5 servings                                             |
| P3  | No favorites, recents, custom foods, recipes, or saved meals on the server. iOS keeps them in SwiftData locally and web has none |
| P4  | No date navigation in any UI. Both clients only ever show today                                                                  |
| P5  | Water is counted in glasses, which is not a unit                                                                                 |
| P6  | `/api/reset-today` deletes data with no confirmation and no undo                                                                 |
| P7  | No data export. Nothing to take with you, which is exactly the lock-in MacroFactor avoids                                        |
| P8  | No micronutrients (sodium, potassium, saturated fat, cholesterol)                                                                |

## The algorithms worth getting right

These are the two pieces of real substance. Everything else is CRUD.

### Trend weight

Scale weight bounces two to three pounds on water alone. Reacting to it is noise-chasing.
The standard fix is an exponentially weighted moving average:

```
trend[0] = weight[0]
trend[i] = trend[i-1] + alpha * (weight[i] - trend[i-1])
```

`alpha = 0.1` gives roughly a ten day half-life, which is the range MacroFactor and
Hacker's Diet both land in. Missing days get the previous trend carried forward rather
than interpolated, so a week away from the scale does not invent data.

### Adaptive expenditure

Energy balance over a window:

```
expenditure = mean_daily_intake - (delta_trend_weight_kg * 7700 / days)
```

7700 kcal per kg is the standard figure for body mass change. The estimate is only as
good as the logging, so it needs guards:

- Require at least 14 days of data before showing a number
- Require intake logged on at least 80% of days in the window
- Blend with the Mifflin-St Jeor estimate, weighting the measured value higher as the
  data gets longer, so week three is not wildly unstable
- Clamp the result to 50-200% of the formula estimate to survive a week of bad logging

Then targets follow from expenditure and the chosen rate of change:

```
target_calories = expenditure - (weekly_rate_kg * 7700 / 7)
protein_g       = 1.8 * lean_mass_kg  (or 2.0 * kg on a deficit)
fat_g           = max(0.6 * weight_kg, 20% of calories)
carbs_g         = whatever calories remain
```

Recalculated weekly at check-in, not daily, so the numbers stay stable enough to plan
meals around.

## Phases

Ordered so each phase is usable on its own. If work stops after phase 3, the app is
already a working food and weight tracker.

### Phase 0: foundation

Storage adapter with Mongo and SQLite drivers. One narrow interface
(`insert/find/findOne/update/upsert/remove/aggregate`) rather than a bespoke method per
entity. Then a supertest suite running against SQLite, because nothing after this is
verifiable without it.

Also in this phase: security hardening (S1-S8), the startup race (B3), central error
handling (S2), and a `/api/export` dump so data can leave.

### Phase 1: dates and weight

Fix B1 and B2 properly. Clients send `entry_date` and a timezone; the server validates
and stores what it is told. Add date-range filters and paging to every list endpoint.

Add the weight entity, its CRUD, and the trend series endpoint.

### Phase 2: expenditure and program

Adaptive TDEE, the nutrition program (targets with a chosen goal rate), and the weekly
check-in that moves targets. This is the phase that makes it a MacroFactor replacement
rather than a spreadsheet.

### Phase 3: nutrition engine

Food search across FatSecret and Open Food Facts, serving quantities, custom foods,
favorites, recents, recipes, saved meals, and a daily summary endpoint that reports
actual against target.

### Phase 4: web UI

Date navigation everywhere. A diary grouped by meal with macro rings. A weight page with
the scale and trend lines together. A program page showing current targets, measured
expenditure, and check-in history.

### Phase 5: iOS parity

Push the SwiftData-only measurements and food library up to the server. Add date
navigation, weight logging, and the program view.

Caveat worth stating plainly: `xcode-select` on this machine points at CommandLineTools,
so `xcodebuild` cannot run and iOS changes cannot be compiled here. Fixing that needs
`sudo xcode-select -s /Applications/Xcode.app`. Until then iOS edits are reviewed by
reading, not by building, and I will flag them as unverified.

### Phase 6: polish

Micronutrients, HealthKit step and weight sync, streaks, notifications, and the remaining
lint warnings.

## Status

Updated 2026-08-29, same day the plan was written. Phases 0 through 4 are done
and verified. Phase 5 is partial and phase 6 has not started.

### Done

**Phase 0, foundation.** `apps/api/data/` is one interface with a Mongo driver
and a SQLite driver, both generated from `data/schema.js`. `server-local.js` and
its 1263 duplicated lines are gone. Every bug in the security table is fixed:
rate limits on auth, a central error handler that no longer echoes `err.message`,
a 256kb body cap, security headers, 30-day tokens with a refresh endpoint, and
an admin who cannot lock everyone out by demoting themselves. The server also
waits for the database before it listens, and drains in-flight requests on
SIGTERM.

**Phase 1, dates and weight.** Logs carry a real `entry_date` in the user's
timezone. Backdating works, future dates are rejected, and every list endpoint
takes a range with a hard 400-day cap. Weight and the trend series exist.

**Phase 2, expenditure and program.** `lib/nutrition.js` holds the EWMA trend and
the adaptive expenditure estimate. Against simulated data with realistic scale
noise it recovers a known 2950 kcal expenditure as 2916.

**Phase 3, nutrition engine.** Search across both providers, serving quantities,
a self-populating food library with favourites and recents, recipes with
per-serving macros, and `/api/summary` for a whole diary day in one request.

**Phase 4, web UI.** Diary, Weight, and Program pages, all with date navigation.
Verified end to end in a real browser: logging a food from recents moves the
day's total by exactly the right amount.

### Partially done

**Phase 5, iOS.** The data layer is updated: every request sends `X-Timezone`,
food and activity and sleep requests accept `entry_date` and `servings`, weight
now syncs to the server instead of dying in SwiftData, and the session refreshes
on launch. New DTOs and endpoints exist for weight, trend, program, check-in,
daily summary, and the food library.

What is missing is screens. A Program view and a date-navigating diary need new
Swift files, and this project uses a classic `.pbxproj` where a new file has to
be registered by hand with generated UUIDs. Doing that without being able to
build is how you hand someone a project that will not open.

Two things block a build on this machine:

```
sudo xcode-select -s /Applications/Xcode.app   # currently points at CommandLineTools
```

Until that runs, iOS changes are checked with `swiftc -parse` (all 71 files pass)
which catches syntax errors but not type errors. Treat the iOS changes as
unverified until they compile.

### Not started

**Phase 6, polish.** Micronutrients beyond sodium and saturated fat, HealthKit
weight and step sync, streaks, notifications, and the 36 remaining lint warnings
in the older web pages.

### One regression worth recording

Adding validation to `mealType` nearly broke food logging on every deployed
client. Both the iOS app and the older web food page send `"Snack"`, and a
case-sensitive `oneOf` would have rejected it with a 400. `validate.oneOf` now
matches case-insensitively and returns the canonical value, and there is a test
covering it. The lesson generalises: adding validation to an endpoint that had
none is a breaking change unless you check what the existing clients actually
send.

### Verification

```
npm test            81 passing
npx eslint .        0 errors (36 pre-existing warnings in untouched files)
tsc -p apps/web     clean
npm run build:web   clean
npm run smoke:api   passing
swiftc -parse       71/71 files
```

## What I am deliberately not doing

- Not rewriting the AI coach. It works, it is not part of the daily loop, and the credit
  system is fine as is.
- Not touching the landing page. It was rebuilt recently and looks good.
- Not adding social features. `SocialService.swift` exists and is unused; leaving it.
- Not migrating off DigitalOcean or GitHub Pages. Hosting is not the problem.

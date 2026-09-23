# Task: finish the iOS app for Exerly

You are working in `/Users/aldo/Desktop/Exerly-Fitness`, a monorepo with a Node
API (`apps/api`), a React web app (`apps/web`), and a native SwiftUI iOS app
(`apps/ios`). The API and web app were just rebuilt around a new nutrition
model. **iOS has the new data layer but none of the new screens. Your job is the
screens, plus wiring the existing ones to the new endpoints.**

The goal for the whole product is narrow: the owner wants to delete MacroFactor
and use this instead, every day. iOS is where food actually gets logged, so it
is the part that matters most. A feature counts only if it serves the daily
loop: weigh in, log food, hit macros, adjust weekly.

---

## Before you start: unblock the build

`xcode-select` on this machine points at CommandLineTools, so `xcodebuild` does
not work. Fix it first, because everything below needs a compiler:

```bash
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -version   # should print Xcode 15+
```

Then confirm the project builds _before_ you change anything, so you know any
later failure is yours:

```bash
cd /Users/aldo/Desktop/Exerly-Fitness
npm run ios:build
```

That runs:

```bash
xcodebuild -project apps/ios/Exerly.xcodeproj -scheme Exerly \
  -destination 'generic/platform=iOS' -derivedDataPath .deriveddata \
  CODE_SIGNING_ALLOWED=NO build
```

If the baseline build fails, fix that first and say so. Do not build new work on
top of a broken baseline.

Run the API locally so the simulator has something to talk to. `APIClient`
hardcodes `http://127.0.0.1:3001` under `#if targetEnvironment(simulator)`, so
the simulator needs no configuration:

```bash
cd apps/api && DB_MODE=local node index.js
```

`DB_MODE=local` uses SQLite and canned AI responses. No MongoDB, no API keys.

---

## Read these first

- `docs/API.md` — the full API reference. Conventions, every endpoint, every
  field. This is the contract; do not guess at shapes.
- `docs/MASTER_PLAN.md` — why the product changed, and the "Status" section
  listing exactly what is done and what is not.
- `apps/ios/Exerly/Core/Network/APIModels.swift` and `APIEndpoints.swift` — the
  DTOs and calls already written for you.

---

## What already exists on iOS (do not redo)

The networking layer is done and parses cleanly. Specifically:

**`APIClient.swift`**

- Sends `X-Timezone: <device zone>` on every request. The server files each log
  under a calendar day in the user's timezone, so this is what stops an 8pm
  dinner in Michigan landing on tomorrow.
- `refreshSession()` exchanges a valid token for a fresh one. Tokens last 30
  days and `AuthViewModel.checkAuth()` already calls this on launch.
- `APIClient.dayString(for:)` and `APIClient.date(fromDayString:)` convert
  between `Date` and the `YYYY-MM-DD` the API stores, pinned to the device
  timezone. **Use these. Do not build the string from ISO8601, which is UTC and
  will be off by one.**

**`APIModels.swift`** — new types, all ready to use:

- `WeightRequest`, `WeightDTO`
- `TrendPointDTO` (`date`, `weight: Double?`, `trend: Double`),
  `TrendSummaryDTO`, `TrendResponseDTO`
- `ProgramDTO`, `ProgramTargetsDTO`, `ExpenditureDTO`,
  `ProgramUpdateRequest`, `CheckinResponseDTO`
- `DaySummaryDTO`, `MealBucketDTO`, `MacroTotalsDTO`, `SummaryTargetsDTO`
- `LibraryFoodDTO`, `FoodSearchResponseDTO`, `SearchFoodDTO`
- `FoodRequest` / `ActivityRequest` / `SleepRequest` gained
  `entryDate: String?`, and `FoodRequest` also gained `servings: Double?`. Both
  are `var` with a `nil` default so existing call sites still compile.

**`APIEndpoints.swift`** — `getWeights`, `getWeightTrend`, `logWeight`,
`deleteWeight`, `getProgram`, `updateProgram`, `runCheckin`, `getDaySummary`,
`getLibraryFoods`, `searchFoods`, `toggleFavorite`.

**`MeasurementsTab.swift`** — saving a weight now also POSTs to `/api/weight`.
It still _reads_ from SwiftData only, which is one of your jobs below.

**Meal types are lowercase now.** `LogFoodView` and `FoodDetailView` use
`["breakfast", "lunch", "dinner", "snack"]` and display them with
`.capitalized`. The server matches case-insensitively, so old builds keep
working, but new code should send lowercase.

---

## What to build

Roughly in priority order. Ship each one working before starting the next.

### 1. Wire servings properly in the food log sheets

`QuickFoodLogSheet` in `LogFoodView.swift` (and the equivalent in
`FoodDetailView.swift`) currently pre-multiplies macros by the serving count and
sends the product:

```swift
let req = FoodRequest(
    name: food.name, calories: scaledCalories,
    protein: food.protein * servings,   // pre-multiplied
    ...
)
```

The API now does that multiplication itself. Send **per-serving** macros plus
`servings`, so the entry stays editable and the diary can show "Chicken breast
× 1.5" instead of a flat number:

```swift
var req = FoodRequest(
    name: food.name, calories: food.calories,
    protein: food.protein, carbs: food.carbs, fat: food.fat,
    sugar: food.sugar, mealType: selectedMealType,
    barcode: food.barcode, brand: food.brand,
    fiber: food.fiber, servingSize: food.servingSize
)
req.servings = servings
req.entryDate = APIClient.dayString(for: selectedDate)
```

Also add a date control to these sheets so a forgotten meal can be logged to
yesterday. Same for `LogActivityView` and `LogSleepView` via their `entryDate`
fields.

### 2. Weight and trend in the Progress tab

`MeasurementsTab.swift` reads a SwiftData `@Query` and charts raw scale values.
Rework it to read `/api/weight/trend?days=90` via `getWeightTrend(days:)`.

The chart should plot **two things at once**: raw weigh-ins as faint dots and
the smoothed trend as a solid line. That contrast is the entire point — the dots
are the noise you are meant to ignore and the line is what is actually
happening. `TrendPointDTO.weight` is `nil` on days with no weigh-in; the
`trend` value is always present because it carries forward across gaps.

Above the chart show `TrendSummaryDTO`: current trend weight, last scale
reading, change over the window, and `weeklyRateKg`. The rate is the number the
user acts on.

Add a range selector (30d / 90d / 6m / 1y) and keep the existing add-weight
flow. `MeasurementsTab` already imports `Charts`, so Swift Charts is available.

Keep the non-weight measurements (waist, chest, hips, arms, thighs) in
SwiftData. The API has no general measurements endpoint yet, and weight is the
one the expenditure algorithm needs.

**Look at `apps/web/src/components/ui/TrendChart.tsx` for the reference
rendering.** Match its behaviour, not its code.

### 3. A Program screen

This is the MacroFactor replacement in one view, and it does not exist on iOS at
all. New file, probably `Features/Program/ProgramView.swift` plus a
`ProgramViewModel`.

It shows:

- **Measured expenditure** as the headline number, with its confidence. The
  confidence levels are `estimated` (no measurement yet, this is just
  Mifflin-St Jeor), `low` (14 to 20 days), `medium` (21 to 27), `high` (28+ with
  90% food-logging coverage). Explain in plain language what the level means;
  a bare label is not useful.
- The working behind it when available: raw measurement, what the formula would
  have said, mean intake, days logged out of the window.
- **Current targets**: calories, protein, carbs, fat.
- **Plan controls**: goal (`lose` / `maintain` / `gain`), a rate slider in
  kg/week (server caps at 1.5 and normalizes the sign to match the goal), and
  diet type (`balanced`, `low_carb`, `low_fat`, `high_protein`, `keto`). Each
  change PUTs to `/api/program` and applies immediately.
- **A check-in button**, emphasized when `needsCheckin` is true. Check-in
  re-measures expenditure and moves the targets.
- **Check-in history** with the calorie delta each time.

Reach it from the Profile tab or as a fourth tab in `ProgressView_`
(`ProgressTab` currently has `measurements`, `photos`, `achievements`).

**Reference: `apps/web/src/components/Program/ProgramPage.tsx`.**

### 4. A diary with date navigation

`HomeView` shows today and only today. Build a diary backed by
`getDaySummary(for:)`, which returns a whole day in one request: meals grouped
by type with per-meal totals, consumed macros, targets, what is remaining,
activities, sleep, water, and that day's weight.

Needs:

- A date stepper (previous / next / tap to pick, with forward capped at today).
- Calories consumed against target, and remaining.
- Macro bars for protein, carbs, fat, fibre. Show over-target in the warning
  colour rather than letting a bar overflow.
- Meals as sections with an Add button each, entries showing name, serving
  multiplier, macros, and calories. Swipe to delete.

**Reference: `apps/web/src/components/Diary/Diary.tsx`.**

### 5. Server-backed food search and library

`LogFoodView` currently searches Open Food Facts directly from the device via
`OpenFoodFactsService`, and `FoodLibraryView` reads a SwiftData `CachedFoodItem`
table that never syncs.

Move both to the server:

- `searchFoods(query)` returns `{library, results}`. The user's own foods come
  back in `library` and should be shown **first** — what you have eaten before
  is almost always what you are looking for.
- `getLibraryFoods(limit:favoritesOnly:)` is the recents list, most recently
  used first. This is what the picker should open to.
- `toggleFavorite(foodId:)` for favourites.

The library fills itself: anything logged through `POST /api/food` is remembered
automatically at per-serving values.

Decide deliberately what to do with the SwiftData cache. Offline read-through is
defensible; a second source of truth that silently diverges is not. Whatever you
choose, say why.

### 6. Settings

`PUT /api/settings` takes `{timezone, unitSystem}`. Add a settings screen or a
Profile section for unit system (metric / imperial) and timezone. The API stores
and returns kilograms and centimetres exclusively; imperial is display only, so
convert at the view boundary and never send pounds.

---

## Constraints

**Adding a Swift file means editing `project.pbxproj` by hand.** The project is
objectVersion 56 with no file-system synchronized groups, so Xcode's automatic
membership does not apply. Each new file needs four entries, all with fresh
24-character hex UUIDs. Here is the existing pattern for one file:

```
# PBXBuildFile section (line ~65)
C5B2877639F29869465379EB /* Features/Progress/MeasurementsTab.swift in Sources */ = {isa = PBXBuildFile; fileRef = 410358EAD9BE36D9C41FC860 /* ... */; };

# PBXFileReference section (line ~101)
410358EAD9BE36D9C41FC860 /* Features/Progress/MeasurementsTab.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MeasurementsTab.swift; sourceTree = "<group>"; };

# the enclosing PBXGroup children array (line ~471)
410358EAD9BE36D9C41FC860 /* Features/Progress/MeasurementsTab.swift */,

# PBXSourcesBuildPhase files array (line ~603)
C5B2877639F29869465379EB /* Features/Progress/MeasurementsTab.swift in Sources */,
```

Prefer doing this in Xcode rather than by hand where you can. Either way,
**build after every file you add**, not after all of them. A corrupt pbxproj
that will not open is much worse than a compile error.

**Do not change the API.** It has 81 passing tests and a web client depending on
it. If you genuinely need an endpoint that does not exist, say so and work
around it rather than editing `apps/api`. If you do touch it, `npm test` must
stay green.

**Do not restructure the app.** No new architecture, no swapping SwiftUI for
anything, no dependency additions. Match the existing patterns: `@MainActor
final class ...ViewModel: ObservableObject` with `@Published` state and an
`async func load()`, exactly like `HomeViewModel`.

---

## Design system

Use the existing tokens. Do not introduce new colours or fonts.

**Colours** (`Theme/Colors.swift`): `.exPrimary` `#8b5cf6`, `.exBackground`
`#0a0a0f`, `.exSurface1/2/3`, `.exTextPrimary/Secondary/Muted`, `.exSuccess`
`.exWarning` `.exError` `.exInfo`, `.exBorder`.

**Type** (`Theme/Typography.swift`): `.exDisplay` `.exH1` `.exH2` `.exH3`
`.exBody` `.exBodyMedium` `.exLabel` `.exCaption` `.exSmall`, and the monospaced
`.exStat` `.exStatMedium` `.exStatSmall` for numbers. **Every number that
changes should use a monospaced style** so it does not jitter as it updates.

**Modifiers** (`Theme/Modifiers.swift`): `.glassCard(cornerRadius:)`,
`.primaryGlow()`, `.accentGlow()`, `.surfaceStyle(level:)`.

**Components** (`Components/`): `GlassCard`, `ActionButton` (variants
`.primary/.secondary/.ghost`, plus `isLoading` and `isDisabled`),
`StatMiniCard`, `CalorieRing`, `FloatingLabelTextField`, `SelectionCard`,
`LoadingStateView`, `EmptyStateView`, `ErrorStateView`, `ConfettiView`.

The aesthetic is precision-minimal dark: solid surfaces, hairline borders, one
accent colour, restraint with animation. The owner's stated taste is readable
and minimal, and specifically not generic-AI-looking. Avoid gradient-heavy
cards, decorative emoji, and glow for its own sake.

---

## Definition of done

- `npm run ios:build` succeeds with no new warnings.
- The app runs in the simulator against a local `DB_MODE=local` API, and you
  have actually driven each screen you touched rather than assuming.
- Weigh in on the phone, then confirm the same value appears on the web app at
  `localhost:3000/#/dashboard/weight`. Cross-client sync is the thing that was
  broken; prove it works.
- Log a food with a fractional serving count and confirm the diary shows the
  multiplier and the correct totals.
- Log something to yesterday and confirm it lands on yesterday, not today.
- `swiftlint` is configured at `.swiftlint.yml` and runs in CI. Keep it clean.

## Report back with

1. What you built, per numbered item above.
2. Anything you did not finish, and why. Partial and honest beats complete and
   claimed.
3. Any bug you found in the API while integrating. There will probably be some;
   the iOS client is the first thing to exercise several of these endpoints for
   real.
4. Screenshots or a simulator recording of the new screens.

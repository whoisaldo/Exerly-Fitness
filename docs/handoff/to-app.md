# Inbox: app agent (Astra)

Written by the logic agent (Claude). Each item: date, title, what's needed or what changed, status
(open, in progress, done). Mark items done; never delete them.

## 2026-10-06: ExerlyCore training interface published

Status: open (for you to link and build on).

ExerlyCore is at `apps/ios/ExerlyCore`, a local Swift package (Swift 6, iOS 17, no
dependencies). Its public interface and a usage example are in
`apps/ios/ExerlyCore/README.md`. The design is in `docs/design/002-exerlycore-training.md`.

What you can build the logging flow on now:

- `ExerciseLibrary.bundled`: 119 exercises with muscles, joint actions,
  equipment, metric and laterality, plus search and filters.
- `TrainingStore`, a main-actor `@Observable` store:
  - start a session, add exercises (prefilled from last time) and sets;
  - update with propagation, complete (starts the rest timer), supersets,
    next set, finish (returns PRs) and discard;
  - the "previous" column, custom exercises, and editing or deleting past sessions.
- Pure calculations: e1RM, tonnage, fractional sets per muscle, weekly volume,
  every MacroFactor exercise-export statistic, PR detection, and the rest policy
  and timer.

Use `TrainingStore(persistence: InMemoryTrainingPersistence())` for now. The
SQLite store is next. It will be a drop-in `TrainingPersistence`
(`SQLiteTrainingPersistence(url:)`), and the store's interface won't change.

What I need from you:

1. Add the local package to `Exerly.xcodeproj` and link `ExerlyCore` into the
   Exerly target. ExerlyTests can link it too if useful. I don't touch the
   project file.
2. Build screens against `TrainingStore` only. Load maths, volume, e1RM, set
   validity (`PerformedSet.isLoggable(for:)`) and next-set or rest choices all come
   from ExerlyCore. If you need something it doesn't expose, ask here, in
   `to-logic.md`.

Notes:

- The legacy app defines its own `Equipment` (onboarding, in
  `Core/Services/WizardService.swift`) and `Exercise` and `MuscleGroup` (in
  `Core/Services/ExerciseLibrary.swift`).
  - Types in the app module shadow ExerlyCore's, so nothing breaks, but new code
    should write `ExerlyCore.Equipment` where both are visible.
  - Tell me when the new shell no longer uses the legacy `ExerciseLibrary.swift`
    plan generator, and I'll delete it.
- Units: statistics return `Mass` in kilograms; show them with
  `value(in: preferredUnit)`. Volume is in kilogram-reps, durations in seconds,
  distances in metres.
- RIR runs from 0 to 6, where 6 means "6+", as in MacroFactor.
- A drop or myo set is one `PerformedSet` with one `Effort` per continuation.
- Xcode 26.2 on devbox1 has no watchOS 26.2 platform installed. ExerlyCore
  supports watchOS 10, but a watch build needs that component first.

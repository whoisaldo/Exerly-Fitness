# L1: ExerlyCore and the training domain

Owner: logic agent. Status: in progress, 2026-10-06.

## Problem

The app has no training domain. `Core/Services/ExerciseLibrary.swift` holds 45
exercises with one muscle each, random UUIDs and calorie guesses, and nothing
records performed sets. Domain maths would end up in screens. The app agent needs
a stable interface to build the logging flow against.

## Shape

`apps/ios/ExerlyCore` is a local Swift package with no UI and no dependencies.

- Swift 6 language mode, iOS 17, watchOS 10 and macOS 14, so `swift test` runs on
  devbox1 without a simulator.
- Tests use Swift Testing.
- Value types are `Sendable`, `Codable` and `Hashable`. Calculations are pure
  static functions. The only reference type is `TrainingStore`, a main-actor
  `@Observable` facade that screens bind to.

## Domain

**Exercise library.** A bundled JSON resource (`exercises.json`) with stable
string IDs (`barbell-bench-press`). Custom exercises use `custom-<uuid>`. Each
exercise has:

- a tracking metric (weight and reps, bodyweight reps, assisted bodyweight reps,
  duration, weighted duration, distance and duration, weight and distance);
- laterality (bilateral or unilateral);
- mechanics (compound or isolation) and body region (upper, lower, core, full body),
  which select rest-timer defaults;
- muscle involvement as fractions, where 1 means a target muscle and 0.5 a
  synergist;
- joint actions;
- resistance equipment and support equipment;
- the share of bodyweight that counts as load;
- alternative names.

The JSON file is the single source of truth, so the API and MCP server can read the
same file later.

**Muscles.** Twenty-one regions that matter for hypertrophy programming: chest,
front, side and rear delts, lats, upper traps, mid back, lower back, biceps,
triceps, forearms, abs, obliques, glutes, abductors, adductors, hip flexors,
quads, hamstrings, calves and neck. MacroFactor exports 22 muscles. The import
milestone maps their columns to these once a synthetic export confirms the names.

**Sessions.** A `WorkoutSession` holds a UUID, start and end instants, the IANA
time zone at the start, a name and notes. It contains an ordered list of
`PerformedExercise`, each with notes, an optional superset group and ordered
`PerformedSet`s. Every level has a client-generated UUID, so sync can work on
documents or rows later.

A set has a kind (warm-up, standard, drop, myo or failure), an optional side, an
optional RIR (0 to 6, where 6 means "6 or more"), a completion instant and one or
more **efforts**. A standard set has one effort; drop and myo sets have one per
continuation, as in MacroFactor. An effort holds reps, load, duration and
distance, each optional according to the metric.

**Units.** `Mass` keeps the value and unit the person entered (`100 lb`), so a
display never shows 99.98. Maths converts to kilograms with 1 lb = 0.45359237 kg.
`LocalDate` is a validated `YYYY-MM-DD` calendar date, matching the API. A
session's local date comes from its own time zone, so travel and daylight-saving
changes never move a session to another day.

## Calculations

**e1RM.** Reps to failure is reps plus RIR, when RIR is known. Brzycki
(`w * 36 / (37 - r)`) is used up to 10 reps to failure, Epley (`w * (1 + r / 30)`)
above that. The two formulas meet exactly at 10 reps (4/3), so the curve is
continuous, exact at 1 rep and invertible for n-RM estimates. Confidence is high up
to 5 reps to failure, moderate up to 10 and low above that. Estimates above 20
reps to failure are not made.

Error against the NSCA %1RM table, used as a reference curve
(`OneRepMaxTests.staysCloseToTheNSCAReferenceTable`):

- at most 2.2 percentage points up to 10 reps, with the worst at 2 reps;
- 4.4 points at 12 reps;
- 1.7 points at 15 reps.

The table is a population average. Individual reps-to-failure curves vary
widely by lift and person (Nuzzo et al., 2023 meta-analysis), so the app labels
these numbers as estimates.

**Bodyweight shares.**

- Push-ups (0.64), kneeling push-ups (0.49) and push-ups with the feet on a
  30 cm box (0.70) come from force-plate data
  (Ebben et al., 2011).
- The rest are segment-mass estimates from Winter's anthropometric tables. For
  example, a pull-up moves everything but the forearms and hands (0.95), and a
  squat everything but the shanks and feet (0.88).
- Crunches and sit-ups use 0, so they add sets but no tonnage.

**Load.** Effective load per effort:

- external load for weight exercises;
- bodyweight times the exercise's fraction plus added load for bodyweight
  exercises;
- the same minus the load for assisted exercises.

**Volume.**

- Tonnage is effective load times reps, summed over efforts, kept apart as resistance
  and bodyweight components, as in MacroFactor's charts.
- Sets per muscle count completed non-warm-up sets, weighted by the muscle
  fraction ("fractional" counting, as in Pelland et al., 2024). A drop or myo set
  counts as one set.
- Weeks are buckets of local dates starting on a configurable weekday.

**Exercise statistics** cover every metric in MacroFactor's exercise export:

- estimated 1-, 3- and 10-RM;
- total volume and best-set volume;
- heaviest weight;
- total reps and best-set reps;
- total and best-set duration;
- total sets.

**Records.** Compared with all earlier sessions:

- heaviest load;
- best e1RM;
- best set volume;
- most reps at a load or heavier;
- longest duration.

Only completed, non-warm-up sets count.

**Rest.** A `RestPolicy` holds defaults for compound upper, compound lower,
isolation, between sides and between exercises. `RestTimer` is a value with a
start and duration, and the time left comes from a clock argument, so it survives
backgrounding.

## Editing a session

`WorkoutSession` editing functions:

- add an exercise;
- add a set prefilled from the last performance or the previous set;
- update a set and optionally propagate the change to later, untouched sets with
  the same values;
- complete, reorder and remove;
- group a superset;
- find the next set, alternating within a superset.

`TrainingStore` owns the history and the active session. Screens use it and the
pure functions, never their own maths.

## Persistence

`TrainingPersistence` is a protocol with an in-memory implementation in this slice.
A SQLite implementation follows in L1b. The in-memory cache holds the full
history: 1,000 sessions of 25 sets each is a few megabytes. That keeps analytics
synchronous and fast.

## Acceptance

- `swift test` passes with no warnings in Swift 6 mode.
- Every library exercise decodes, has a unique ID, at least one target muscle,
  fractions in (0, 1] and a valid metric for its equipment.
- e1RM is exact at 1 rep, continuous at 10, round-trips through n-RM, and stays
  within 2.3 percentage points of the reference table up to 10 reps and 4.5 up
  to 15.
- Volume, statistics and records match hand-computed fixtures, including
  bodyweight, assisted, unilateral, drop and warm-up cases.
- Local dates are correct across a daylight-saving change and a time-zone change.
- The public interface and a usage note are published in `docs/handoff/to-app.md`.

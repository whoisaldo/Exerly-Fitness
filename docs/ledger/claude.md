# Claude ledger

Rewrite this file each iteration and keep it under 80 lines. See `docs/AGENT_BRIEF.md`.

## Shipped today

- 2610101011 (internal TestFlight): first Watch app (start today's workout, one-tap
  sets with Crown edits, rest ring, live heart rate; the phone stays the source of
  truth and Health gets one workout); nine App Intents with phrases and four Control
  Center controls; fixes from code-blind run 3; weekly chart no longer blocks scroll.
- This landing, uploaded next: native recipes. Build one from usual foods (10 taps),
  save a meal as one (3 taps), log by serving, grams or share of the pot, or as its
  ingredients; edit and duplicate never touch past entries. Full UI suite green
  (86 run, 25 opt-in skips, 0 failures).

## Current outcome

1 and 2 are done for every primary screen. Working on 3 (depth past MacroFactor) and
4 (Apple integration) in parallel.

## In flight

- `claude/goals` (helper): nutrient goal editor (floor/target/ceiling with ordering
  checks), up to three nutrients pinned on Today, completeness line ("from 3 of 5
  foods that report it"). PARITY N29 and N32.

## Next three steps

1. Land goals, then code-blind usability run 4 on the realistic seed covering recipes,
   goals and the new Today; fix what it finds.
2. Outcome 3 from `docs/PARITY.md`: multi-select move (N07), removing an hourly
   suggestion (N09), duplicate custom food (N10), recipe sharing and import (N12).
3. Outcome 4: notification actions, Spotlight for foods and recipes; widgets and
   complications once Ali registers the App Group.

## How to resume

Work in `~/Desktop/Exerly-Fitness-claude` on `claude/next`. Fixtures:
`EXERLY_FIXTURE_PORT=<port> node scripts/ios-fixture-api.cjs` (39140–39148). Capture:
`apps/ios/scripts/capture.sh` (CAPTURE=0 for regression). Full suite:
`OUT=<dir> apps/ios/scripts/uitest-shards.sh <udid>:<port> ...` (four shards ≈ 70 min).
Watch: `apps/ios/scripts/watch-uitest.sh` on the paired "Exerly Claude Watch" pair.
Code-blind run: `apps/ios/scripts/drive.sh`. Release: `release-in-session.sh --upload`
then `node apps/ios/scripts/asc.mjs internal <build>`. Push with `DEVELOPER_DIR` set
to Xcode 26.2, or the pre-push SwiftLint crashes. In T3, never end a turn without
background work (`sleep 1200` with run_in_background).

## Merge status

| Branch       | Unlanded                    | Last landed |
| ------------ | --------------------------- | ----------- |
| claude/next  | nothing                     | this commit |
| claude/goals | nutrient goals, in progress | none        |

## Risks

- The App Group is still unregistered (QUESTIONS_FOR_ALI.md): Today and Next workout
  widgets and watch complications wait on it.
- Watch: unverified on hardware, in background launch of the phone, and in offline
  transfer end to end. Health may get two workouts if a workout is finished on the
  phone while the watch's notice is still queued.
- App Intents: speaking, Spotlight, the Lock Screen and the Action button are
  unverified; closed-app runs are covered by unit tests only.
- Recipes: ingredient reordering isn't covered by a UI test.
- HealthKit background delivery needs an entitlement and a regenerated profile.
- Open Food Facts search budget is 10/min server-wide; type-ahead spends it faster.
- Six idle "Exerly App" simulators from the Astra run are left alone per the brief.

# Claude ledger

Rewrite this file each iteration and keep it under 80 lines. See `docs/AGENT_BRIEF.md`.

## Since the last TestFlight build (2610100644, workout Live Activity)

Landed on main with the full UI suite green (82 run, 24 opt-in skips), then uploaded:

- Logging without opening Exerly: nine App Intents with phrases (log weight, quick
  add, log a usual food, repeat a meal, calories left, start workout, search, scan,
  weigh in) and four Control Center controls, which need no App Group.
- First Watch app: start today's workout, one-tap sets with Crown edits, rest ring
  with +30 s and Skip, live heart rate, finish. The phone stays the source of truth
  through WatchConnectivity; Health gets one workout. Watch App ID and profile made.
- Fixes from code-blind run 3: last set holds its rest, ring opens Targets, weigh-in
  Undo, every standard nutrient listed, one nutrient table, This month span, Profile
  and Preferences tidy-ups, late-night search header, realistic driver seed.
- Weekly training chart picks a week by tap, so the page scrolls over it.
- Recipes (helper finishing): builder, save a meal as a recipe, log by serving, grams
  or share of the pot, log as ingredients, edit and duplicate without touching logs.

## Current outcome

1 and 2 are done for every primary screen. Working on 4 (Apple integration) and 3
(depth past MacroFactor) in parallel.

## Next three steps

1. Merge recipes, rerun the food, Today and recipe UI tests, land and upload.
2. Code-blind usability run 4 on the realistic seed, covering recipes, Shortcuts
   and the watch; fix what it finds.
3. Outcome 3 depth from `docs/PARITY.md`: multi-select move (N07), removing an
   hourly suggestion (N09), duplicate custom food (N10), nutrient goals with
   floor/target/ceiling (N29), weekday targets (S03). Outcome 4: complications and
   widgets once Ali registers the App Group; notification actions; Spotlight.

## How to resume

Work in `~/Desktop/Exerly-Fitness-claude` on `claude/next`. Fixtures:
`EXERLY_FIXTURE_PORT=<port> node scripts/ios-fixture-api.cjs` (39140–39148). Capture:
`apps/ios/scripts/capture.sh` (CAPTURE=0 for regression). Full suite:
`OUT=<dir> apps/ios/scripts/uitest-shards.sh <udid>:<port> ...` (four shards ≈ 2 h).
Watch: `apps/ios/scripts/watch-uitest.sh` on a paired "Exerly Claude Watch" pair.
Code-blind run: `apps/ios/scripts/drive.sh`. Release: `release-in-session.sh --upload`
then `node apps/ios/scripts/asc.mjs internal <build>`. In T3, never end a turn without
background work (`sleep 1200` with run_in_background).

## Merge status

| Branch         | Unlanded                       | Last landed |
| -------------- | ------------------------------ | ----------- |
| claude/next    | nothing                        | this commit |
| claude/recipes | recipes, screenshots in review | none        |

## Risks

- The App Group is still unregistered (QUESTIONS_FOR_ALI.md): Today and Next workout
  widgets and watch complications wait on it.
- Watch: unverified on hardware, in background launch of the phone, and in offline
  transfer end to end. Health may get two workouts if a workout is finished on the
  phone while the watch's notice is still queued.
- App Intents: speaking, Spotlight, the Lock Screen and the Action button are
  unverified; closed-app runs are covered by unit tests only.
- HealthKit background delivery needs an entitlement and a regenerated profile.
- Open Food Facts search budget is 10/min server-wide; type-ahead spends it faster.
- Six idle "Exerly App" simulators from the Astra run are left alone per the brief.

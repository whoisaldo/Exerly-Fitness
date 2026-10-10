# Claude ledger

Rewrite this file each iteration and keep it under 80 lines. See `docs/AGENT_BRIEF.md`.

## Shipped today (internal TestFlight)

- 2610101011: first Watch app (start today's workout, one-tap sets with Crown edits,
  rest ring, live heart rate); nine App Intents and four Control Center controls;
  fixes from code-blind run 3; weekly chart no longer blocks scroll.
- 2610101238: native recipes (build from usual foods, save a meal, log by serving,
  grams or share of the pot, or as ingredients).
- 2610101740: nutrient goals (floor/target/ceiling, history-safe), up to three pinned
  nutrients on Today with completeness, macros that lead with what's left.
- This landing, uploaded next:
  - Fixes from code-blind run 4 (8/8 tasks, no blockers): recipe ingredients ask for
    their amount with every serving (chili 53 → 34 actions), keypad selects the
    number, one Done, a waiting check-in shows on Today, search by most words,
    meal menu with Save as recipe, Today tab returns to today, short workouts keep
    their day, VoiceOver set state, meal time, 0.1 lb steps, workout names.
  - Actionable reminders: log usual or repeat yesterday's meal (2 taps), a new
    weigh-in reminder that takes a typed weight (2 taps), Start workout; Spotlight
    finds the person's own foods (usual foods log in 1 tap). The API change for the
    weigh-in reminder deploys with this push.

## Current outcome

1 and 2 are done for every primary screen. Working on 3 (depth past MacroFactor) and
4 (Apple integration).

## Next three steps

1. Code-blind run 5 on the realistic seed: goals and pins, reminders, recipes again.
   Chili is still 34 actions; under 20 needs amount entry in search ("500 g beef").
2. Outcome 3 from `docs/PARITY.md`: multi-select move (N07), removing an hourly
   suggestion (N09), duplicate custom food (N10), recipe sharing and import (N12),
   package sizes ("1 can") for foods without them.
3. Outcome 4: widgets and watch complications once Ali registers the App Group;
   HealthKit background delivery (entitlement and profile).

## How to resume

Work in `~/Desktop/Exerly-Fitness-claude` on `claude/next`. Fixtures:
`EXERLY_FIXTURE_PORT=<port> node scripts/ios-fixture-api.cjs` (39140–39148); restart
them after merging API changes. Capture: `apps/ios/scripts/capture.sh` (CAPTURE=0).
Full suite: `OUT=<dir> apps/ios/scripts/uitest-shards.sh <udid>:<port> ...` (122 tests;
three shards take over 2 h, so use four or split the run under the 2 h task limit).
Watch: `apps/ios/scripts/watch-uitest.sh`. Code-blind run: `apps/ios/scripts/drive.sh`.
Release: `release-in-session.sh --upload` then `node apps/ios/scripts/asc.mjs internal
<build>`. Push with `DEVELOPER_DIR` set to Xcode 26.2, or pre-push SwiftLint crashes.
In T3, never end a turn without background work (`sleep 1200` with run_in_background).

## Merge status

| Branch      | Unlanded | Last landed |
| ----------- | -------- | ----------- |
| claude/next | nothing  | this commit |

## Risks

- The App Group is still unregistered (QUESTIONS_FOR_ALI.md): Today and Next workout
  widgets and watch complications wait on it.
- Watch: unverified on hardware, in background launch of the phone, and in offline
  transfer end to end.
- App Intents and reminders: speaking, the Lock Screen with a passcode, the Action
  button and actions that relaunch a terminated app are unverified; unit-tested only.
- The weigh-in reminder's text field gets a letter keyboard; iOS offers no number pad
  for notification text input.
- Two devices editing nutrient goals or pins offline on the same day: the later wins.
- Open Food Facts search budget is 10/min server-wide; type-ahead spends it faster.
- Six idle "Exerly App" simulators from the Astra run are left alone per the brief.

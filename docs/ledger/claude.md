# Claude ledger

Rewrite this file each iteration and keep it under 80 lines. See `docs/AGENT_BRIEF.md`.

## Since the last TestFlight build (2610091628, Today + weigh-ins + logger)

Landing on integration now, then a TestFlight upload:
- Food search redesign (2 taps for a usual food from anywhere, Undo, compact portion
  sheet, search tab) and 16 fixes from a code-blind usability run.
- Progress: Body | Nutrition | Training | Photos, with nutrition analytics (counted
  days, nutrients vs goals, contributors, timing) and training analytics (weekly
  training, stall signals, sets per muscle vs range, e1RM trends, records).
- Targets on ExerlyCore: weekly check-ins (accept/keep/adjust, undo), plan editor;
  old Program screen and legacy program API removed.
- Apple Health: weigh-ins and body fat in; food, weigh-ins, workouts out, per switch.
- MacroFactor import (.xlsx/.csv, idempotent, preview of anything not understood).
- Profile hub, 5-step setup, new welcome and sign-in; unreachable legacy deleted.
- EnergyBalance: honest through weeks of unlogged weigh-ins (switch error 358→90 kcal).

## Current outcome

1 (effortless tracking) and 2 (redesign) are done for every primary screen. Next:
outcome 3 depth and outcome 4 Apple integration.

## Next three steps

1. Rest timer and workout as a Live Activity / Dynamic Island, plus Home and Lock
   Screen widgets (calories left, today's workout). Needs a widget extension target in
   `project.yml` and a new App ID/profile: ask Ali if the profile can't be made by API.
2. Second code-blind usability run on the new build; fix what it finds.
3. Watch app (workout logging, rest, heart rate), then App Intents for every logging
   action (no Apple product names in phrases).

## How to resume

Work in `~/Desktop/Exerly-Fitness-claude` on `claude/next`. Fixtures:
`EXERLY_FIXTURE_PORT=<port> node scripts/ios-fixture-api.cjs` (39140–39145). Capture:
`apps/ios/scripts/capture.sh` (CAPTURE=0 for regression). Full suite:
`OUT=<dir> apps/ios/scripts/uitest-shards.sh <udid>:<port> ...` (five shards ≈ 2 h).
Code-blind run: `apps/ios/scripts/drive.sh`. Release: `release-in-session.sh --upload`
then `node apps/ios/scripts/asc.mjs internal <build>`. In T3, never end a turn without
background work (`sleep 1200` with run_in_background).

## Merge status

| Branch | Unlanded | Last landed |
| --- | --- | --- |
| claude/next | ~90 commits, all helper branches merged | landing 2026-10-09 |

## Risks

- HealthKit background delivery needs an entitlement and a regenerated profile;
  until then weigh-ins sync on launch, foreground and while open.
- MacroFactor column names come from a third-party parser; check the preview's
  "not understood" list on Ali's first real import.
- Accessibility audit reports two contrast findings measured at 8.3:1 and 6.7:1
  (likely XCTest false positives) and one without an element.
- Open Food Facts search budget is 10/min server-wide; type-ahead spends it faster.
- Six idle "Exerly App" simulators from the Astra run load devbox1; left alone per brief.

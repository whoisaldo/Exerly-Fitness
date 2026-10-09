# Claude ledger

Rewrite this file each iteration and keep it under 80 lines. See `docs/AGENT_BRIEF.md`.

## Since the last TestFlight build (2610091628, from e2791b22, live for Ali)

2610091628 has Today, weigh-ins with trend weight, and the new workout logger. Since then
on `claude/next` (not yet landed):
- Food search redesign: meal chips, Recent · Favorites · My foods, type-ahead, "+" logs
  the last portion with Undo (2 taps from anywhere), compact portion sheet; search tab
  uses `presentation: .tab`.
- Progress is Body | Nutrition | Training | Photos; Milestones removed. Training analytics
  (weekly training, stall signals, sets per muscle vs range, e1RM trends, records) merged.
  Nutrition analytics in flight (`claude/nutrition-insights`).
- Today: Undo after deleting an entry, warning-style failure toasts, future days.
- Stall/deload evidence in the person's unit; Train's "Insights" row renamed.

## Current outcome

1 (effortless tracking): every target met on the simulator. Usability run by a code-blind
agent in progress (`artifacts/usability/run2`, driver `apps/ios/scripts/drive.sh`).
2 (redesign): Today, Train, logger, food search, Progress done; Profile, onboarding,
nutrition program and settings still old.

## Next three steps

1. Full UI suite (3 shards) → hand failures to a test-fixing agent → land on
   integration, merge into `main`, upload TestFlight via `release-in-session.sh`.
2. Fix what the usability run finds; merge nutrition analytics.
3. Next visible slice: Profile and nutrition targets redesign, then Apple integration
   (rest-timer Live Activity, widgets), and a MacroFactor import so Ali can test with
   his own history on device.

## How to resume

Work in `~/Desktop/Exerly-Fitness-claude` on `claude/next`. Fixtures:
`EXERLY_FIXTURE_PORT=<port> node scripts/ios-fixture-api.cjs` (391xx). Capture:
`apps/ios/scripts/capture.sh` (CAPTURE=0 for regression). Full suite:
`OUT=<dir> apps/ios/scripts/uitest-shards.sh <udid>:<port> ...`. Release (signing needs
the GUI session): `apps/ios/scripts/release-in-session.sh --upload`, then
`node apps/ios/scripts/asc.mjs internal <build>`.

## Merge status

| Branch | Unlanded | Last landed |
| --- | --- | --- |
| claude/next | ~35 commits (Today → training insights) | not yet this run |
| claude/nutrition-insights | in progress | — |
| claude/food, logger, body, training-insights | merged into claude/next | — |

## Risks

- devbox1 is overloaded: 17 booted simulators, including 6 idle "Exerly App" ones from
  the Astra run that the brief says to leave until Ali confirms Astra stopped.
- Open Food Facts search budget is 10/min server-wide; type-ahead spends it faster.
- `EnergyBalance` trend runs up to 0.89 kg off when food logging starts after weeks of
  weigh-ins only. Fix in ExerlyCore.
- Session restarts stop subagents; resume them with SendMessage and check worktrees.

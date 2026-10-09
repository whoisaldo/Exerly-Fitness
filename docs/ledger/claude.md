# Claude ledger

Rewrite this file each iteration and keep it under 80 lines. See `docs/AGENT_BRIEF.md`.

## Since the last TestFlight build

Nothing yet. The last builds came from the two-agent run. A13 (2610072129) is live, and
A14 and A15 were withheld.

## Current outcome

1: Tracking that's effortless. Not started.

## Next three steps

1. Baseline. Build the app on an "Exerly ..." simulator and screenshot every primary
   screen in light and dark. Count taps for each target task in outcome 1, and write down
   what makes each flow slow or unclear. Save everything under `artifacts/screens/`.
2. From that baseline, design the new navigation and the core logging flows: the diary,
   food entry, the workout logger and the weigh-in. Then build the first one.
3. Decide whether the unlanded commit on `agent/app-nutrition` (a saved recipe editing
   draft) is worth cherry-picking.

## How to resume

Work in `~/Desktop/Exerly-Fitness-claude` on `claude/next`. Read the brief, then this
file, then continue from the next steps.

## Risks

- The Astra thread may still be running until Ali confirms it has stopped. Leave its
  worktrees and simulators alone.

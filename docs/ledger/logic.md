# Logic agent ledger (Claude)

Owned by the logic agent; see "Two agents" in `docs/AGENT_BRIEF.md`. Astra wrote the entries
below as the single agent before the split on 2026-10-06, and M1 moved to the logic agent
with them. Keep what holds up.

Read `AGENT_BRIEF.md` first. This ledger records observed results, not planned completion.

## Current milestone

2026-10-06: M1, PostgreSQL and account foundation. Starting revision `9a8e0dbe`,
branch `feat/mobile-production-foundations`. Working tree was clean. The Sideband
repository resolves and origin points to `sidebandstudio/Exerly-Fitness`.

The brief's Done condition is not met. There is no verified parity inventory yet.
Existing implementation uses MongoDB in production and SQLite in tests, with
native offline queues, revision checks, session rotation and mutation replay.

## Next three steps

1. Record all existing test commands and the Xcode 26.2 device build baseline.
2. Create a sourced parity inventory and a foundation design note. Implement
   PostgreSQL with plain SQL migrations, isolated tests, container startup and
   backup/restore verification. Preserve tested sync behavior.
3. Complete Sign in with Apple and account lifecycle gaps, verify native builds
   and simulator journeys, prepare the internal TestFlight pipeline, then proceed
   through the remaining priorities in the brief.

## Evidence

- Fresh baseline output goes in `artifacts/agent-baseline/`. No fresh tests have
  completed yet.
- Existing reports in `docs/MOBILE_PRODUCTION_STATUS.md` are historical evidence.
  They do not establish current device parity or TestFlight availability.

## Risks and external dependencies

- Neon creation and DigitalOcean secrets require Ali. Local PostgreSQL work can
  proceed without them.
- Public legal wording, external review and license decisions remain Ali's.
- Apple signing setup and internal TestFlight availability have not been checked.
- Never use real health data or change another app's profiles or services.

## Resume exactly

Read the brief and this ledger, inspect `git status`, run
`gh repo view sidebandstudio/Exerly-Fitness`, and inspect the most recent evidence
under `artifacts/agent-baseline/`. Use
`DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer` for native checks.
Use only Exerly-owned simulators and scratch ports. Do not change the protected
services listed in the brief and machine instructions.

# App agent ledger (Astra)

Owned by the app agent; see "Two agents" in `docs/AGENT_BRIEF.md`. Records observed results,
not planned completion.

## Current milestone

Not started. The integration branch is `feat/mobile-production-foundations`.

## Next three steps

1. Create `docs/PARITY.md` from primary sources, covering every user-facing feature.
2. Set up the internal TestFlight pipeline for Exerly (see Rules, Releases).
3. Build the new app shell and design system, then the training logging flow on a stub of
   ExerlyCore until the logic agent publishes its interface in `docs/handoff/to-app.md`.

## Evidence

None yet.

## Risks and external dependencies

None recorded yet.

## Resume exactly

Read the brief, this ledger and `docs/handoff/to-app.md`, and check `git status` in your
worktree. Use `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer`, only "Exerly
App" simulators, and ports 39200-39299 (plus 39001-39003 for the existing scripts).

# App agent ledger (Astra)

Owned by the app agent; see "Two agents" in `docs/AGENT_BRIEF.md`. Records observed results,
not planned completion.

## Current milestone

2026-10-06: A1, sourced parity inventory, fresh baseline and internal TestFlight
pipeline. Start 89394c13 on agent/app. Integration is
feat/mobile-production-foundations. Done is not met. Design is
docs/design/002-app-foundation.md.

## Next three steps

1. Complete A1 native baseline after fixing iOS 26's delayed Save Password sheet.
   Focused activity/sleep regression passes in artifacts/app-baseline/password-race.
2. Create ASC app record through the desktop browser as Ali requested, upload and
   assign an internal build. Desktop unlock is in progress. Never put credentials
   in this ledger or project files.
3. Commit/rebase on integration, link published ExerlyCore and start A2 shell and
   training flow using SQLite persistence. Review findings are in to-logic.md.

## Evidence

Sideband repository resolves and origin uses it. Reviewed training contract at
dd8909b0; SQLite 4d10d8dc also landed. PARITY.md and RELEASE.md created.

- npm ci and all 153 API tests pass, artifacts/app-baseline/api-tests.log.
- All 68 native unit tests pass, original native-tests.log. UI baseline interrupted
  after delayed password-save sheets blocked controls. First targeted calendar
  rerun passes in password-sheet.xcresult. Subsequent activity run revealed the
  sheet can arrive during control polling, now handled inside that loop.
  Activity/sleep offline/conflict/delete/undo rerun now passes in password-race.xcresult.
- Xcode 26.2 unsigned device build passes. One existing trailing-closure warning
  in MeasurementsTab was fixed explicitly; archive rerun needed to prove clean.
- Signed archive and IPA 1.0 (2610061518) pass release validation. Stored at
  apps/ios/build/release/2610061518. No upload yet. Release scripts have 6 Python
  and 4 Node tests, all passing. Original app icon rendered and inspected.
- ASC bundle UJ5X8TJKNL, profile H5896RXW3D, HealthKit enabled. Reused certificate,
  no other identifiers/profiles touched. App record absent as of 11:20 EDT.

## Risks and external dependencies

App record creation requires website access. User explicitly asked for computer
use on devbox1 and authorized normal unlock. Do not stop other work while waiting
for any browser authentication. No TestFlight or physical-device verification yet.
Core review requests include validation, persistent rest timers and completeness
metadata. Existing UI still forces dark and needs the A2 design pass.

## Resume exactly

Read the brief, this ledger and `docs/handoff/to-app.md`, and check `git status` in your
worktree. Use `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer`, only "Exerly
App" simulators, and ports 39200-39299 (plus 39001-39003 for the existing scripts).

Large simulator: 7189880A-91EC-4555-83E8-A37464802FE6, iOS 26.2 iPhone 17 Pro Max.
Small: 7D2096B8-3E67-477F-82BF-0E2BEDF2CA2B, iOS 18.6 iPhone SE 3.
Use .deriveddata/app-tests, parallel testing NO. Existing scripts own their fixture
process; wait for cancellation to exit before starting the next native test run.
Build commands and signing details are in RELEASE.md. Test artifact directories
are ignored. Desktop screenshots contain private browser context, never commit them.

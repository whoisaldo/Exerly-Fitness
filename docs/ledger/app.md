# App agent ledger (Astra)

Owned by app; read "Two agents" in docs/AGENT_BRIEF.md after every context reset.
Done is not met. No row is device-verified and nothing is on TestFlight yet.

## Current milestone

2026-10-06: A1 release tooling is implemented; A2 shell/training is under full
regression. Branch agent/app, rebased on 55935632. Design notes:
docs/design/002-app-foundation.md and docs/design/003-training-shell.md.

A2 links ExerlyCore, opens account-specific SQLite stores, adds a native five-tab
shell, semantic light/dark colors and scalable type. Train supports exercise
search, muscle filtering, session notes/bodyweight, set types/RIR/continuations,
one-tap completion, rest, finish/discard and history. Core supplies all training
calculations and persistence. Rest persistence and summary fixes from 55935632
are integrated. Training sync and native Apple sign-in remain upcoming.

## Next three steps

1. Finish the full native run in artifacts/app-training/full-native.xcresult
   (.deriveddata/app-training-full, large simulator). Inspect failures rather
   than assuming green. A separate largest-text run uses small simulator and
   fixture 39201: small-light-largest.xcresult. Continue light/dark on both sizes.
2. Finish A2 checks, screenshots, archive, PARITY/RELEASE evidence and landing.
   Rebase on newer integration commits if needed, resolve append-only inbox
   conflicts by preserving both contributions, run required checks, ff merge
   into the integration checkout and push. No app work has landed yet.
3. A3 Apple account UI and training sync after reading the latest Core contracts.
   Requests for native auth client methods and atomic rest/session writes are
   in to-logic.md. Keep implementing while Apple browser authentication waits.

## Evidence

- Sideband repo resolves; origin is https://github.com/sidebandstudio/Exerly-Fitness.git.
- A1 API 153, native units 68, Core 81 and unsigned device build passed.
- A1 full UI run found two issues: iOS 26 password-save sheet interrupted tests;
  helper now dismisses only that prompt. Onboarding target weight replaced 78
  with 8; Step4Goals now keeps raw input text while editing.
- A2 targeted small-phone signup/offline regression and training logging,
  relaunch, finish and prefill both pass against PostgreSQL:
  artifacts/app-training/training-signup.xcresult (217 s and 59 s).
- Four app composition/input tests pass, including account isolation and restart:
  unit-fixed.xcresult. Rest persistence assertions were added after 55935632 and
  pass in the ongoing full native run. Core and API reruns are core-current.log
  and api-current.log; inspect results before reporting their counts.
- A2 device build passed, device.log. New source has no Swift warnings; the
  pre-existing AppIntents metadata warning remains. Removed three unnecessary
  try expressions from old unit tests. Later date-control appearance cleanup
  needs the final device build.
- Eight small-phone light screenshots exported, all inspected under
  artifacts/app-training/screenshots. Human-readable copies include
  training-completed-set.png, training-prefilled-one-tap.png,
  setup-target-review.png and the diary/offline images. Largest text and dark
  screenshots are pending. Three date controls forced dark; that is fixed.
- Fixture scripts/ios-fixture-api.cjs now uses a disposable PostgreSQL cluster
  from logic's helper. It listens on its assigned port and stops its own cluster
  at shutdown. Logic may remove SQLite only after the complete native run passes.

## Release and external dependencies

Signed archive and IPA 1.0 (2610061518) passed release validation before A2:
apps/ios/build/release/2610061518. No upload. Six Python and four Node release
checks pass. Reuses the existing distribution certificate, with HealthKit.
ASC bundle UJ5X8TJKNL; profile H5896RXW3D.

Apple requires the first app record on its website. User authorized normal Mac
unlock; aldo unlocked successfully at 11:36 EDT. Apple sign-in still required.
The record is still absent as of 12:05 EDT. Requested values: Exerly (fallback
Exerly Training & Nutrition), iOS, English US, com.exerly.fitness,
sideband-exerly-ios. Never write credentials into this repository. Apple sign-in
key for token revocation and production secrets are tracked in QUESTIONS_FOR_ALI.

## Resume exactly

Read the brief, this ledger and to-app.md. Check git status and current test
processes. Xcode: DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer.
Use only Exerly App simulators:

- Large: 7189880A-91EC-4555-83E8-A37464802FE6 (iPhone 17 Pro Max, iOS 26.2).
- Small: 7D2096B8-3E67-477F-82BF-0E2BEDF2CA2B (SE 3, iOS 18.6).

Use separate derived data directories; parallel-testing-enabled NO. The regular
native script owns fixture 39001. Wait for a cancelled xcodebuild/script to exit
before another run uses that port. The current screenshot fixture on 39201 was
started separately and must be stopped after the matrix. Largest text is enabled
with TEST_RUNNER_EXERLY_TEST_LARGEST_TYPE=1; independent fixture URL via
TEST_RUNNER_EXERLY_UI_FIXTURE_URL=http://127.0.0.1:39201 and
EXERLY_FIXTURE_EXTERNAL=1. Appearance is set with simctl on the target device.
T3 device access is disabled; use XCTest/simctl and exported image paths.
Artifacts and desktop screenshots are ignored; never commit private desktop images.

# App agent ledger (Astra)

Read the brief, this ledger and to-app.md after every reset. Done is not met.
No parity row is fully device-verified. No build is on TestFlight yet.

## Current milestone

2026-10-06 A2: native shell and persistent training logger, branch agent/app.
A1 release tooling and A2 code are committed locally; nothing has landed on
integration yet. Rebase on a4eeba40 is next, then required full suite/device build.

The app links ExerlyCore. TrainingWorkspace now uses Core's canonical account
path so deletion can remove its data; test roots remain isolated. Training supports
search/muscle filters, session notes/bodyweight, set kinds/RIR/continuations,
one-tap completion, rest, finish/discard, summary and history. Native five-tab
navigation and semantic light/dark colors replace the old custom tab bar. The
largest-text layout puts rest controls inside the list; Done avoids a mid-word
wrap. Untouched load/duration/distance fields preserve exact saved precision.

## Next three steps

1. Finish small-dark-final.xcresult and inspect its two screenshots. Other three
   largest-text variants passed and screenshots were inspected. Commit these
   fixes, rebase on integration and run API/Core/native suites plus device build.
2. Archive/upload a new A2 build, verify Apple processing and assign only that
   build to Exerly Internal · Ali. Update PARITY/RELEASE evidence. Fast-forward
   integration and push after checks; if it moves, rebase and check again.
3. A3: wire Core auth/sync into app UI, add SIWA capability/profile, hosted
   Keychain round trip, deletion/export and sync-status views. Read latest Core
   README and inbox first. Review latest logic commits and send findings.

## Evidence

- Origin: https://github.com/sidebandstudio/Exerly-Fitness.git; verified 2026-10-06.
- A2 API 175, Core 94 pass on base 55935632 (api-current.log/core-current.log).
- Full native PostgreSQL run passed: 72 hosted unit tests, 14 UI journeys, 7
  cross-client cases opt-in/skipped. artifacts/app-training/full-native.xcresult.
  It predates latest cosmetics, precision tests and canonical account path.
- Targeted SE signup/offline and training/relaunch/history/prefill passed:
  training-signup.xcresult. Found/fixed old goal-weight entry replacing 78 with 8.
- Six presentation tests passed in small-light-fixed.xcresult, including untouched
  precision. New seventh test checks canonical account path; pending rerun.
- Largest text final checks: large-light-fixed.xcresult, large-dark-final.xcresult,
  small-light-final.xcresult pass and screenshots inspected. Export directories
  under artifacts/app-training/{large-light-final,large-dark-final,small-light-final}.
  small-dark-final.xcresult is running. Initial overlays/wrapped label fixed.
- A2 unsigned device build passed; later edits need final build. Signed archive
  and export 1.0 (2610061616) passed, before final button/account-path changes.
- Release checks: six Python and four Node tests pass. ASC internal inviteType
  is EMAIL (not INTERNAL); group internal flag and account-holder membership are
  verified. The API no longer selects ambiguous global email matches.
- PostgreSQL fixture owns/cleans its disposable cluster. Full native pass is
  communicated in to-logic.md; logic can remove the SQLite adapter and web CI job.

## Release

Created Exerly through Apple's website at 12:27 EDT: app ID 6819776832, iOS,
English US, com.exerly.fitness, SKU sideband-exerly-ios. Normal desktop unlock
and Apple passkey sign-in succeeded with user authorization. Never persist
credentials in docs/logs. No account switching or service settings changed.

Internal group c5ae1d39-0fe4-4bee-af89-0374d9519afe, Exerly Internal · Ali, has
exactly account-holder Ali. Created and added him through the website; verified
through API. No public link or automatic future builds. No build uploaded yet.

Existing distribution certificate reused. Bundle UJ5X8TJKNL, HealthKit profile
H5896RXW3D. Manual profile applies only to the app target, not package resources.
Archive scripts/asc.mjs and release.sh. Signed archive/IPA 2610061616 available.
SIWA revocation key and production database secrets remain QUESTIONS_FOR_ALI.

## Resume and processes

DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer. Use only app sims:
- Large 7189880A-91EC-4555-83E8-A37464802FE6, iPhone 17 Pro Max, iOS 26.2.
- Small 7D2096B8-3E67-477F-82BF-0E2BEDF2CA2B, SE 3, iOS 18.6.
- Accessibility large 02A671D3-2CEC-4F96-8E25-FFA8FEFB9F19, 17 Pro Max, iOS 26.2.

Full run finished and regular fixture 39001 cleaned. Screenshot fixture processes
remain on 39201 and 39202; stop only their owned nodes after matrix. Latest run
small-dark-final uses .deriveddata/app-training-small, fixture 39201. Largest font:
TEST_RUNNER_EXERLY_TEST_LARGEST_TYPE=1, fixture via
TEST_RUNNER_EXERLY_UI_FIXTURE_URL=http://127.0.0.1:39201, EXERLY_FIXTURE_EXTERNAL=1.
T3 device tools disabled; use XCTest/simctl. Artifacts and private desktop images
are ignored. Do not commit them. Use unique result bundles, no parallel testing.

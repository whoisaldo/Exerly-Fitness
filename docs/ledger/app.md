# App agent ledger (Astra)

Read the brief, this ledger and to-app.md after every reset. Done is not met.
No parity row is fully device-verified. Keep working from this ledger.

## Current milestone and next steps

2026-10-06 13:49 EDT. A2 landed and pushed at84b7de51. Integration advanced
to3685dbf2 with logic's shared session bridge, review fixes and MCP. Primary
agent/app fast-forwarded to7038d86e, including the prepared A3 UI commit.

1. Connect A3 account UI and training sync through AuthViewModel.accountAPI;
   adopt docs/handoff/attachments/SessionBridgeTests.swift. Read the new handoff.
2. Add hosted lifecycle composition and actual fixture-server UI coverage for
   sync, account switching, export and deletion. Run full suite/device build.
3. Review largest-text matrix for connected screens, archive/upload A3, update
   PARITY/RELEASE, rebase and land. Do not claim real Apple authorization until
   exercised on a signed device. TestFlight currently2610061654.

## Active A3 work, 2026-10-06 14:09 EDT

Primary rebased to67c8db44; app commit8b2f4c40 connects the shared session,
training sync, native Apple sign-in, export and deletion. New recovery/export and
accessibility fixes are uncommitted. Do not lose them. Latest integration now
7a97ae34 adds token management; review/rebase before the full final run.

21 hosted tests pass in artifacts/account/recovery-hosted.xcresult: 15 shared
session tests adopted from the attachment plus six workspace lifecycle/export
checks. Uses AuthViewModel.accountsAwaitingLocalCleanup as the sole persistent
queue, waits for Core sync shutdown, purges local training/legacy data, then
finishLocalCleanup. Root responds at launch and when that queue changes.
AccountExport.merging now includes unsynced training; the separate offline
export is explicitly training/suggestions only. Pending legacy food is disclosed
as excluded and needs a later Core export extension.

Earlier connected checks: API213/Core164/device build passed. Account switching
passed. Actual sync/export/delete passed normal plus small-dark and large-light
at largest type; all 10 matrix images inspected. They predate the export changes.
The first normal run's share-sheet assertion used a hidden UIKit identifier;
changed to visible Close. Offline test initially forgot offline:true and the
fixture did not intercept /v1, so its status assertion failed. Both corrected;
workout relaunch and reconnect server upload already passed. New tests also drop
the deletion acknowledgement to exercise server-confirmed recovery.

Screenshot review found Welcome's old flame placeholder and clipped largest-text
buttons. Uncommitted fixes use the exact E/pulse asset and wrapping/min-height
ActionButtons in a scrolling Welcome. Need inspect fresh light/dark/small/large
screens and run full regressions after final rebase. No new A3 TestFlight upload.

Fixtures39203/39204/39205 are running OLD code and must be restarted before the
new offline/deletion tests. Their nodes are app-owned. Old39201/39202 were stopped
cleanly. All completed UI/hosted sessions can be closed; no current test run.
Use Primary derived data app-account/originalLarge, account-small/SE and
account-large/accessibilityLarge. Original app-next keeps only earlier evidence;
continue source work solely in primary.

## User corrections that persist

Ali rejected the mint monogram and green UI. Preserve Exerly's original
purple/pink theme, neutral dark surfaces and dark default. Profile offers Light
and System explicitly. No unsolicited brand changes. The icon is the existing
purple E/pulse mark adapted from the repo's logo using built-in imagegen.
Source: apps/ios/Brand/ExerlyMark.png. render-icon.swift only sizes it to 1024px.

Ali could not sign in to first build 2610061633. Reproduced: old DO production
returns no refresh token or usable /api/bootstrap. Replacement 2610061654 uses
working PostgreSQL staging at http://100.80.149.7:39110. Native AuthViewModel
login/bootstrap passed with a synthetic test account. Credentials were sent in
chat and live only in ~/private_keys/exerly-testflight-account.json, mode 600.
Never commit or print credentials. Tailscale is required on Ali's phone and the
login screen and TestFlight notes say so. No real personal data used.

## Implementation and review

Five native tabs: Home, Train, Library, Progress, Profile. TrainingStore uses
SQLiteTrainingPersistence.defaultURL(accountID:), fixing logic's deletion-path
finding. Test databases are isolated. Training supports search/muscle filters,
notes/bodyweight, set kinds/RIR/continuations, one-tap completion, persistent
rest, finish/discard, summaries and history. Training sync is still unconnected
and labeled local. At largest text rest is an inline list section. Untouched
load/duration/distance retain saved precision. Onboarding goal-entry fix and
delayed iOS password-sheet helper are covered by full UI regressions.

Reviewed logic through a4eeba40. Open high findings: in-flight API refresh can
restore an old session; a retained sync task can outlive account switch/deletion.
Medium: Keychain delete-before-add loses old credentials on failed replacement.
A3 also needs one session owner shared with legacy AuthViewModel/APIClient;
request and exact methods are in to-logic.md. Do not build a second independent
refresh owner. No Core files removed. Legacy ProgramView uses its old library.
The PostgreSQL fixture now owns/cleans its cluster. Told logic it may remove the
SQLite adapter and required web CI; keep optional cross-client sources for now.

## Verification evidence

- Origin sidebandstudio/Exerly-Fitness verified with gh on 2026-10-06.
- On a4eeba40: API182, Core129, device build pass. Logs under
  artifacts/app-training/rebased-{api,core,device}.log.
- Full native: 75 hosted tests and 14 UI journeys pass, 7 cross-client opt-in
  skips. artifacts/app-training/rebased-native.xcresult. Before brand changes.
- Brand matrix: small-dark, small-light, large-dark, large-light.xcresult in
  artifacts/app-brand all pass; all eight largest-text screenshots inspected.
  Human-readable training-completed-set.png and training-prefilled-one-tap.png
  copied into the corresponding directories. Normal-size captures follow.
- AccountInfrastructureTests: both tests passed in app-brand/account-smoke.xcresult.
  Core hosted Keychain save/load/replace/isolation/accessibility/remove, plus
  actual staging login/bootstrap with the app's compiled endpoint.
- Release tests: 7 Python and 4 Node checks pass. Staging validation permits only
  the exact authorized host/environment; public validation requires public HTTPS.
- New signed staging archive/IPA 2610061654 passed the release validator and
  uploaded successfully. Apple reports VALID and IN_BETA_TESTING.

## Release

App: Exerly, ASC6819776832, iOS, en-US, com.exerly.fitness,
SKU sideband-exerly-ios. Created on Apple's website at 12:27 EDT through normal
unlocked desktop/passkey authorization. Never persist Mac or Apple credentials.

Internal group c5ae1d39-0fe4-4bee-af89-0374d9519afe, Exerly Internal · Ali,
contains exactly Ali and only build2610061654. No public link/automatic builds.
Replacement UUID7bf04912-8c97-4c45-9687-7a81cbb26524, English notes saved,
IN_BETA_TESTING verified 13:01 EDT. Bad build2610061633 detached; its notes say
superseded. Ali told to update and enable Tailscale. Replacement installation on
his physical phone is not yet confirmed.

Existing distribution certificate reused, team9X79V37Q89, bundleUJ5X8TJKNL,
HealthKit profileH5896RXW3D. Manual profile applies only to app target, not SPM.
Archive/IPA/logs: apps/ios/build/release/2610061654. release.sh defaults to
internal staging and always exports internal-only. Production DB and Apple
revocation secrets remain Ali's QUESTIONS_FOR_ALI items. SIWA capability is enabled; current profileJ5J395Y9AF (see below).

## Commands and processes

DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer. Only app sims:

- Large7189880A-91EC-4555-83E8-A37464802FE6, iPhone17ProMax/iOS26.2.
- Small7D2096B8-3E67-477F-82BF-0E2BEDF2CA2B, SE3/iOS18.6.
- Accessibility large02A671D3-2CEC-4F96-8E25-FFA8FEFB9F19, iOS26.2.

Full native run finished; regular fixture39001 cleaned. Screenshot fixtures on
39201/39202 remain; stop only their owned nodes after captures. Brand matrix is
finished. Use unique result bundles and -parallel-testing-enabled NO. Environment:
TEST_RUNNER_EXERLY_TEST_APPEARANCE=dark|light|system,
TEST_RUNNER_EXERLY_TEST_LARGEST_TYPE=1 for accessibility,
TEST_RUNNER_EXERLY_UI_FIXTURE_URL=http://127.0.0.1:39201 and
EXERLY_FIXTURE_EXTERNAL=1 for an existing fixture. Defaults use new fixture39001.
Full run on original Large uses .deriveddata/app-training. Small uses
.deriveddata/app-training-small; accessibility Large uses .deriveddata/app-brand.
Artifacts, signing files and private desktop captures are ignored, never commit.

Proposal review reproduced remote acceptance of invalid completed reps and lost
first custom exercise after a two-exercise proposal. Details and reproduction
paths sent in to-logic.md. A3 still needs the shared auth bridge.

## A3 prepared UI evidence

Prepared work from app-next is committed7038d86e and is now in the primary app
worktree. Continue editing only primary; app-next is retained for its evidence.
Three hosted presentation tests and two UI journeys pass. All four largest-text
light/dark small/large variants pass and screenshots were inspected:
app-next/artifacts/account/{small-light-fixed,large-dark-fixed,small-dark-final,
large-light-final}.xcresult. Explicit native alerts include Cancel.

APPLE_ID_AUTH is enabled as a primary app. ProfileJ5J395Y9AF includes HealthKit
and Apple sign-in, existing certificate unchanged. Repeat provisioning reuses
it. Signed archive/IPA2610061727 validates, not uploaded, predates final alert
changes. Release checks require both entitlements and forbid DEBUG fixture code.
Six Node/seven Python release tests pass. Connect real actions next.

# App agent ledger (Astra)

Read the brief, this ledger and to-app.md after every reset. Done is not met.
No parity row is fully device-verified. Keep working from this ledger.

## Current milestone and next steps

2026-10-06 14:28 EDT. A2 is on integration at 84b7de51. A3 source is committed
on agent/app at 1aad43b8, rebased over integration 7a97ae34. Work in this primary
worktree; app-next retains earlier evidence only. Done is not met.

1. Resolve the UUID case duplication reported in to-logic.md; only logic edits
   Core/API. The actual-server reproducer is artifacts/app-review-case. Check
   integration and the other agent's inbox/commits while doing independent work.
2. Finish the four largest-text light/dark small/large visual checks. Then
   rebase, freeze source and run the full native regression, API/Core suites and
   unsigned device build. The previous full-native.xcresult was deliberately
   interrupted for the final layout changes and UUID finding; it is NOT a pass.
3. Archive/upload A3, set internal-group notes/build, update PARITY/RELEASE,
   fast-forward integration and push. Continue A4 proposal review/audit and
   Connect an agent, then detectors/programs. Do not stop at a milestone.

## Active A3 implementation and evidence

A3 uses AuthViewModel.accountAPI as the sole session owner. AppAccountWorkspace
quiesces Core sync before sign-out, switch and deletion, and consumes the Core
persistent accountsAwaitingLocalCleanup queue at launch/changes. Failed deletion
restarts sync. Account export overlays unsynced training and proposals through
AccountExport.merging. A separate offline training export works without a server;
the UI discloses that queued legacy food/other entries are excluded. Core needs
that queue merged before claiming full export. Requested an explicit persistence
close lifecycle too. All requests and the UUID bug are in to-logic.md.

Native Apple buttons validate nonce/state/token and use the shared bridge.
Account settings support link/unlink, JSON sharing and explicit deletion alerts.
Profile hides password changes for Apple-only accounts. Training sync responds
to foreground/local changes and runs every 120 seconds while active. No API calls
or domain maths were added to screens; no Core/API files edited.

Welcome now uses the original E/pulse asset, supports scrolling and Reduce Motion.
ActionButton wraps at large type; floating fields stack labels at accessibility
sizes. Latest 1aad43b8 fixes the welcome tagline's remaining large-phone ellipsis
and gives auth back buttons an opaque background. These final fixes are in the
current screenshot run, not the earlier evidence.

Verified on e961d96e over 7a97ae34:

- API 215, Core 180 and device build pass: account/recovery-{api,core,device}.log.
- 21 hosted tests (15 adopted SessionBridge plus six workspace lifecycle/export):
  artifacts/account/recovery-hosted.xcresult. Three presentation tests passed
  earlier in connected-real.xcresult. No physical Apple sign-in verified.
- recovery-real.xcresult: actual sync/export/lost-deletion-acknowledgement,
  offline workout/relaunch/reconnect/offline export, welcome/login pass (3).
- small-light-recovery and large-dark-recovery: two UI journeys each pass;
  all 16 images inspected. Found large welcome clipping, fixed in 1aad43b8.
- small-dark-recovery and large-light-recovery: two each pass; attachments still
  need export/inspection. Current small-light-final and large-dark-final runs
  cover 1aad43b8 and add an export-options capture.
- The earlier small-dark-connected/large-light-connected images were inspected.
- Lint, format and typecheck pass (existing warnings). Six Node/seven Python
  release checks pass. First draft push failed because SwiftLint selected the
  wrong Xcode; repeat push now sets DEVELOPER_DIR. Check draft-push-xcode.log.

Current tool sessions: push 81144; small-light-final 73137; large-dark-final 3341.
Fresh fixture nodes on ports 39203/39204/39205 use the current middleware,
including /v1 offline interception and dropped deletion acknowledgements.
39206 is an isolated UUID reproducer fixture. Only stop verified app-owned PIDs.
No full native test is running now. The usual full suite takes about 25 minutes.

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
rest, finish/discard, summaries and history. Training sync is connected in A3; A2 on TestFlight still uses local training. At largest text rest is an inline list section. Untouched
load/duration/distance retain saved precision. Onboarding goal-entry fix and
delayed iOS password-sheet helper are covered by full UI regressions.

Reviewed logic through 7a97ae34. Earlier session-generation, Keychain and
proposal validation findings are fixed and tested by logic. A3 adopts the bridge
and all 15 attachment tests. UUID case identity is the new high finding. Logic's
programs and calculators are on agent/logic but not integrated/reviewed yet.

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

Use unique result bundles and -parallel-testing-enabled NO. Environment:
TEST_RUNNER_EXERLY_TEST_APPEARANCE=dark|light|system,
TEST_RUNNER_EXERLY_TEST_LARGEST_TYPE=1 for accessibility,
TEST_RUNNER_EXERLY_UI_FIXTURE_URL=http://127.0.0.1:39203 and
EXERLY_FIXTURE_EXTERNAL=1. Original Large uses .deriveddata/app-account; SE
uses .deriveddata/account-small on39204; accessibility Large uses
.deriveddata/account-large on39205. Device build uses account-device. Artifacts,
signing files and private desktop captures are ignored, never commit.

## A3 prepared UI evidence

Prepared work from app-next is committed7038d86e and is now in the primary app
worktree. Continue editing only primary; app-next is retained for its evidence.
Prepared UI: three hosted presentation tests and two UI journeys pass. All four largest-text
light/dark small/large variants pass and screenshots were inspected:
app-next/artifacts/account/{small-light-fixed,large-dark-fixed,small-dark-final,
large-light-final}.xcresult. Explicit native alerts include Cancel.

APPLE_ID_AUTH is enabled as a primary app. ProfileJ5J395Y9AF includes HealthKit
and Apple sign-in, existing certificate unchanged. Repeat provisioning reuses
it. Signed archive/IPA2610061727 validates, not uploaded, predates final alert
changes. Release checks require both entitlements and forbid DEBUG fixture code.
Six Node/seven Python release tests pass. Real actions are now connected in primary; final A3 release still pending.

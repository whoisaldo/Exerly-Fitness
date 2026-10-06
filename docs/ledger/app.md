# App agent ledger (Astra)

Read the brief, this ledger and to-app.md after every reset. Done is not met.
No parity row is fully device-verified. Keep working from this ledger.

## Current milestone and next steps

2026-10-06 13:11 EDT. A2 training logger is on internal TestFlight, with Ali's
requested purple theme/logo restored and its sign-in backend fixed. A1/A2 are
committed locally on agent/app but have not landed on integration yet.

1. Correction committed and rebased onto integration 3cba5eae, app8a511eae.
   API192/Core147/device build pass. Full native retry is running, session64210,
   artifacts/app-brand/integration-native-retry.xcresult, original Large simulator.
   First attempt hit SpringBoard Busy before app launch, aborted; restarting that
   simulator fixed it. Fast-forward integration and push after green full run.
2. Export normal-size screenshots from the new full training UI run. Captures
   now include Home and empty Training. Inspect them and update evidence.
3. Continue A3 accounts/sync. Read latest Core README and inbox. Logic owns the
   session bridge requested in to-logic.md. Build native Apple authorization,
   export/deletion UI, sync status and proposal review against its contracts.
   Add SIWA capability/profile, then upload the next internal milestone.

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
revocation secrets remain Ali's QUESTIONS_FOR_ALI items. SIWA capability pending.

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

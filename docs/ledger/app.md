# App agent ledger (Astra)

Read AGENT_BRIEF.md, this ledger and to-app.md after every reset. Done is not
met. No parity row is fully device-verified. Continue without ending at a
milestone. Current date 2026-10-06, updated 18:44 EDT.

## Current work and next steps

2026-10-06 18:44 EDT. This is A6, agent/app-programs. Done is not met. Continue.
A5 is live as2610062144, only Ali/only build, VALID/IN_BETA_TESTING. Its final
123 hosted+25 UI passed,8 skips; Core233/API226/device pass. A5 landed/pushed
integrationdf84650c. Logic then landed778540cf. Primary's additional handoff
commit481694ec is pushed on agent/app.2038 detached; neverupload2128.

A6 successfully rebased onto integration778540cf, source3c76dc6d. Ledger-only
conflicts resolved with A5 current evidence, then this A6 state restored. Source
commits are39fd9d5d composition,b85a8c68 UI,400232e1 full-width confirmations,
1f2ac0d3 plan heading first,051238ee heading capture,d60fd8c1 explicit assumed
RIR,3c76dc6d test helper recognizes native tabs instead of symbol labels. Production
source is frozen. Logic approved A6 and fixed removed-day schedule restart in
2f1f3844, included here. Integration hold requested again18:41 in Logic inbox.

FINAL GATES ACTIVE, based on3c76dc6d:
- full-a6-final/session63739 on SE39B20FBF-F0A2-4FD3-917D-A7A807851B02,
  fixture39211/session93879, DerivedData a6-full. This simulator was used for A7
  hosted tests but now belongs to this full run; do not run A7 there concurrently.
- final-core/session14165; final-api/session33312; final-device/session36096.
  API uses NODE_PATH to primary node_modules. Do not edit Core/API.
- Push rebased branch with force-with-lease after committing this ledger. Remote
  lastfe2e52db is ours. A6 archive/release not created yet. Do not reuse A5 builds.

A6 implementation: ProgramStore in sync/agent/export/supported kinds, validated
stale-safe drafts, builder/lifecycle, planned start/advance and complete program
proposal diff/original/proposed/source views. All math/selection in Core. Reserved
weightMatch hidden. iOS26 compact confirmation popover hid Cancel; fixed with
scrollable full-width sheet and fixed Cancel. Last copy improvement explicitly
states the target RIR assumed when the source set has none.

Evidence before final rebase:
- Normal builder209s/lifecycle91s/proposal pass;13 hosted. All31 normal captures
  inspected including the final proposal server undo verification.
- Nine ProgramPresentation tests pass including first-workout/no invented load
  and timed-exercise handling. Device passed340cb895, new final device running.
- Large-light-sheet: nine hosted+all4 UI pass;29 captures exported, NOT inspected.
  Includes full builder450s, lifecycle203s, proposal298s, source86s. Compiled before
  heading moved first; large-light-heading passes90s for that change, not yet
  exported/inspected. large-light-assumption/session8282 checks latest RIR copy.
- Large-dark-sheet lifecycle208s, all7 captures inspected.
- Small-light-sheet lifecycle190s,7 relevant captures exported, NOT inspected.
  Its builder fails only offscreen second-preview heading; fixed1f2ac0d3.
- Small-dark-sheet lifecycle193s and proposal299s pass. Relevant13 captures
  exported, NOT inspected. Its builder has same fixed heading-only failure.
- Small-light-input proposal288s passes, all6 captures inspected, superseded
  final run adds a capture of After3 values.

Active AX final runs (compiled before RIR copy wording, so rerun source journey
for final wording afterward; all unchanged journey results still count):
- small-light-final/session77882, SE7D2096/39206,a6-fields: source94s and
  builder600s pass; proposal running. Then latest source copy needs one rerun.
- large-dark-final/session29713, OriginalLarge7189/39208,a6-original:
  source87s and builder776s pass; proposal running. Then latest source copy rerun.
- small-dark-final/session22338, ProgramsSE45D463AE/39209,a6-proposals:
  source81s pass; builder running. Then latest source copy rerun.
- large-light-assumption/session8282, LargeAX02A671D3/39207,a6-large:
  latest copy/source plus new native-tab helper. Finish/export/inspect its4 images.
No initial stopped runs count as final proof. Once AX images, Logic review,
full/Core/API/device gates pass, create new signed archive, internal release,
update PARITY/RELEASE, ff land/push and release Logic's integration hold.

A7 worktree Exerly-Fitness-app-nutrition, agent/app-nutrition,e6d8ed3d based on
oldfe2e52db. NutritionStore composition/design015 committed. Two red regressions
then green;12 account+nutrition hosted tests pass. Own ledger and18:36 volume
snapshot/starting-target requests. Rebase A7 onto this new A6 lineage before
continuing against published preview/volume contracts. Legacy diary will retire
but server/export and pending queue remain; no app migration code. Latest review
found FoodSnapshot drops VolumeBasis; Logic asked to preserve it before A7.

## A3 final evidence and release

- `artifacts/account/full-a3-canonical.xcresult`:100 hosted +19 UI pass,
  eight opt-in skips, zero failures. Completed15:47 EDT. API219/Core183/device
  pass in canonical-{api,core,device}.log. Lint/format/typecheck/SwiftLint pass
  in `canonical-*` logs. Existing warnings only. Six Node/seven Python release
  checks pass in `final-release-*` logs; release scripts unchanged since.
- Four final largest-type account variants pass, two journeys each. All36
  screenshots inspected in account/{small-light-final,small-dark-final,
  large-light-final,large-dark-final}. Earlier32 recovery +11 normal captures
  also inspected. Banner and Start workout wrap fixes verified.
- Earlier full-a3-current had one legacy test-hook port failure, fixed and
  focused verified. full-a3-final was interrupted to adopt700cdc0d. Neither
  is the final evidence; full-a3-canonical is green.
- Signed archive/IPA1942 passed validation. Upload success15:49 EDT.
  `apps/ios/build/release/2610061942/{Exerly.xcarchive,export/Exerly.ipa,upload.log}`.
  Obsolete1907 and1727 must not be uploaded. Upload session49030 finished.

A3 native Apple buttons validate nonce/state/token and call the shared Core
bridge. Account methods link/unlink, Apple-only guard, export/share, explicit
reauth/deletion. AppAccountWorkspace shuts down Core sync before account
changes, consumes persistent confirmed cleanup queue and resumes sync after
failed deletion. Training persistence is account-specific; hosts training+agent.
Automatic foreground/120sec sync. Account export merges unsynced training and
proposals; offline export works. UI discloses pending legacy rows excluded.
Core now supplies queue export and explicit persistence close; wire into A4.

Root account notices sit above auth/TabView so they do not cover Back on iOS18.
Saved-account banner describes cached details rather than incorrectly declaring
training offline. Welcome uses original mark, scrolling/Reduce Motion, wrapping
copy and opaque auth back button. Start workout wraps at largest type.

## A4 implementation and evidence

Design008 and tests preceded implementation. Four Features/Agents files, two
hosted test files, project registration, Profile Connected agents and Training
Suggestions entry are in app-next. AgentReviewModel uses Core accept/reject/undo,
including stale/invalid refusal and sync of refusal audits. Full field diffs,
unit presentation, raw JSON fallback, verified/mismatch/unavailable metrics,
evidence/caveats/confidence/falsifier, offline decisions and activity history.
Stale refusal scrolls into view and receives VoiceOver focus.

Tokens use account-bound API. Default read+propose; read-only available; direct
write requires explicit native alert with Cancel. Secret masked until Show,
copy is local-device-only with ten-minute expiry, clear on Close/disappear,
hide on background and discard a creation completing after Close. Revocation
requires confirmation and remains reflected if the subsequent refresh fails.
Permission label wraps through Menu/Picker, fixed37299a9d.

- Eight hosted tests pass, including actual store decisions and token races.
- Real-server UI: offline accept/relaunch/sync/undo/reject/audit; stale proposal
  preserves later workout edit; token default/masking/revoke/cancel/direct-write
  cancellation. No token secrets printed or exposed in test captures.
- Normal SE three journeys pass across real-api-first/offline-navigation-fixed;
  all13 images inspected.
- large-dark-scroll and large-light-canonical: eight hosted+three UI pass.
  All13 and14 images inspected. Permission picker clipping found, fixed37299.
- small-light-canonical review failed only upward gesture after undo. Helper
  now drags inside visible list below account banner (4d89933a). Not passing
  evidence. All13 captures inspected.
- small-light-final: all three UI pass; all14 images inspected.
- large-dark-final: all three UI pass; all14 images inspected.
- large-light-permission-final: focused connection journey passes; all5 images
  inspected. Completes verification of picker correction in light mode.
- small-dark-final: all three UI pass; all14 images inspected.
- Device build passes after picker fix in agents/permission-device.log.
- Full native A4 suite active as listed above; A4 TestFlight pending.

Native alerts remain scrollable at largest type; test both Cancel and confirm.
Exercise evidence links currently explain unavailable; A5 will link to logged sets.

## Logic handoffs and reviews

Logic worktree /Users/aldo/Desktop/Exerly-Fitness-logic, last seen branchlogic/next
at7ba4f44e. It waits for A3 landing before M4/M5. App must not edit Core/API.
Integration /Users/aldo/Desktop/Exerly-Fitness is merge-only, never edit files.
App writes docs/handoff/to-logic.md in primary and logic worktree for timely review.

Reviewed migrated UUID issue; exactfix700cdc0d adopted into A3/A4. Reviewed
M4 weightMatch inert toggle: Logic explicitly reserves it now, omit from UI.
New medium plate finding: greedy80kg/bar20/25pair1+15pairs2 returns70 despite80
achievable; target10/bar20 reports zero shortfall. Reproduction in
artifacts/app-review-plates/result.log. Inbox asks best combination and clear
below-bar outcome including warm-ups. A4 remote4e696163 review requested.

Available contracts on logic/next, not yet integrated:

- b9736776 SQLiteTrainingPersistence.close(); deleteDatabase closes all instances
  for that path. Use close on switch/signout. Reads/writes after close throw.
- ecccb9fd AccountExport.merging(... pending: try SyncEngine.shared.pendingExportRows()).
  Overlays all legacy queue entries/deletions with pending_sync; remove exclusion
  copy. Adopt hosted attachment docs/handoff/attachments/LegacyExportTests.swift.
- 00d9992f entry detector stable identity per workout and accurate same-workout
  evidence, reject/undo wins. App A5 design009 uses this unchanged API.
- ProgramStore + ProgramSchedule nextWorkout/lifecycle/overrides, sync and agent
  host support. A6 design010, omit reserved weightMatch and await plate fix.
- NutritionStore domains, energy-balance/trend estimates. Targets/search/import
  still forthcoming from Logic; no nutrition UI started yet.

## User corrections and credentials

Ali rejected mint/green. Preserve original purple/pink, neutral dark, dark default,
existing purple E/pulse mark. Profile can select Light/System. Icon source
apps/ios/Brand/ExerlyMark.png; render-icon.swift sizes it. No brand redesign.

Old1633 could not sign in to incompatible DO API. Live1654 uses working staging
http://100.80.149.7:39110; phone must enable Tailscale. Synthetic login/bootstrap
passed, credentials already sent in chat and stored only in
~/private_keys/exerly-testflight-account.json mode600. Never print or commit them.
Physical replacement install/login not confirmed. Do not persist Mac password.

## Signing and infrastructure

Exerly ASC6819776832, en-US, SKUsideband-exerly-ios, bundlecom.exerly.fitness,
team9X79V37Q89, bundleresourceUJ5X8TJKNL. Record created website12:27 EDT.
Internal groupc5ae1d39-0fe4-4bee-af89-0374d9519afe Exerly Internal · Ali,
only Ali, no public link/autofuture. Existing dist certificate expires2027-09-25;
never create/revoke. ProfileJ5J395Y9AF HealthKit+SIWA. ASCkey4Z7KFJ8DWZ/issuer
under ~/private_keys. Never expose. Live1942 UUID17311f01-34dc-4a20-9171-7343ce4ccf39.
Production Neon/DO and Apple revocation credentials are existing Ali questions,
not a reason to stop UI work. External/App Review requires Ali after preparation.

Always DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer, including
push hooks. Origin sidebandstudio/Exerly-Fitness verified with gh15:48 EDT.
Commit as Ali Younes, no coauthor/tool attribution.

App sims only, never Logic sims:

- Original Large7189880A-91EC-4555-83E8-A37464802FE6,17ProMax26.2, main
  .deriveddata/app-account, fixture39203. Free after A3 full suite.
- SE7D2096B8-3E67-477F-82BF-0E2BEDF2CA2B,SE3/iOS18.6, app-next
  .deriveddata/a4-review, fixture39204. Current small-dark run.
- Accessibility Large02A671D3-2CEC-4F96-8E25-FFA8FEFB9F19,17ProMax26.2,
  app-next .deriveddata/a4-large, fixture39205. Free.
- Device derived data account-device or a4-device by worktree.

Use -parallel-testing-enabled NO, unique result bundle. TEST_RUNNER_EXERLY_TEST_APPEARANCE,
TEST_RUNNER_EXERLY_TEST_LARGEST_TYPE=1, TEST_RUNNER_EXERLY_UI_FIXTURE_URL and
EXERLY_FIXTURE_EXTERNAL=1. Existing fixture39203/4/5/6 sessions3247/7679/53930/93999,
current700cdc0d source, logs account/canonical-fixture-<port>.log. Environment
EXERLY_FIXTURE_PORT, not PORT. Verify PID/cwd before stopping a fixture and never
while tests use it. Protected devbox services untouched.

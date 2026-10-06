# App agent ledger (Astra)

Read AGENT_BRIEF.md, this ledger and to-app.md after every reset. Done is not
met. No parity row is fully device-verified. Continue without ending at a
milestone. Current date 2026-10-06, updated 18:44 EDT.

## Current work and next steps

2026-10-06 19:03 EDT. A6, agent/app-programs. Done is not met. Continue.
A5 is live as2610062144, only Ali/only build, VALID/IN_BETA_TESTING. Its final
123 hosted+25 UI passed,8 skips; Core233/API226/device pass. A5 landed/pushed,
then Logic landed778540cf. A6 rebased on that and was reviewed/approved by Logic.
Integration is held for A6 since18:41. A7 will adopt subsequent Core work.

The image audit found real truncation in the builder at largest text: name,
deload choice and crowded navigation title. Program/day names now wrap; deload,
icon, color and cycle selectors use wrapping Menu labels. Reorder moved into
the Days section and the navigation title is Program. Core math is unchanged.
The source-RIR note explicitly names the assumed target. Full-a6-final was
interrupted to include these changes, so it is NOT final release evidence.

Core259 tests/52 suites and API238 pass in final-core.log/final-api.log. Earlier
final-device passed before the wrapping fix. Lint/typecheck pass with warnings;
format check found only this ledger and it will be formatted before commit.
SwiftLint passed before wrapping; repeat device/SwiftLint for final source.

Current AX wrapping runs, all compiled on the latest product source:

- large-light-wrapping/session99623, LargeAX02A671D3/39207,a6-large:
  builder+cancel/lifecycle. Source wording already passed large-light-assumption.
- small-light-wrapping/session85894, SE7D2096/39206,a6-fields:
  source+builder+lifecycle.
- small-dark-wrapping/session78078, SE45D463AE/39209,a6-proposals:
  source+builder.
- large-dark-wrapping/session87661, Large7189880A/39208,a6-original:
  source+builder.
  Native full test will restart on SE39B20FBF/39211,a6-full, unique result bundle
  full-a6-wrapping. Do not use that simulator for A7 while it runs.

Completed earlier: small-light-final and large-dark-final each source/builder/
proposal pass; small-dark-final source/builder pass. Their captures exported.
Normal31 captures inspected. Large-dark-sheet lifecycle7 inspected. The detailed
image audit continues; artifacts/programs/visual-review.md records inspected
images and any remaining fixes. Never claim exported images as inspected.
Large-light-assumption4 captures inspected; copy wraps, new heading is first.
The next source captures also show the tail of the RIR assumption beside its
workout link. Additional UI capture does not change product source.

Once wrapping runs/images and final full native/device/quality gates pass,
create a fresh signed timestamp archive, upload, wait for VALID/IN_BETA_TESTING,
assign only Ali and detach2144 only after readiness. Update PARITY/RELEASE,
ff land/push and release Logic's integration hold. No A6 archive created yet.

A7 worktree Exerly-Fitness-app-nutrition, agent/app-nutrition,b83a896f rebased
onto A6e6ea5dd7. NutritionStore composition/design015 committed. Two regressions
red then green;12 account+nutrition hosted tests pass. Next food/amount drafts
and diary. Legacy diary retires per Logic, its sync queue/server/export remain.
Logic has published the volume snapshot fix, initial BodyProfile/formula plan,
and batch logging/copy/move/recipe suggestions, landing after A6. Do not edit
Core/API. A7 can build drafts with current NutritionStore.preview/per-label API.

Login reverified19:00: correct /login endpoint returns200 for the stored
synthetic TestFlight account. Credentials remain only in private_keys and were
sent to Ali in chat. Phone requires Tailscale and current2144. Original theme
and logo retained. No Mac password saved.

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

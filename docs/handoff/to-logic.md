# Inbox: logic agent (Claude)

Written by the app agent (Astra). Each item: date, title, what's needed or what changed, status
(open, in progress, done). Mark items done; never delete them.

## 2026-10-06: A1 baseline and training contract request

Status: done (logic): the training interface is published in to-app.md and the ExerlyCore README.

App is creating PARITY.md and an internal TestFlight pipeline before A2, the new
shell and training logger. Please publish ExerlyCore's training interface as soon
as it is usable, including offline store construction, exercise search/filter,
session lifecycle, set edits/completion, previous-set suggestions, history and
computed summaries. UI needs stable IDs and explicit save failures. Please include
the intended package deployment target and any Core target removals.

Reviewed integration through 89394c13. There are no separate logic commits yet.
App baseline uses its own Exerly App simulators and artifacts/app-baseline. I will
own apps/ios/scripts/release.sh and the related release/ASC tooling. Please keep
backend CI edits scoped to your area; existing native scripts use 39001 as agreed.

## 2026-10-06: Training contract review for the device logger

Status: done (logic, fixed in 55935632). Reviewed dd8909b0 and the published interface. SQLite commit
4d10d8dc is landing while A1 checks run; I will integrate it for A2.

- High, TrainingStore.swift:161 and SessionEditing.swift:127. updateSet accepts a
  completed set after clearing required reps/load, and updateActiveSession can
  replace all fields without validating the session. The header promises every
  change is validated. A correction can persist invalid completed work and then
  pollute history. Please validate completed sets and identity invariants at the
  store boundary, while allowing incomplete set drafts. Also reject empty effort
  arrays because primary indexes element zero. These are inspection findings;
  the app has not yet reproduced them through a screen.
- Medium, TrainingStore.swift:35 and :79. RestTimer is not restored in init or
  saved by startRest/extendRest/skipRest. Session data survives, but a rest timer
  disappears after termination. Please persist its deadline and rest policy in
  the new SQLite store, including explicit skip and account separation.
- Medium, TrainingHistory.swift:38. ExerciseStatistics discards
  Tonnage.isComplete. Unknown bodyweight then appears as a complete volume total.
  Please expose completeness in statistics/session summaries so UI can label it.
- Low, Exercise.swift:4. Muscle has 21 values versus the brief's 22 export groups.
  Please document the mapping or add the missing region when import fields are
  specified. PARITY A03 remains unverified.

For A2 please expose a session summary with completed working-set count, duration
at a supplied instant, total volume/completeness and muscle contributions. The UI
should not reduce sets into domain totals itself. Volume also needs a display
conversion API for kilogram-reps versus pound-reps. Pause/resume timing can follow.

App release progress: com.exerly.fitness registered with HealthKit, existing
distribution certificate reused, signed archive/IPA 1.0 (2610061518) succeeded.
App Store record creation awaits normal desktop unlock/browser access. Full
native baseline uncovered iOS 26's delayed password-save sheet; helper fix is
under regression. API 153 and native unit 68 passed. PARITY.md now has the sourced
inventory; no row is marked device-verified.

## 2026-10-06: A2 linkage and PostgreSQL fixture

Status: in progress.

Rebased app onto 5278f84b. Reviewed the PostgreSQL adapter, migration runner,
cluster helper and container setup; no new correctness finding from that review.
The simulator fixture now uses your disposable PostgreSQL cluster, including
shutdown cleanup. Native regressions are next; wait for the app's green run before
removing SQLite. New API coverage will therefore exercise the real adapter.

ExerlyCore is linked to the app and tests. A2 opens a separate SQLite file per
authenticated account (hashed path); four app composition/input tests pass,
including restart recovery and a second account seeing no first-account workout.
The new logger uses TrainingStore for mutations. Legacy ProgramView still uses
the old exercise library, so do not delete it yet.

A1 full UI baseline found an existing onboarding target-weight input issue:
entering 78 left 8. The app fix retains raw text during editing; regression is
pending. The earlier activity/sleep, body-measurement, diary, preferences and
reminder UI tests passed. devbox1 is unlocked; ASC still needs Apple login.

## 2026-10-06: Core rest fix pulled; auth UI needs client methods

Status: done (logic): atomic rest writes in a4eeba40; account methods in the session bridge.

Pulled 55935632 and 51f67e57. Thank you for the validation, summary and persistent
rest changes. A2 now handles the throwing rest operations and displays Core's
summary. The training/relaunch/prefill UI test and fixed onboarding test passed
on the small simulator against PostgreSQL before this pull; full suite follows.

Medium, TrainingStore.swift:91 and :137. Completing or finishing commits the
session before saving/clearing rest state. If saveValue fails, the method throws
after publishing a completed set or removing activeSession. That breaks the
documented failed-change invariant and makes save errors misleading. Please make
the session and rest change atomic through persistence, or provide an explicit
partial-success result; cover injected failure on the second write. Discard has
the same issue. Inspection finding, not reproduced in UI.

For A3 please publish native client/auth methods for Apple sign-in, linking,
unlinking, account deletion (including apple_reauthorization_required), and
full export. AuthViewModel/APIClient are still yours under Core; the app must not
call the network directly. The UI will own AuthenticationServices, nonce creation,
credential prompts, confirmation and share-sheet presentation. Publish how to
apply the returned session and clear local stores after deletion. I will add the
Apple capability/profile before the A3 build. No legacy Core files removed.

## 2026-10-06: A2 regression green; ASC created; review response

Status: in progress (logic): web CI removed; the SQLite adapter goes next.

The full native run against PostgreSQL passed: 72 hosted unit tests and 14 UI
journeys (7 cross-client cases remain opt-in), full-native.xcresult. You may
remove the SQLite API fixture adapter. Largest-text light/dark training checks
are finishing on both small and large simulators. App is rebasing on a4eeba40
next, with a fresh full suite before integration.

Your account-path finding is fixed: production TrainingWorkspace now uses
SQLiteTrainingPersistence.defaultURL(accountID:). Only isolated test roots are
custom. Tests reject unsafe account IDs and check the canonical production URL.
No released training data needs migration; prior files contain synthetic tests.

Please remove the web CI job as the brief and decision specify. Keep the web
sources and optional cross-client script for now; required CI should exercise
native and API behavior. No permission from Ali is needed for that agreed scope.

Exerly's ASC record is created: app ID 6819776832, com.exerly.fitness, English US,
SKU sideband-exerly-ios. A2 signing/export succeeded after limiting the manual
profile override to the app target (SPM resource bundles cannot take profiles).
Internal-only upload follows the final rebased build. A3 will use your API,
credential and sync contracts, including a hosted Keychain round trip.

## 2026-10-06: A3 needs one session owner; Core account review

Status: done (logic): see to-app.md, "Shared session bridge (A3), your review fixes, and MCP". Reviewed a4eeba40 and the account/sync interface.

The app still uses your Core/Auth/AuthViewModel and Core/Network/APIClient for
bootstrap, onboarding, diary and sign-out. A second ExerlyAPI with a separate
KeychainCredentialStore would sign training into a different session and leave
those screens unauthenticated after Apple sign-in. Sharing rotated tokens between
two refresh implementations would race. Please publish one bridge before A3:

- AuthViewModel.signInWithApple(identityToken:rawNonce:name:) accepting the native
  credential and driving the same bootstrap/onboarding/offline state as login.
- One DocumentAPI for the current authenticated account, using the same session
  owner as legacy APIClient. It must reject account changes during in-flight work.
- Account link/unlink, export and deletion methods through that same owner, and
  a UI-safe way to clear its current user/cache/queued legacy data after deletion.
- Linked-Apple/password availability in account state so Settings presents the
  correct actions. Keep networking/calculations in your ownership. Native Apple
  authorization, confirmation, file sharing and sync status are app work.

Review findings (inspection; not yet reproduced on device):

- High, ExerlyAPI.swift refresh/signOut/startSession: actor suspension has no
  session-generation check. An in-flight refresh can save credentials after
  sign-out or replace a newer sign-in. Please invalidate/cancel older work and
  verify the account/session before saving or returning credentials.
- High, SyncEngine.swift sync/run: its unstructured Task retains the engine and
  store after the UI drops them. Cancellation of the caller does not stop it.
  During account deletion, a pending pull could write old data again; during an
  account switch, reuse of one API could send the old store with the new token.
  Please expose cancellation/quiescence for account lifecycle and bind requests
  to an expected account. Add delayed-transport switch/delete tests.
- Medium, Credentials.swift private write: SecItemDelete precedes SecItemAdd.
  Failed replacement loses the previous credential or pending refresh key.
  Please use update-or-add semantics preserving an existing item on failure.

Rebased A2 at 4e2b66c2: API 182, Core 129 and device build pass. Full native
regression is running (~24 minutes, started 12:33 EDT). If possible, keep the
integration head stable until it lands; continue your next changes on logic.

## 2026-10-06: TestFlight correction and hosted Keychain verified

Status: done (logic): noted. Staging is redeployed after every API change.

2610061633 reached internal TestFlight, but Ali reported login failure. Confirmed
old DO production returns no refresh token and no usable /api/bootstrap. The app
release now explicitly targets your devbox1 staging by default; public HTTPS
remains separate validation. Native AuthViewModel login/bootstrap against staging
passed with a synthetic TestFlight account, without changing your auth code.
AccountInfrastructureTests also verifies ExerlyCore Keychain save/load/replace,
service isolation, AfterFirstUnlockThisDeviceOnly and removal. Both hosted tests
passed on app's iOS 26.2 simulator. Replacement build 2610061654 is now VALID and
IN_BETA_TESTING, assigned only to Ali. The incompatible build was detached.

Ali rejected the green palette/mint icon. Restore the original purple/pink dark
brand and purple E/pulse symbol. Dark is default again; accessibility work stays.

## 2026-10-06: Proposal review found two reproducible data bugs

Status: done (logic): same to-app.md entry. Reviewed ce3aa2ce and db6fbecd on integration 3cba5eae.

- High, AgentStore.swift:71 and :206. A proposal received through DocumentHost
  prepareWrite bypasses check, and accept never validates its after documents.
  Reproduced using only public APIs: sync in a proposal whose before is the
  current finished workout and whose after has -8 completed reps. accept returns
  success and persists -8. Local file rejects this, so the remote path is weaker.
  Validate incoming proposal shape/IDs and all changes at decision time, including
  undo targets. Reject unsupported or duplicate targets without partial writes.
- High, TrainingStore.swift:264. stageExercise captures a replacement library
  before the transaction publishes. Accepting a proposal that creates two custom
  exercises saves both to persistence, then the second publish overwrites the
  first in memory. Reproduced: first in memory=false, after reload=true, second
  in memory=true. Stage the combined library or publish without losing earlier
  writes. Please cover create/create, edit/edit, undo and failures atomically.
- Medium, apps/api/lib/documents.js:12. Proposal validation permits missing
  createdAt, summary, evidence and confidence, malformed changes and non-UUID
  proposal IDs. ExerlyCore cannot decode these. One validly authorized agent's
  malformed proposal can stop a device's entire change-feed page repeatedly.
  Please finish the shared schema validation before agents file device proposals,
  and expose a recoverable invalid-document state rather than labeling decode
  failures as offline. This finding is from inspection; the first two are run.

Reproducer is a separate scratch package, so no ownership boundary was crossed:
artifacts/app-review/Sources/Review/main.swift and result.log in the app worktree.
Run: DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer swift run
--package-path artifacts/app-review. It uses in-memory synthetic records only.

The final A2 rebase is on 3cba5eae. API192/Core147/device build pass. Full native
retry is running after an app simulator SpringBoard refused launches; a reboot
of that simulator restored launch. No macOS services changed. A3's shared-session
bridge request above remains needed; I am preparing its native authorization UI.

## 2026-10-06: A2 final integration checks pass; A3 UI is prepared

Status: done (logic): deletion recovery and the merged export landed in 90b62488 and 67c8db44.

Final A2 on 3cba5eae passed API192, Core147, device build, 77 hosted tests and
14 native UI journeys with 7 opt-in cross-client skips. Core Keychain and live
staging AuthViewModel sign-in are included. Lint/format/typecheck also pass,
with existing lint warnings. App is landing the A2 commits now.

While the 24-minute regression ran, I prepared A3 in a separate app-owned
worktree, ~/Desktop/Exerly-Fitness-app-next, branch agent/app-next. Native Apple
authorization, Account settings, export sharing and deletion confirmation compile
against injected actions. The real UI is deliberately unconnected pending your
single-session bridge. Three hosted presentation tests and two normal-size UI
journeys pass using synthetic actions; largest-text checks found a system
confirmation-popover issue, now being corrected with an explicit alert/cancel.

Exerly's APPLE_ID_AUTH capability is enabled as a primary app. A new Exerly-only
profile J5J395Y9AF includes HealthKit and Sign in with Apple; the existing
certificate is unchanged. Signed archive/IPA 2610061727 passed, not uploaded.
The current test build remains 2610061654 with its working synthetic login.

Please include Apple/password method availability and account-bound refresh,
link/unlink, export and delete actions in the bridge. Deletion needs quiescence
and local cleanup, including lost-acknowledgement recovery. Export must include
pending local workouts eventually; current UI truthfully labels server-only
export as excluding unsynced workouts. Proposal review findings above still need
fixing before agent decisions reach the phone.

## 2026-10-06: Adopting the bridge; deletion recovery and dependency follow-up

Status: done (logic): deletion recovery in 90b62488; shell-quote is 1.12.0 through an override in 61e175ad. App is on7038d86e over your3685dbf2. The A3 presentation commit
contains native Apple authorization and accessible account controls. All four
largest-text small/large light/dark variants pass with screenshots inspected.
I am connecting your session bridge now and adopting SessionBridgeTests.

Please cover lost deletion acknowledgements before public readiness: currently
DELETE /api/account can commit, then lose its response; retry sees an expired
session, leaving local training files because the UI only cleans on .deleted.
Publish a confirmed-deletion recovery result or equivalent safe mechanism. Do
not infer deletion from an arbitrary401 (revoked sessions must keep offline data).
I will persist and retry local cleanup after a confirmed server deletion.

Dependency review: your new lock has proxy-addr2.0.8 and source-map-js1.2.2, which
address alerts58/59. It now has shell-quote1.9.0; alert60 reports affected

`>=1.8.4,<1.11.0`, fixed1.11.0. Please verify and update in your dependency scope:
https://github.com/sidebandstudio/Exerly-Fitness/security/dependabot/60.

## 2026-10-06: A3 connected; UUID case creates duplicate server workouts

Status: done (logic): 4f026b47, with the payload follow-up in 700cdc0d. App is rebased on7a97ae34. Account actions, training sync and
deletion recovery are connected. Your15 hosted bridge tests plus six workspace
tests pass. Actual UI tests confirm a lost deletion acknowledgement, offline
training/relaunch/reconnect, exports and account switching. Largest-text screens
are being inspected; the full native regression is next. A3 upload follows.

High, identity/data: Core documentIDs uses UUID.uuidString (uppercase), while the
API accepts lowercase UUID document IDs. Reproduced against a real isolated
PostgreSQL fixture39206 through public Core APIs: write one lowercase workout,
then open an empty TrainingStore and sync. Sync reports success but the server
now has two document rows for the same UUID, one lowercase and one uppercase.
An export duplicates that workout; later edits/deletions can address different
rows. Please canonicalize UUID-based IDs consistently at the API and Core
boundaries, including references and sync bases, and test lower/mixed case.

Exact output: Seed result applied(revision:1); Sync succeeded; Stored rows
9D315F3D-CF88-4C46-A2FA-AD36ADBDB055 and
9d315f3d-cf88-4c46-a2fa-ad36adbdb055; Distinct UUID values:1.
Reproducer: app worktree artifacts/app-review-case/Sources/Review/main.swift,
result.log. Synthetic account was deleted afterward. No Core/API files edited.
Relevant: DocumentHost.swift:67, SyncEngine.swift:key, documents.js:readID and
readPayload. Token session validation also accepts both cases today.

The shared export now overlays unsynced training through AccountExport.merging.
I expose a separate offline training export. UI discloses that pending legacy
food/other queued entries remain excluded; a complete account export still needs
that queue merged by Core. Please publish that when available. Also SQLite
deleteDatabase says to close every persistence first but offers no explicit
close; composition shuts down/drops owners, though SwiftUI can retain old views.
An explicit close/delete lifecycle would make this guarantee enforceable.

Please keep integration stable for about25minutes after the UUID fix so the app
can finish the required full regression and land A3. Continue other work on logic.
Next app milestone is proposal review/audit plus Connect an agent using the
published token contract, then built-in training suggestions.

## 2026-10-06: UUID migration review: existing payload references remain lowercase

Status: done (logic): 700cdc0d; see to-app.md. Review of 4f026b47, high for MCP and existing proposals.

Migration 0005 uppercases documents.document_id and sync_changes.entity_id but
leaves documents.payload.id and embedded proposal/evidence/audit references
unchanged. agentTools.workspace returns those raw payloads, while getDocument
now compares payload.id against canonicalID(request.id). A migrated lowercase
workout is therefore unfindable through get_document with either case.

Reproduced using the exported getDocument with a workspace containing the
post-migration payload {id: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"}; both lower
and upper request IDs throw "No workout_session has that ID". Evidence lives in
the app worktree at artifacts/app-review-case/migrated-mcp.log. The migration
test inserts exactly this shape but asserts only document_id/entity_id.

Please canonicalize stored payload identities and references too, including
historical change-feed payloads. An existing proposal's change.id remains a
String in Core, so verify an old lower-case proposal can still be accepted and
undone after migration. Also check the MCP propose path with lower-case IDs
and payload.id, which currently passes canonical change IDs to trainingProblems
without first normalizing after. Add a migrated-data MCP/phone regression.

## 2026-10-06: Before A5 entry checks, clarify same-workout evidence and deduplicate across devices

Status: done (logic): 6b7669fa; see to-app.md. Medium; for A5, not an A3/A4 release blocker.

EntryErrorDetector.proposal can work from two sibling sets with no earlier
sessions, but its evidence claims "Your working sets of Deadlift in your last
0 sessions were 55–135 kg." Reproduced with a finished first workout containing
100 kg, 100 kg and 1000 kg sets of five reps. The reference here is two sets in
the same workout, not earlier sessions. Please describe that basis accurately.
Artifact: app worktree artifacts/app-review-detector/result.log and its scratch
Swift executable. No Core source modified.

Also, identical inputs and no existing proposals produce a new random proposal
ID each time. Two devices can both finish pulling before either files the same
built-in check, leaving duplicate suggestions after sync. Please provide stable
identity or another Core-owned deduplication rule before I automatically file
entry checks on finish and after sync. Test concurrent devices and preserve a
rejected/undone check's suppression. Published interface can stay unchanged.

A3's final full native run began 15:06 EDT on0354e510 over66b3dd1e, with a signed
2610061907 archive prepared. If the migrated-payload follow-up changes Core,
I will rebase and rerun the final suite; A3 source otherwise stays frozen apart
from a just-found largest-text Start workout label wrap. A4 review tests are
running in app-next on the other two app simulators.

## 2026-10-06: App is adopting 700cdc0d into A3 before the final suite

Status: done (logic): noted; integration stayed at 66b3dd1e until A3 landed. I can see the migrated-payload fix on logic/uuid2 while
you continue M4/M5 on logic/next. I am adopting that exact committed fix into
agent/app, then rebasing onto integration and running the full app/API/Core
checks before the A3 fast-forward. This keeps the fix in the account build
without landing M4/M5. Please leave integration at66b3dd1e until A3 lands so
we can finish one frozen full native run. No Core/API source edited by app.

## 2026-10-06: M4 review: the weight-match setting currently has no effect

Status: done (logic): reserved in 779ab7ee; leave it out of the builder. Medium, for the program UI milestone rather than A3/A4.

Program.swift:49 publishes weightMatch as "Keep later sets at the first set's
load", and the handoff includes it among the builder controls. ProgramSchedule.plan
at line243 passes expandRepRange but never reads weightMatch. Progression.swift:89
always repeats one PlannedSet for the entire slot. Searching Core finds no other
consumer of weightMatch. Turning it off therefore cannot change the plan.

Please implement and test the distinction before publishing that control as
working, or clarify that it is reserved and should be omitted from the first
builder. I will not add an inert weight-match toggle. No Core/API source edited.

A3 final native validation is still running on700cdc0d plus the app fixes.
API219, Core183 and the device build pass. The final archive will use a fresh
build number; prepared2610061907 is obsolete. Integration remains66b3dd1e.

## 2026-10-06: M4 calculator review: reachable loads and targets below the bar

Status: done (logic): see to-app.md, "The plate calculator finds the best reachable load". Medium, before adding plate and warm-up UI.

Plates.swift:32-53 promises the heaviest load at or under target but uses greedy
selection. With target80 kg, bar20 kg, one pair25 kg and two pairs15 kg, it
returns70 kg using the25 kg pair, shortBy10 kg. The available two15 kg plates
per side reach80 kg exactly. This matters for limited inventory and mixed units.
Please select an achievable best combination, with a documented tie-break.

Plates.swift:35-36 also returns total20 kg and shortBy0 for target10 kg with a
20 kg bar. A zero shortfall cannot represent this as an exact achievable target.
Please expose a clear below-bar result or validation error, retaining enough
information for the UI to explain that a lighter bar is needed.

Both are reproduced against the actual current logic Core package by the
app-owned scratch executable at artifacts/app-review-plates, with result.log
in the app worktree. No Core source changed. The same load routine is used by
WarmUpScheme, so cover the corrected combination behavior there as well.

A4 is available for your review on remote agent/app-next, currently4e696163.
Eight hosted agent tests and all three large-phone light journeys pass. Normal
SE journeys pass. Largest-type SE review hit a test-only upward gesture that
started in the account banner; corrected in4d89933a, rerun active. The permission
picker label also wraps now. Files are Features/Agents, TrainingPresentation,
TrainingView, ProfileView and tests. A3 remains frozen while its full suite runs.

## 2026-10-06: A3 is green and fast-forwarded; M4/M5 can land

Status: done. Integration is now02277a81, including your unchanged700cdc0d.
The final app run passed100 hosted tests and19 UI journeys, eight opt-in skips,
zero failures. API219, Core183 and the iOS device build pass. Internal signed
build2610061942 is VALID and IN_BETA_TESTING, assigned only to Ali. The first
push stopped on documentation formatting; corrected before retry.

You can rebase and land M4/M5 now. I will adopt legacy pending-export rows,
close-on-account-change and LegacyExportTests in A4, then run a frozen full
regression. Please review remote agent/app-next4e696163. Three large dark and
small light review journeys pass; all final captures inspected so far. Final
small dark is running. A5/A6 design notes are committed on app-next.

## 2026-10-06: A4 adopts the published close and pending-export contracts

Status: in progress. A3 is now pushed at507ee527, with build2610061942 live
in the Ali-only internal group. A4 rebased onto it and adopted your exact
b9736776/ecccb9fd commits unchanged to wire the public contracts while you
finish M4/M5. Hosted app regressions now check retained-screen writes after
sign-out/switch and queued rows through both account export actions. The
LegacyExportTests attachment is registered in the app test target. I will
rebase onto your integration landing before final A4 checks.

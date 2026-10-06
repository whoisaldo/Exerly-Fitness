# ExerlyCore

Exerly's domain logic as a local Swift package with no UI and no dependencies:
models, calculations, persistence, and later sync and the agent model. The app
target links it and uses only its public API. Screens never do domain maths or
call the network themselves.

Owner: the logic agent. Design notes: `docs/design/002-exerlycore-training.md`.

## Use

```swift
import ExerlyCore

let store = try TrainingStore(persistence: InMemoryTrainingPersistence())
try store.startSession(name: "Upper", bodyweight: .kg(80))
let bench = try store.addExercise("barbell-bench-press")   // prefilled from last time
let setID = store.activeSession!.exercises[0].sets[0].id
var set = store.activeSession!.set(setID)!.set
set.primary = Effort(reps: 5, load: .kg(100))
set.rir = 2
try store.updateSet(set, in: bench, propagate: true)
try store.completeSet(setID)                                // starts store.restTimer
let summary = try store.finishSession()                     // summary.records: PRs
```

Test with `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer` set.

- `swift test` in this directory.
- `scripts/live-sync.sh` runs the client and sync engine against the real API on
  a throwaway PostgreSQL database, on port 39102.
- The Keychain store needs a host app, so its test runs only when
  `EXERLY_KEYCHAIN_TESTS` is set.

## Public interface

Units are explicit. `Mass` keeps the value and unit entered; loads in
statistics are `Mass` in kilograms, so convert with `value(in:)` for display.
Volume is in kilogram-reps, durations in seconds, distances in metres.

### Units

| Type | Purpose |
| --- | --- |
| `Mass`, `MassUnit` | `Mass(225, .pounds)`, `.kg(100)`, `.lb(45)`; `kilograms`, `value(in:)`, `converted(to:)`; compares by physical amount. `Mass(validating:_:)` rejects negative or non-finite input. |
| `LocalDate`, `Weekday` | A `YYYY-MM-DD` calendar date. `LocalDate("2026-10-06")`, `LocalDate(instant, in: zone)`, `adding(days:)`, `days(until:)`, `weekday`, `startOfWeek(firstWeekday:)`. Encodes as a string. |

### Exercise library

| Type | Purpose |
| --- | --- |
| `ExerciseLibrary` | `.bundled` (119 exercises), `exercise(_:)`, `search(_:muscle:available:)`, `adding(_:)` for custom exercises. Search ignores case, accents and punctuation, and expands db, bb, kb and bw. |
| `Exercise` | `id`, `name`, `aliases`, `category` (strength or cardio), `metric`, `laterality`, `mechanics`, `region`, `muscles` (share per muscle: 1 target, 0.5 synergist), `actions`, `equipment`, `support`, `bodyweightShare`, `targetMuscles`, `synergistMuscles`, `validationErrors`. |
| `ExerciseID` | Stable string ID, such as `"barbell-bench-press"`. `ExerciseID.custom()` makes `custom-<uuid>`. |
| `Muscle` | 21 regions, each with a display `name`. |
| `JointAction`, `Equipment` | Joint actions; resistance, support and cardio equipment. |
| `TrackingMetric` | `weightReps`, `bodyweightReps`, `assistedReps`, `duration`, `weightDuration`, `distanceDuration`, `weightDistance`. `tracksReps`, `tracksLoad`, `requiresLoad`, `tracksDuration` and `tracksDistance` say which fields to show. |
| `Laterality`, `Mechanics`, `BodyRegion`, `ExerciseCategory` | Classification used for set credit and rest. |

### Sessions

| Type | Purpose |
| --- | --- |
| `WorkoutSession` | `id`, `name`, `startedAt`, `endedAt`, `timeZoneID`, `notes`, `bodyweight`, `exercises`; `localDate` (from its own zone), `isFinished`, `duration`. |
| `PerformedExercise` | `exerciseID`, ordered `sets`, `notes`, `supersetID`, `restOverride`. |
| `PerformedSet` | `kind`, `side`, `efforts`, `rir` (0 to 6, where 6 means 6+), `completedAt`; `primary` (the first effort), `isCompleted`, `counts` (completed and not a warm-up), `isLoggable(for:)`, `PerformedSet.rir(fromRPE:)`. |
| `Effort` | `reps`, `load`, `duration`, `distance`. A drop or myo set has one effort per continuation. For bodyweight exercises `load` is added weight; for assisted ones it is the assistance. |
| `SetKind` | `warmUp`, `standard`, `drop`, `myo`, `failure`. |
| `Side` | `left`, `right`, for unilateral exercises logged one side at a time. |

Editing functions on `WorkoutSession` (the store wraps all of them):
`addExercise`, `removeExercise`, `moveExercise`, `addSet`, `updateSet(_:in:propagate:)`,
`completeSet`, `reopenSet`, `removeSet`, `makeSuperset`, `removeFromSuperset`,
`set(_:)`, `performanceOrder`, `nextSet(after:)` and `finish(at:discardIncompleteSets:)`.
Failures throw `WorkoutSession.EditError`.

`validate(library:)` throws the first problem that makes a session
untrustworthy:

- duplicate exercise or set IDs, or an unknown exercise or time zone;
- an end before the start;
- a set that isn't sane: no efforts, negative or non-finite numbers, RIR outside
  0 to 6, or continuations on a set kind that has none;
- a completed set missing a field its metric needs.

Incomplete sets are drafts and may leave fields empty. `PerformedSet.isSane` and
`isLoggable(for:)` expose the two levels.

- `propagate: true` copies each changed field down to later incomplete sets that
  held the old value, and stops at the first one that differs.
- `nextSet(after:)` walks straight sets exercise by exercise and superset members round by
  round, then wraps back to sets skipped earlier.
- A new set copies the previous one. Unilateral exercises alternate sides and copy the
  last set on that side.

### Calculations

| Function | Result |
| --- | --- |
| `OneRepMax.estimate(load:reps:rir:)`, `estimate(_ mass:reps:rir:)` | e1RM from reps to failure (reps + RIR): Brzycki up to 10, Epley above; nil past 20. |
| `OneRepMax.load(forReps:oneRepMax:)` | The inverse, for n-RM estimates. |
| `OneRepMax.confidence(repsToFailure:)` | `high` up to 5, `moderate` up to 10, `low` above. |
| `Volume.effectiveLoad(_:exercise:bodyweight:)` | Kilograms per rep, including the bodyweight share; nil if unknown. |
| `Volume.tonnage(_:exercise:bodyweight:)` | `Tonnage` with `resistance`, `bodyweight`, `total` and `isComplete` (false when bodyweight was missing). |
| `Volume.setCredit(_:exercise:)` | 0 for warm-ups, incomplete sets and cardio; 0.5 for one side of a unilateral exercise; otherwise 1. |
| `Volume.byMuscle(_:library:)`, `Volume.weeklyByMuscle(_:library:firstWeekday:)` | `[Muscle: MuscleVolume]` (fractional `sets`, `tonnage`), and the same per week keyed by the week's first `LocalDate`. |

### History

`TrainingHistory(sessions:library:)` sorts sessions and indexes sets by exercise.

- `lastPerformance(of:before:excluding:)`
- `sets(of:from:through:)`, which returns `[SetRecord]`
- `statistics(of:from:through:)`, which returns `ExerciseStatistics`. It has every
  metric in MacroFactor's exercise export: estimated 1-, 3- and 10-RM, total and
  best-set volume, heaviest load, total and best-set reps, total and best-set
  duration and distance, and total sets.
- `oneRepMaxTrend(of:)`
- `records(in:)`, which returns `[PersonalRecord]` (e1RM, heaviest load, set
  volume, reps at a load, duration, distance), compared with earlier sessions.
- `weeklyMuscleVolume(firstWeekday:)` and `muscleVolume(from:through:)`

`ExerciseStatistics.isVolumeComplete` is false when a bodyweight exercise was logged
without a known bodyweight.

`WorkoutSummary(session:library:at:)` totals one session:

- `exerciseCount`, `totalSets`, `completedSets` and `workingSets` (completed,
  not warm-ups);
- `duration`, measured to `at` while the session is in progress;
- `tonnage`, with its completeness;
- `muscles`.

`Tonnage.total(in:)`, `resistance(in:)` and `bodyweight(in:)` give kilogram-reps or
pound-reps for display.

### Rest

| Type | Purpose |
| --- | --- |
| `RestPolicy` | `compoundUpper` 150 s, `compoundLower` 180 s (also full body), `isolation` 90 s, `warmUp` 60 s, `betweenSides` 15 s, `betweenExercises` 120 s. `rest(after:in:library:)` picks one from what comes next; a set within a superset round gets 0. |
| `RestTimer` | `startedAt`, `duration`, `endsAt`, `remaining(at:)`, `isFinished(at:)`, `extend(by:)`. Time left comes from a clock, so it survives backgrounding and suits a Live Activity. |

### Store

`TrainingStore` is `@MainActor @Observable`. Bind screens to `library`, `history`,
`activeSession`, `restTimer` and `restPolicy`.

Every change is applied to a copy and validated with `validate(library:)`.
A change that writes more than one thing is one unit
(`TrainingPersistence.performAtomically`): completing a set saves the set and
its rest timer, and finishing or discarding saves the session and clears the
timer. A
whole-session edit may not change the ID. The copy is saved first and published
only after that, so a failed change leaves memory and disk as they were. The rest
timer and rest policy are saved too, and come back after relaunch.

- `startSession(name:bodyweight:timeZone:)`
- `addExercise(_:at:)`, which prefills from history
- `addSet(to:kind:)`
- `updateSet(_:in:propagate:)`
- `completeSet(_:)`, which starts the rest timer
- `reopenSet`, `removeSet`, `removeExercise`, `moveExercise`, `makeSuperset`,
  `removeFromSuperset`
- `updateActiveSession { $0.notes = ... }`
- `previousSets(for:)`, the "previous" column
- `summary(of:)`, which returns a `WorkoutSummary` measured to now
- `finishSession(discardIncompleteSets:)`, which returns a `FinishedSession` with
  `session` and `records`
- `discardSession()`
- `startRest(seconds:)`, `extendRest(by:)`, `skipRest()` and `setRestPolicy(_:)`,
  all of which save and can throw
- `saveSession(_:)` and `deleteSession(_:)` for finished sessions
- `addCustomExercise(_:)`

Errors are `TrainingStore.StoreError`. An unfinished session is restored at
launch.

`TrainingPersistence` is the storage protocol.

- `SQLiteTrainingPersistence(url:)` is the on-device store. Use
  `SQLiteTrainingPersistence.defaultURL(accountID:)`, which is
  `Application Support/Exerly/<accountID>/exerly.sqlite`. Each account has its
  own file.
  - Each session is one JSON document, written atomically in WAL mode with full
    sync.
  - The schema version is in `user_version`. A file from a newer version is refused,
    never downgraded.
  - Rows it cannot decode are listed in `unreadableRows` and left untouched.
  - `loadValue(forKey:)` and `saveValue(_:forKey:)` hold small values, such as the
    rest timer and settings.
  - `performAtomically` runs on one transaction; a nested call uses a savepoint.
- `InMemoryTrainingPersistence` is for previews and tests.

## Accounts and sync

One object owns the session: it signs in, refreshes and stores credentials. In
the Exerly app that is the legacy `APIClient`, which implements
`SessionTransport`; `AuthViewModel` hands out an `AccountAPI` bound to the
signed-in account. `ExerlyAPI` is a standalone owner for tests, scripts and
future targets. Never run two owners against one session: rotating refresh
tokens would race.

Wiring, with `ExerlyAPI` as the owner:

```swift
let api = ExerlyAPI(baseURL: apiURL, credentials: KeychainCredentialStore())

// Sign in with Apple: give Apple nonce.sha256, send nonce.raw to Exerly.
let nonce = AppleSignInNonce()
request.nonce = nonce.sha256
// ... after ASAuthorization succeeds:
let result = try await api.signInWithApple(identityToken: token, rawNonce: nonce.raw,
                                           name: fullName, timeZone: .current, unitSystem: nil)

let account = try await api.account()   // bound to result.account.id
let persistence = try SQLiteTrainingPersistence(url: .defaultURL(accountID: account.accountID))
let store = try TrainingStore(persistence: persistence)
let sync = SyncEngine(store: store, state: persistence, api: account)
try await sync.sync()   // at launch, on foreground, after finishing a session, and every few minutes

// Signing out, switching or deleting the account:
await sync.shutdown()   // returns once nothing more will be written or sent
try await api.signOut()
```

### SessionTransport and AccountAPI

- `SessionTransport.send(_:path:body:headers:as:)` sends one request as an
  account, refreshing once after a 401. It throws `accountChanged` when the
  session belongs to someone else, or is replaced or removed while the request
  is in flight.
- `AccountAPI(accountID:transport:)` is one account's endpoints:
  - the document endpoints `SyncEngine` uses (it is a `DocumentAPI`);
  - `connectApple(identityToken:rawNonce:)` and `disconnectApple()`;
  - `exportAccount()`, which returns the JSON `Data`;
  - `deleteAccount(appleAuthorizationCode:)`, which deletes on the server. The
    session owner then forgets the session.

### ExerlyAPI

An actor, and a `SessionTransport`.

- `signInWithApple(identityToken:rawNonce:name:timeZone:unitSystem:)` and
  `signIn(email:password:)` return a `SignInResult` with `created` and
  `account` (`id`, `email`, `name`).
- `account()` returns the signed-in account's `AccountAPI`.
- `signOut()` forgets the session at once, then revokes it on the server when
  reachable. `deleteAccount(appleAuthorizationCode:)` deletes, then forgets.
- `isSignedIn` and `accountID`.

It refreshes the 15-minute access token before it expires and once after a 401. A
refresh's idempotency key stays in the credential store until the rotated
credential is saved. Each sign-in or sign-out starts a new session generation:
a refresh or request begun under an older one never saves credentials or
returns its response.

Errors are `APIError`, with user-facing descriptions (`LocalizedError`):

- `sessionExpired`: sign in again.
- `linkRequired`: a password account owns that email.
- `linkConflict`: the Apple ID is connected to another account.
- `appleReauthorizationRequired`: deletion needs a fresh Apple authorization code.
- `accountChanged`: the account changed during the request; nothing was applied.
- `server(status:message:)`, `notSignedIn` and `invalidResponse`.

### Credentials

- `KeychainCredentialStore` keeps the session in the Keychain, readable after first
  unlock and never migrated to another device. It updates in place, so a failed
  write keeps the previous credential.
- `InMemoryCredentialStore` is for previews and tests.

### SyncEngine

`@MainActor @Observable`.

- `sync()` pulls, pushes, then pulls again. Overlapping calls share one run;
  cancelling the call that started it cancels the run.
- `shutdown()` stops it for good and returns once the current run has stopped.
  After that it writes nothing locally and sends nothing. Call it before signing
  out, switching or deleting the account.
- `state` is `idle`, `syncing`, `offline` or `failed(message)`, and
  `lastSyncedAt` records the last success.
- `SQLiteTrainingPersistence` and `InMemoryTrainingPersistence` both provide the
  `SyncStateStore` the engine needs.

How it decides what to send:

- A document needs pushing when its canonical JSON differs from the last version
  the server acknowledged. A crash between saving and syncing therefore loses
  nothing.
- Conflicts merge three ways with `Merge`: whichever side changed a field wins,
  local wins when both did, and items merge by ID. Nothing logged on either side
  is lost.
- Sessions and custom exercises sync today.

### Wire format and storage

- `ExerlyJSON.encoder` and `ExerlyJSON.decoder` use sorted keys and ISO 8601 dates
  with milliseconds. The store creates dates at whole milliseconds
  (`Date.roundedToMilliseconds`), so they round-trip exactly.
- `SQLiteTrainingPersistence.deleteDatabase(accountID:)` removes an account's
  local data after it is deleted.

## Agents: proposals and the audit log

Agents propose and people decide. See `docs/design/004-agent-core.md`.

```swift
let agent = try AgentStore(persistence: persistence, hosts: [store])
let sync = SyncEngine(hosts: [store, agent], state: persistence, api: api)   // proposals sync too

try agent.file(proposal)      // validated; changes nothing; audited
agent.diff(proposal.id)       // [DocumentDiff]: field paths with before and after
try agent.accept(proposal.id) // all changes or none; throws .stale if the data moved on
try agent.undo(proposal.id)   // restores exactly, or throws .stale
try agent.reject(proposal.id)
```

### AgentStore

`@MainActor @Observable`.

- `proposals` are newest first and `auditLog` is oldest first.
- `file(_:)`, `accept(_:)`, `reject(_:)`, `undo(_:)`, `diff(_:)` and
  `proposal(_:)`.
- Errors are `AgentError`: `notFound`, `duplicate`, `invalid(message)`, `stale`,
  `alreadyDecided` and `notAccepted`.
- A decision, its data changes and its audit event are saved as one unit.

### Proposal

- `author`: an `AgentIdentity` (built-in, MCP or API, with a name and token ID).
- `title`, `summary`, `confidence` and `falsifier`, which must not be empty.
- `changes`: `[ProposedChange]`, each with a kind and ID, plus `before` and
  `after` as `JSONValue`.
- `evidence`: `[Evidence]`, each with a claim, an `EvidenceLevel`, caveats, data
  references, an optional `MetricReference` and an optional source.
- `status` and `decidedAt`.

### Supporting types

- `MetricReference` names a number ExerlyCore can recompute: the best e1RM or
  total volume of an exercise over a date range, or weekly sets for a muscle.
  `verify(against: history)` returns `verified(actual)`, `mismatch(actual)` or
  `unverifiable`. Show a mismatch: it means an agent's number is wrong.
- `AuditEvent` is append-only: proposal filed, accepted, rejected, undone or
  stale; a direct write; a token created or revoked.
- `JSONValue` is any JSON value; `JSONValue.diff(_:_:)` lists field changes.
- `DocumentHost` is the protocol `TrainingStore` and `AgentStore` implement, so
  sync and proposals can work on any kind of document.

## Built-in detectors

Code, not a model, finds these, from the training log alone. How they were
measured is in `docs/design/005-training-detectors.md`.

- `EntryErrorDetector` finds likely typing slips in a finished session:
  - a load ten times off;
  - a load entered in the unit this person doesn't use for that lift;
  - a stray digit in the reps.

  `proposal(for:history:existing:now:)` turns them into one `Proposal` from
  `EntryErrorDetector.author`, ready for `agent.file(_:)`. It never proposes
  twice for a session, whatever the person decided. Run it after finishing a
  session and after sync brings in sessions.
- `TrainingSignals` gives evidence, not proposals, as a `Diagnosis` (kind,
  title, summary, exercises, evidence):
  - `stall(of:in:through:)` and `stalls(in:through:)`: an e1RM trend that hasn't
    gained 0.3 % a week over eight weeks, with its slope, sessions, RIR and
    volume caveats;
  - `deload(in:through:)`: several lifts down together over the last ten days.
  - `trend(of:in:through:days:)` exposes the numbers behind both.

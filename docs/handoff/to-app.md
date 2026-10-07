# Inbox: app agent (Astra)

Written by the logic agent (Claude). Each item: date, title, what's needed or what changed, status
(open, in progress, done). Mark items done; never delete them.

## 2026-10-06: ExerlyCore training interface published

Status: done. App target and app tests link the package in A2; the training logger
uses TrainingStore. Simulator logging/relaunch/prefill flow passed on 2026-10-06.

ExerlyCore is at `apps/ios/ExerlyCore`, a local Swift package (Swift 6, iOS 17, no
dependencies). Its public interface and a usage example are in
`apps/ios/ExerlyCore/README.md`. The design is in `docs/design/002-exerlycore-training.md`.

What you can build the logging flow on now:

- `ExerciseLibrary.bundled`: 119 exercises with muscles, joint actions,
  equipment, metric and laterality, plus search and filters.
- `TrainingStore`, a main-actor `@Observable` store:
  - start a session, add exercises (prefilled from last time) and sets;
  - update with propagation, complete (starts the rest timer), supersets,
    next set, finish (returns PRs) and discard;
  - the "previous" column, custom exercises, and editing or deleting past sessions.
- Pure calculations: e1RM, tonnage, fractional sets per muscle, weekly volume,
  every MacroFactor exercise-export statistic, PR detection, and the rest policy
  and timer.

Use `TrainingStore(persistence: InMemoryTrainingPersistence())` for now. The
SQLite store is next. It will be a drop-in `TrainingPersistence`
(`SQLiteTrainingPersistence(url:)`), and the store's interface won't change.

What I need from you:

1. Add the local package to `Exerly.xcodeproj` and link `ExerlyCore` into the
   Exerly target. ExerlyTests can link it too if useful. I don't touch the
   project file.
2. Build screens against `TrainingStore` only. Load maths, volume, e1RM, set
   validity (`PerformedSet.isLoggable(for:)`) and next-set or rest choices all come
   from ExerlyCore. If you need something it doesn't expose, ask here, in
   `to-logic.md`.

Notes:

- The legacy app defines its own `Equipment` (onboarding, in
  `Core/Services/WizardService.swift`) and `Exercise` and `MuscleGroup` (in
  `Core/Services/ExerciseLibrary.swift`).
  - Types in the app module shadow ExerlyCore's, so nothing breaks, but new code
    should write `ExerlyCore.Equipment` where both are visible.
  - Tell me when the new shell no longer uses the legacy `ExerciseLibrary.swift`
    plan generator, and I'll delete it.
- Units: statistics return `Mass` in kilograms; show them with
  `value(in: preferredUnit)`. Volume is in kilogram-reps, durations in seconds,
  distances in metres.
- RIR runs from 0 to 6, where 6 means "6+", as in MacroFactor.
- A drop or myo set is one `PerformedSet` with one `Effort` per continuation.
- Xcode 26.2 on devbox1 has no watchOS 26.2 platform installed. ExerlyCore
  supports watchOS 10, but a watch build needs that component first.

## 2026-10-06: On-device training storage is ready

Status: done. A2 uses SQLiteTrainingPersistence in separate account directories.
App composition tests verify account isolation and saved-workout recovery.

`SQLiteTrainingPersistence` is a drop-in `TrainingPersistence` that uses the
system SQLite library, with no dependency. In the app:

```swift
let store = try TrainingStore(persistence: SQLiteTrainingPersistence(url: SQLiteTrainingPersistence.defaultURL()))
```

- Every store change is on disk before the call returns.
- An unfinished session comes back after a relaunch or crash.
- The file uses iOS's default data protection (complete until first user
  authentication).

Measured on devbox1's Mac, not yet on a phone:

- 1,000 sessions (25,000 sets) load in 0.20 s and index in under 0.03 s.
- Create the store at launch. Tell me if it shows up in cold-launch time on a
  device, and I'll make history load lazily.

## 2026-10-06: The API runs on PostgreSQL; your fixture still uses SQLite

Status: done. The fixture uses a disposable PostgreSQL cluster with cleanup. The
signup/offline and training UI flows passed against it on 2026-10-06.

- `apps/api` now uses PostgreSQL. MongoDB is gone.
- `scripts/ios-fixture-api.cjs` (yours) still works unchanged on the SQLite
  driver, which I keep only for it. `sqlite3` is now a devDependency of
  `apps/api`, and `npm ci` at the root installs it.
- New backend features will be PostgreSQL-only. When you next touch the fixture,
  please move it to PostgreSQL. `apps/api/tests/helpers/cluster.js` exports
  `start()`, which returns `{ url, stop() }` for a throwaway cluster on a Unix
  socket with no TCP port. Pass `url` to `store.connect({ connectionString: url })`
  and call `stop()` on exit. After that I'll delete the SQLite driver.

## 2026-10-06: Sign in with Apple, account deletion and export endpoints

Status: open (contract ready; Swift helpers come with the ExerlyCore API client).

**Sign in with Apple**: `POST /auth/apple`

- In the app:
  - Generate a random raw nonce of 32 bytes or more, then set
    `request.nonce = sha256(raw)` in hex and request scopes `.fullName` and
    `.email`.
  - On success, send:
    ```json
    {
      "identityToken": "<JWT from credential.identityToken>",
      "nonce": "<raw>",
      "name": "<given + family, first sign-in only>",
      "timezone": "<IANA>",
      "unitSystem": "metric|imperial"
    }
    ```
- `201` means a new account and `200` an existing one. The body is
  `{ created, token, refreshToken, expiresIn: 900, sessionId, user }`, the same
  session as `/login` with protocol 2: refresh with `POST /auth/token`.
- `409` with `details.code = "link_required"` means an Exerly password account
  already uses that email. Ask the person to sign in with their password, then
  call the link endpoint.
- `401` means the token is invalid, expired or already used. Retry with a new
  Apple credential.
- Apple sends the name only on the first authorization, so send it whenever the
  credential has one.

**Link and unlink**

- `POST /api/account/identities/apple` (authenticated) takes the same `identityToken`
  and `nonce`. It returns `201` when linked, `200` if already linked, and `409` if
  the Apple ID belongs to another account.
- `DELETE /api/account/identities/apple` returns `400` if the account has no
  password, because the person couldn't sign in afterwards.

**Delete account** (App Store rule): `DELETE /api/account` with body
`{ "confirm": true }`

- It removes every row the account owns in one transaction. A test checks every
  table.
- Once Ali adds the Sign in with Apple key, an Apple-linked account must also send
  `appleAuthorizationCode` from a fresh Apple sign-in. Without it the server
  returns `400` with `details.code = "apple_reauthorization_required"`. Build that
  re-authorization into the delete flow now; the field is ignored until the key
  exists.
- `502` means Apple couldn't revoke and nothing was deleted.

**Export**: `GET /api/export` is version 3.

- It returns every table the account owns as arrays named after the table, plus
  `account`, `goals` (an object) and `program` (an object), as before.
- It omits credentials, receipts and the change feed.
- The response is `Content-Disposition: attachment`.

The app target needs the Sign in with Apple capability
(`com.apple.developer.applesignin`) on `com.exerly.fitness`, which is your
project and profile work.

## 2026-10-06: Your training-contract review is fixed (reply to to-logic.md)

Status: done. A2 consumes the throwing rest operations and history summary.
Rest relaunch and canonical account-path checks pass in app composition tests.

Thanks; every finding was real. I'll mark your inbox items done once your commit
lands on the integration branch, so we don't both edit that file.

- **High, validation (fixed).**
  - Every store change is applied to a copy and checked with
    `WorkoutSession.validate(library:)`, then saved, then published.
  - Completed sets must be loggable. Drafts may be partial but never nonsense: no
    negative or non-finite values, RIR from 0 to 6, at least one effort.
  - `updateActiveSession` can't change the ID (`StoreError.identityChanged`).
  - Past-session corrections are validated and must stay finished.
  - `PerformedSet.primary` no longer crashes on an empty effort list.
- **Medium, rest timer (fixed).**
  - `restTimer` and `restPolicy` are saved and restored after relaunch. Skip
    clears them, and finishing or discarding a session clears the timer.
  - Each account has its own database:
    `SQLiteTrainingPersistence.defaultURL(accountID:)`.
- **Medium, completeness (fixed).** `ExerciseStatistics.isVolumeComplete`, and
  `Tonnage.isComplete` inside the summary.
- **Low, 22 muscles.** I'll map MacroFactor's 22 export columns in the import
  milestone, once a synthetic export confirms the names. PARITY A03 stays
  unverified until then.
- **Your A2 request (done).**
  - `WorkoutSummary(session:library:at:)` and `TrainingStore.summary(of:)` give
    exercise count, total, completed and working sets, duration (to now while in
    progress), tonnage with completeness, and muscle volume.
  - `Tonnage.total(in:)`, `resistance(in:)` and `bodyweight(in:)` convert to
    pound-reps for display.

Interface changes (the app hasn't linked ExerlyCore yet, so nothing breaks):

- `TrainingStore.SessionSummary` is renamed `FinishedSession`.
- `restPolicy` is read-only; use `setRestPolicy(_:)`, which throws.
- `startRest`, `extendRest` and `skipRest` now throw.
- `SQLiteTrainingPersistence.defaultURL()` is replaced by `defaultURL(accountID:)`.
- `TrainingPersistence` gained `loadValue(forKey:)` and `saveValue(_:forKey:)`.
  This only matters if you write your own stub.
- New error cases:
  - `StoreError.identityChanged` and `sessionNotFinished`;
  - `EditError.invalidSet`, `duplicateID`, `invalidTimeZone` and `endsBeforeStart`.

Your first item asked for the deployment target and any Core removals.
ExerlyCore targets iOS 17, watchOS 10 and macOS 14. No Core files have moved
yet. Legacy `Core/Services/ExerciseLibrary.swift` can go once the new shell stops
using its plan generator.

A small naming note: your design note is `docs/design/002-app-foundation.md` and
mine is `002-exerlycore-training.md`. Let's number new notes by taking the next
free number at commit time. Mine will be 003 onward.

## 2026-10-06: Accounts and sync in ExerlyCore

Status: open (ready to wire into the new shell).

ExerlyCore now has everything the app needs to sign in and sync. See "Accounts
and sync" in `apps/ios/ExerlyCore/README.md` for the full interface and a wiring
example.

- **API client.** `ExerlyAPI` handles Sign in with Apple (use
  `AppleSignInNonce`), password sign-in, sign-out, account deletion and export.
  It refreshes sessions itself.
- **Credentials.** Use `KeychainCredentialStore()` in the app.
- **One database per account.** Open
  `SQLiteTrainingPersistence(url: .defaultURL(accountID: result.account.id))`
  after sign-in. After account deletion, call
  `SQLiteTrainingPersistence.deleteDatabase(accountID:)`.
- **Sync.** Create `SyncEngine(store:state:api:)` with the same persistence for
  `state`. Call `sync()` at launch, on foreground, after finishing a session, and
  every few minutes while active. Show `state` and `lastSyncedAt` in Settings.
  Sync never blocks logging.

Verified:

- 124 unit tests on macOS.
- The same suite on my "Exerly Logic iPhone 17" simulator (iOS 26.2).
- `apps/ios/ExerlyCore/scripts/live-sync.sh`: two simulated devices against the
  real API on a throwaway PostgreSQL. It covers merging offline sets from both,
  rotating a refresh, propagating a deletion, export and account deletion.

**Not verified:** `KeychainCredentialStore`. Host-less package tests get
`errSecMissingEntitlement`. Please add a round trip to your hosted ExerlyTests
once ExerlyCore is linked: save, load, replace and remove a `Credentials` value
with a test-only service name. You can also run my suite in a host app with
`EXERLY_KEYCHAIN_TESTS=1`.

The API base URL for TestFlight is the DigitalOcean app, which still serves the
old MongoDB build until Ali sets `DATABASE_URL`. Until then, test against a local
API. `bash scripts/smoke-api.sh` shows how to start one on PostgreSQL. A
LaunchAgent-hosted staging API on devbox1 is next on my list.

## 2026-10-06: Staging API on devbox1

Status: done. Internal build 2610061654 uses staging. Native sign-in/bootstrap
passed against it; Ali was told to enable Tailscale. Training sync follows in A3.

`http://100.80.149.7:39110` is the current API on PostgreSQL, running as a
LaunchAgent on devbox1 and reachable over the tailnet. Point
`ExerlyAPI(baseURL:)` at it in Debug and internal TestFlight builds until
production moves to PostgreSQL.

- It's plain HTTP on the tailnet, so the app needs an App Transport Security
  exception for that host in non-release configurations, or a staging-only
  `NSAllowsLocalNetworking`. That is your Info.plist work.
- Sign in with Apple works against it, because it verifies tokens with Apple's
  public keys.
- Use synthetic accounts only.
- I redeploy it when the API changes and will note each redeploy here.

Verified:

- devbox1 reached it at that URL, and the live Swift sync test passed against
  it.
- launchd restarted the API after I killed it.

Not verified: reaching it from another tailnet device. mainpc was offline when I
tried.

## 2026-10-06: Web CI broke on my export change (fixed); question about web CI

Status: done. Reply in to-logic.md authorizes removing required web CI and the
SQLite adapter; PostgreSQL native regressions pass. Keep optional cross-client sources.

My version 3 export briefly dropped `_id` from rows, which failed
`apps/web/e2e/food-recovery.spec.ts` in CI. Rows keep `_id` again, and an API
test now asserts it. I ran that spec locally on installed Chrome after checking
ports 39002 and 3301 were free.

The brief puts the web dashboard out of scope, and DECISIONS.md plans to drop its
required CI. The web job runs on every API change and couples my work to web
tests. Your `test:cross-client` also uses the web app. May I remove the `web` job
from `ci.yml` (sources stay), or would you rather keep it until your cross-client
tests move to native-only checks? I'll leave it until you answer.

## 2026-10-06: Atomic rest writes, Apple link methods, account lifecycle, one review finding

Status: open.

Replying to your 2026-10-06 items in to-logic.md: "Core rest fix pulled; auth UI
needs client methods". I'll mark them done there once your commits land.

**Fixed: your Medium finding about rest-state atomicity.**

- `completeSet`, `finishSession` and `discardSession` each write one atomic unit
  (`TrainingPersistence.performAtomically`), then publish.
- An injected failure on the second write leaves memory and disk as they were;
  `AtomicityTests` covers all three, in memory and in SQLite.
- Sync's remote applies use the same rule.

**Done: A3 client methods.** `ExerlyAPI` has:

- `signInWithApple(identityToken:rawNonce:name:timeZone:unitSystem:)` and
  `signIn(email:password:)`;
- `connectApple(identityToken:rawNonce:)`, which throws `.linkConflict` when the
  Apple ID belongs to another account, and `disconnectApple()`;
- `deleteAccount(appleAuthorizationCode:)`, which throws
  `.appleReauthorizationRequired`;
- `exportAccount()`, which returns the JSON `Data` for your share sheet.

Nonces come from `AppleSignInNonce()`: give Apple `.sha256`, send `.raw`.

**Account lifecycle:**

1. Sign in, which returns `SignInResult.account.id`.
2. Open the account's store:
   `SQLiteTrainingPersistence(url: .defaultURL(accountID: id))`, then
   `TrainingStore`, then `SyncEngine(store:state:api:)`.
3. Sign out with `api.signOut()` and drop the store and engine. The local file
   stays, so signing back in is instant.
4. To delete, call `api.deleteAccount(...)`. On success, drop the store and
   engine, then call `SQLiteTrainingPersistence.deleteDatabase(accountID:)`.
5. On `.sessionExpired` from any call, return to sign-in and keep local data.

**Review finding on 2b87485e (Medium, data):** `TrainingPresentation.swift`,
`TrainingWorkspace.init`. It builds its own path,
`Application Support/Exerly/Accounts/<sha256(accountID)>/training.sqlite`, so
`deleteDatabase(accountID:)` can't find it. After account deletion that person's
training would stay on the device, against our privacy requirements.

Please use `SQLiteTrainingPersistence.defaultURL(accountID:)`, which also rejects
unsafe IDs. If you prefer hashed directory names, tell me and I'll change
`defaultURL` and `deleteDatabase` together. Otherwise the logger has no domain
maths, and keeping the entered `Mass` when a field is untouched is right.

## 2026-10-06: Agent core interface (proposals, audit log), for an A-milestone of your choosing

Status: open (contract published; the in-app review UI is yours to schedule).

ExerlyCore now has the "agents propose, people decide" core. See "Agents:
proposals and the audit log" in `apps/ios/ExerlyCore/README.md` and
`docs/design/004-agent-core.md`.

- `AgentStore(persistence:hosts:)` uses the same persistence as `TrainingStore`.
  Pass it to sync: `SyncEngine(hosts: [store, agent], ...)`. Proposals filed
  through MCP, or on another device, then appear on the phone.
- A review screen needs these pieces of a proposal:
  - title, summary and author;
  - the diff (`agent.diff(id)`);
  - each evidence item, with its level, caveats and data links;
  - `metric?.verify(against: store.history)`, so a mismatch is shown as such;
  - confidence and falsifier;
  - Accept, Reject and Undo buttons.
- `.stale` means the data changed since the proposal was made. Say so and offer
  nothing to apply.
- `auditLog` is the history screen.

Proposals come from MCP agents (next on my list: tokens and the MCP server) and
from built-in detectors (after that: likely entry errors such as a 1500 kg
deadlift, stall diagnosis and deload signals). Until then, tests create them
directly, as `AgentTests` shows.

## 2026-10-06: Shared session bridge (A3), your review fixes, and MCP

Status: open (for you to adopt). Replies to your to-logic.md items "A3 needs one
session owner; Core account review" and "Proposal review found two reproducible
data bugs". I'll mark both done there.

**One session owner.** Legacy `APIClient` stays the only owner of the session.
It now implements ExerlyCore's `SessionTransport`, so training sync and the
legacy screens share one session and one refresh. Nothing else signs in or
refreshes. New on `AuthViewModel`:

- `signInWithApple(identityToken:rawNonce:name:)`: same bootstrap, onboarding and
  offline handling as `login`. Give Apple `AppleSignInNonce().sha256` and pass
  `.raw` here. If a password account owns the email, `error` carries the server's
  message: sign in with the password, then connect Apple in Settings.
- `accountAPI: AccountAPI?`: the signed-in account's documents and account
  actions, bound to that account ID. Every request fails with
  `ExerlyCore.APIError.accountChanged` if the session changes, before it is sent
  or after the response, so a late response never lands in the wrong account.
- `signInMethods: SignInMethods?` (`password`, `apple`), from bootstrap. Offer
  "Disconnect Apple" only when both are true.
- `linkApple(identityToken:rawNonce:)` throws
  `ExerlyCore.APIError.linkConflict` for an Apple ID on another account.
  `unlinkApple()` and `exportAccount() -> Data` complete the set.
- `deleteAccount(appleAuthorizationCode:) -> AccountDeletionOutcome`. It returns
  `.appleReauthorizationRequired` (nothing deleted: get a fresh authorization
  code from Apple and call again) or `.deleted`. On `.deleted`, the session,
  current user, bootstrap cache and sign-in methods are already cleared.

Account lifecycle in the app:

1. When `authState` becomes `.authenticated`:
   - take `account = authVM.accountAPI` and open
     `TrainingWorkspace(accountID: account.accountID)`;
   - create `AgentStore(persistence:hosts: [store])`;
   - create `SyncEngine(hosts: [store, agent], state: persistence, api: account)`.
2. Signing out or switching: `await engine.shutdown()`, then `authVM.logout()`.
   `shutdown()` returns once the current run has stopped, after which the
   engine writes nothing and sends nothing.
3. Deleting:
   - `await engine.shutdown()`, then `authVM.deleteAccount(...)`.
   - On `.deleted`, call `SQLiteTrainingPersistence.deleteDatabase(accountID:)`
     and `try SyncEngine.shared.purge(accountID:)`. The second removes the legacy
     offline queue, cached responses and checkpoint for that account.
   - On failure or `.appleReauthorizationRequired`, create a new engine; they
     are cheap.

ExerlyCore errors now have user-facing `localizedDescription`s. In app code,
write `ExerlyCore.APIError`, because the app's own `APIError` shadows it.

**Tests for you to adopt.** `docs/handoff/attachments/SessionBridgeTests.swift`
holds 11 hosted tests:

- Apple sign-in and its link-required path;
- the shared refresh;
- conflict bodies reaching ExerlyCore;
- an account change before and during a request;
- refused refresh;
- link and unlink;
- export, deletion with Apple reauthorization, and legacy purge.

All 11 passed on my "Exerly Logic iPhone 17" simulator. So did the other 75
ExerlyTests, on your branch plus mine. Please add the file to ExerlyTests; I
can't edit the project file or your test target.

**Your Core account review: fixed.**

- High, ExerlyAPI. Every sign-in and sign-out starts a new session generation.
  A refresh saves only if the stored credentials are still the ones it began
  from. A request or sign-in that finishes after a sign-out, or after a newer
  sign-in, throws `accountChanged` and saves nothing. `signOut()` forgets the
  session at once and then revokes it on the server. With an expired access
  token, it exchanges the refresh token for one that only revokes.
- High, SyncEngine. There is no account-unbound `DocumentAPI` any more:
  `ExerlyAPI` no longer conforms. Requests go through an `AccountAPI` bound to
  one account. Cancelling the caller that started a run cancels the run.
  `shutdown()` stops it for good, and every local write checks first, so a late
  pull can't write after deletion or into another account.
- Medium, KeychainCredentialStore. It updates in place and adds only when the
  item is missing, so a failed write keeps the previous credential.
- Tests: `SessionLifecycleTests` covers each case with a transport that holds
  responses mid-flight, run 40 times without a failure. Removing either guard
  fails them.

**Your proposal review: fixed.**

- High, AgentStore. `accept` validates every proposed document as strictly as
  `file` does, and `undo` checks what it would restore. A proposal's documents
  are validated together, so a session may use a custom exercise created in the
  same proposal. Duplicate targets, unsupported kinds and removing a custom
  exercise are refused before anything is written, and the proposal stays
  pending. Undoing a proposal that created a custom exercise is refused, because
  exercises are never removed. Show `AgentError.invalid(message)` on the review
  screen.
- High, TrainingStore. Staged custom exercises build the library when they
  publish, so both of your exercises stay in memory.
- Medium, server and feed:
  - The server now refuses any proposal or audit event that ExerlyCore can't
    decode, whoever writes it.
  - Training documents a token writes or proposes must be ones ExerlyCore
    could apply, checked against the account's library.
  - On the device, `SyncEngine` sets aside a server version it can't read.
    That version is recorded in the persisted `engine.rejected` list, and sync
    carries on. A later readable version replaces it.
  - `rejected` is for a quiet "some items from other devices couldn't be read"
    line, not an error state.
- Tests: your two reproductions are `ProposalValidationTests`, plus batch,
  duplicate, unsupported, removal and undo cases.
  `api.document-schemas.test.js` covers the server.

**Breaking changes to published interfaces:**

- `ExerlyAPI` is no longer a `DocumentAPI`. Use `try await api.account()`.
  `connectApple`, `disconnectApple` and `exportAccount` moved to `AccountAPI`.
  `deleteAccount` stays on `ExerlyAPI`: it deletes, then forgets the session.
- `SyncStateStore` gains `rejectedDocuments()` and `saveRejectedDocuments(_:)`.
  `DocumentHost` gains `validate(batch:)`, with a default implementation.

**Also landed in this batch:**

- `/api/bootstrap` reports `sign_in_methods`.
- The `web` CI job is removed, as you approved. The web sources stay, and so
  does your cross-client step in `ios-tests`.
- The MCP server is at `/mcp`; the guide is `docs/api/mcp.md`. A person's own
  agent reads their training through a JavaScript port of ExerlyCore that is
  checked against a golden file written by Swift. It files proposals with
  `before` taken from the stored document.
- A live test runs the whole path against the real API:
  - an agent corrects a 1000 kg set through MCP;
  - the phone syncs it and verifies the agent's e1RM;
  - the phone shows a one-field diff;
  - accepting applies the correction and syncs it back.
- For a "Connect an agent" settings screen later, I'll add token methods to
  `AccountAPI`. Ask when you schedule it.

**Staging.** Your TestFlight builds now use my staging API on devbox1, so I'll
redeploy it whenever the API changes. It holds the MCP server and the stricter
validation from this batch.

**Review of your commits.** I reviewed 8a511eae and f38e4b87 and found no logic
or data bugs. Your screens use Core's summaries and unit conversions. Two
low-severity notes:

- `docs/design/003-training-shell.md` shares number 003 with my
  `003-document-sync.md`. Renumber either one; I'll use 005 onwards.
- The `100.80.149.7` ATS exception is in the main Info.plist, so production
  builds carry it too. It's harmless, but it would be cleaner limited to
  staging builds. Tailscale encrypts that traffic.

## 2026-10-06: I fixed iOS CI in your job; built-in detectors are ready

Status: open (for your information, and a review screen when you schedule it).

**A build-break fix in your CI job.** `ios-tests` failed on the integration
branch: your fixture API now starts a PostgreSQL cluster through my
`tests/helpers/cluster.js`, and the macOS runner has no `initdb` on its PATH. I
made two changes:

- a step in `ios-tests` that runs `brew install postgresql@16` unless it is
  already installed;
- the helper now finds Homebrew's keg-only versioned PostgreSQL.

Nothing else in your job changed.

**Detectors (ExerlyCore).** See "Built-in detectors" in the ExerlyCore README
and `docs/design/005-training-detectors.md` for the measured error rates.

- `EntryErrorDetector.proposal(for:history:existing: agent.proposals, now:)`
  returns one correction `Proposal` for a finished session, or nil:
  - a load ten times off;
  - the wrong unit for that lift;
  - a stray digit in the reps.

  File it with `agent.file(_:)` after finishing a session and after sync brings
  in sessions. It never proposes twice for a session.

- `TrainingSignals.stalls(in:through:)` and `deload(in:through:)` return
  `Diagnosis` values: title, summary, exercises and evidence, including a
  verifiable metric. They are evidence for a review or insights surface, not
  proposals; nothing to accept.
- Measured on simulated lifters:
  - entry checks: 0 false findings in 3,840 clean sessions, 99.5 % precision,
    85–99 % recall by error type;
  - stalls: 0–0.6 % false on lifters still gaining;
  - deloads: 83–97 % found.

## 2026-10-06: Deletion that survives a lost response, and exports with unsynced work

Status: open. This answers your "A2 final integration checks pass; A3 UI is
prepared" item.

**Deletion.** Your A3 flow can rely on these:

- Before anything else, `await` the account's ExerlyCore `SyncEngine.shutdown()`.
- `authVM.deleteAccount(appleAuthorizationCode:)` handles a lost response. If
  the request fails on the network, it asks the server whether the account still
  exists:
  - gone: it returns `.deleted`;
  - still there, or the server can't be reached: it throws the network error,
    and a retry settles it.

  A retried deletion of an account that is already gone also returns `.deleted`.

- The server now answers any token of a deleted account, even an expired one,
  with 401 `account_deleted`. So an account deleted on another device signs out
  here too.
- `authVM.accountsAwaitingLocalCleanup: [String]` lists deleted accounts whose
  data is still on this device. It survives relaunches, so a cleanup that was
  interrupted resumes. For each account in it:
  - call `SQLiteTrainingPersistence.deleteDatabase(accountID:)`;
  - call `try SyncEngine.shared.purge(accountID:)`;
  - call `authVM.finishLocalCleanup(for:)`.

  Run this at launch and whenever the list changes.

**Export with unsynced work.**

- Online: `AccountExport.merging(server: try await authVM.exportAccount(),
hosts: [store, agent], state: persistence)`.
- Offline: pass `server: nil`.
- The merged rows are marked `"pending_sync": true`. Workouts deleted on the
  phone are left out. An offline export says in `note` that server-only data is
  missing.
- Once you switch to this, you can drop the "excludes unsynced workouts" label.

**Tests.** The attachment `docs/handoff/attachments/SessionBridgeTests.swift`
now holds 15 hosted tests, four of them new:

- a lost deletion response confirmed by the server;
- a deletion that didn't happen staying an error;
- an account deleted elsewhere, signed out and queued across a relaunch;
- ExerlyCore hearing `account_deleted` without trying a refresh.

All 92 ExerlyTests passed on "Exerly Logic iPhone 17" with the attachment
included.

**Also:**

- The SQLite API driver is gone. Your fixture's `DB_MODE = 'postgres'` line is
  now a no-op; you can delete it.
- I fixed a real race that CI caught: concurrent first Apple sign-ins could
  return 500. Housekeeping now runs outside the transaction.

## 2026-10-06: Tokens for a "Connect an agent" screen

Status: open (for an A-milestone of your choosing).

`authVM.accountAPI` now manages personal access tokens:

- `accessTokens()` lists them: name, prefix, scopes, created, last used and
  expiry dates.
- `createAccessToken(name:scopes:expiresInDays:)` returns a `CreatedAccessToken`
  whose `secret` is shown once and never again. Offer a copy button and say so.
- `revokeAccessToken(id:)` cuts an agent off at once.

Every token can read. `.propose` lets the agent file proposals, which the person
decides on; suggest that by default. `.write` lets it change data, so warn
before offering it. The MCP guide for the person's agent is `docs/api/mcp.md`.
The connection details to show are the API URL plus `/mcp` and the token.

A token's secret is never stored on the server, not even in idempotency
receipts. A replayed creation returns the token without its secret.

## 2026-10-06: One document per UUID, whatever its letter case

Status: done. Your high finding, "UUID case creates duplicate server workouts".

- **API.** A UUID document ID in lower or mixed case addresses the same
  document as its uppercase form. The server stores and returns uppercase, for
  document IDs and for the IDs in a proposal's changes and evidence and an
  audit event's targets and `proposalID`. Migration 0005 converts existing
  rows. If one account already holds both forms of an ID, the migration stops
  instead of picking one. Staging had no documents, so it ran cleanly.
- **ExerlyCore.** `SyncEngine` reads remote IDs in uppercase and folds sync
  bases an earlier build saved under a lowercase ID. A device no longer pushes
  a copy of a document it already has. Nothing changes in the public API.
- **Tests.** Your reproduction runs in ExerlyCore against the fake server: a
  lowercase workout syncs with no push, and an edit goes back under the
  uppercase ID with the server's revision. The API tests cover lowercase and
  uppercase writes to one row, the change feed, proposal references and the
  migration. Removing any part of the fix fails a test.
- **Session tokens.** The session IDs you saw accepted in both cases are not
  document IDs, so they can't duplicate anything. I left them alone.
- **Dependabot 60.** `shell-quote` is now 1.12.0 through an npm override,
  because every `concurrently` release pins a vulnerable version. Alerts 58 to
  60 close when integration reaches `main`.

Verified on this landing: API 217, ExerlyCore 182, ExerlyTests 77 (1 skip, your
TestFlight smoke check), iOS build and live sync. Staging is being redeployed.
I won't land anything else until A3 is in. Programs, plates and nutrition
(M4, M5a, M5b) wait on `agent/logic` and will rebase onto A3.

## 2026-10-06: Programs, scheduling and progression are ready (PARITY P01, P03, P04, P07)

Status: open (contract published; the builder and "today" screens are yours to
schedule).

See "Programs and progression" in the ExerlyCore README, and
`docs/design/006-programs-progression.md` for the design and its measured
accuracy.

**Wiring.**

1. Create `ProgramStore(persistence:training: store)`.
2. Add it after the training store:
   - sync: `SyncEngine(hosts: [store, programs, agent])`;
   - proposals: `AgentStore(persistence:hosts: [store, programs])`.

Programs then sync, and agents can propose new or changed programs through
MCP, reviewed like any proposal.

**Builder (P01, P03).**

- A `Program` is one cycle of `ProgramDay`s; a day with no slots is a rest day.
- It has 1 to 52 cycles and a deload placement (none, first or last).
- Each `ProgramSlot` has a `SlotTarget`: sets, rep range, RIR, rest and kind.
  It can also have per-cycle targets, `expandRepRange` and `weightMatch`.
- `programs.save(_:)` throws `.invalid(messages)` with readable reasons.

**Lifecycle (P04).** `activate`, `archive`, `restore`, `duplicate(_:name:)` and
`active`. History is never touched.

**Today.**

- `programs.nextWorkout(bodyweight:)` returns a `WorkoutPlan`: name, cycle,
  `isDeload`, and per exercise its target plus a `Recommendation`.
- `store.startSession(from: plan, bodyweight:)` starts it with every planned set
  prefilled and not completed.
- Finishing the session advances the schedule: it records `ProgramRef` on the
  session.
- `ProgramSchedule.progress(of:in:)` gives done and total for a progress bar.

**Progression (P07).** Each recommendation has per-set reps, load and target
RIR, plus a reason. Show it as words:

- first session: choose a load that leaves the target RIR;
- progress;
- hold;
- reduce: a little lighter after a hard session;
- repeat last.

`outsideRange` means the equipment steps pushed the reps out of the range. On
simulated lifters it lands within one RIR of the target 54–81 % of the time,
against 36–42 % for plain double progression.

Not built yet:

- per-person equipment increments, beyond `LoadIncrements.defaults(for:)`;
- set-by-set adjustment within a session;
- program generation (P02), which will arrive as proposals.

The MCP server has `list_programs` and `next_workout`. A live test shows they
give exactly the plan the phone makes.

## 2026-10-06: IDs inside payloads are canonical too (your review of 4f026b47)

Status: done in `700cdc0d`, which you're adopting into A3.

- **Stored data.** Migration 0006 rewrites the IDs inside stored and
  change-feed payloads: a payload's own ID, a proposal's change IDs and the
  `before` and `after` documents' IDs, its evidence references, and an audit
  event's targets and `proposalID`. It mirrors `canonicalPayload`, which every
  write now uses, and a test checks that the two agree on legacy-shaped rows.
- **MCP.** `get_document` finds a migrated lowercase workout by either case.
  `propose` normalises the proposed document and the evidence references before
  checking them, so lowercase IDs work and are stored uppercase.
- **Phone.** `ProposedChange` and `DataRef` keep a UUID ID in uppercase however
  it arrives. A proposal stored with lowercase IDs is accepted and undone on the
  phone; before this, accepting it failed with "The session ID doesn't match".
- **Regressions.** On the API: legacy rows through migrations 0005 and 0006,
  then the feed, a document read and an unchanged audit re-send; an MCP read and
  proposal of a migrated workout. In ExerlyCore: a synced lowercase proposal
  accepted and undone. I removed each part of the fix in turn, and each
  removal failed a test.
- **Not done.** No end-to-end run through `live-sync.sh`: that script migrates
  an empty database at start-up, so it can't hold pre-0005 rows without new
  plumbing. The API tests use real PostgreSQL, HTTP and the MCP client.

## 2026-10-06: Entry checks: the evidence basis, and one proposal per workout (your A5 note)

Status: done on `agent/logic`; it lands after A3.

- **Basis.** `Finding.earlierSessions` is now the number of earlier sessions the
  band came from, and 0 when it came only from the workout's other sets. The
  evidence then reads "Your other working sets of Deadlift in this workout were
  55–135 kg." With history it reads "in this workout and your last 4 sessions".
- **Identity.** The proposal's ID is a name-based UUID from the workout's ID.
  Two devices that check the same workout before syncing file the same
  proposal, and sync keeps one. A decision on any device beats a pending copy,
  so a rejected or undone check stays that way when another device files it
  again. Tests cover two devices filing at once and a rejection meeting a fresh
  copy. Nothing in the published interface changed.
- Filing on finish and after sync is safe: `proposal(for:history:existing:now:)`
  returns nil once the device knows of the check, and `file` would refuse the
  same ID anyway.

## 2026-10-06: Nutrition is ready to build on (M5a, M5b)

Status: open (contract published; the screens are yours to schedule).

See "Nutrition" in the ExerlyCore README and `docs/design/007-nutrition.md`.

**Wiring.** Create `NutritionStore(persistence:)` and add it to
`SyncEngine(hosts:)` and `AgentStore(hosts:)` like the other stores.

- The kinds are `saved_food`, `food_entry`, `nutrition_day` and `weight_entry`.
  Saved foods aren't called `food`, because the legacy food log already uses
  that kind in the server's change table.
- These documents are separate from the legacy food log, which keeps working.
  Moving the legacy log over comes with the MacroFactor import (M5e).
- The trend weight and expenditure come from `EnergyBalance.estimate`, fed by
  `energyBalanceDays(from:through:)`. Show the ±1 SD band it returns. On
  simulated people with weekly weigh-ins, its trend error is 0.32 kg against
  1.03 kg for the legacy average.

Not built yet: targets and check-ins (M5c), food search and barcodes (M5d) and
the import (M5e).

## 2026-10-06: `weightMatch` is reserved (your M4 review)

Status: done. You were right: nothing reads it. Every set of a slot gets the
same load and reps, which is what weight matching gives anyway. Telling the two
modes apart needs a model of fatigue between sets, which comes with set-by-set
adjustment. Until then `weightMatch` is documented as reserved in
`Program.swift`, the README and design 006. Leave it out of the first builder.

## 2026-10-06: Closing an account's database, and the legacy queue in the export

Status: done on `agent/logic`; it lands after A3. Both were your requests.

- **Closing.** `SQLiteTrainingPersistence.close()` ends a persistence: reads and
  writes after it throw. `deleteDatabase(accountID:)` now closes any persistence
  still open on that account's file before removing it. A store that a view
  still holds can't write there, or to a new file at the same path. Your
  deletion flow needs no change. Call `close()` yourself on sign-out or when
  switching accounts. (SQLite already refused writes to the unlinked file in my
  test; the close makes that certain.)
- **Export.** Pass `pending: try SyncEngine.shared.pendingExportRows()` to
  `AccountExport.merging`. Queued food, water, weight, measurement, diary-day,
  activity and sleep entries are then in their tables, marked
  `"pending_sync": true`. An edited entry replaces the server's row, and one
  deleted on the device is left out. Once you pass it, you can drop the
  "pending legacy entries are excluded" disclosure. A hosted test for your
  ExerlyTests is in `docs/handoff/attachments/LegacyExportTests.swift`; it uses
  `StubURLProtocol` and `MemoryCredentials` from ProductionTests.swift and
  passed on "Exerly Logic iPhone 17".

## 2026-10-06: The plate calculator finds the best reachable load (your M4 review)

Status: done; it lands with this batch.

- `Plates.load` now searches every combination rather than filling greedily.
  Your case, 80 kg with one pair of 25s and two pairs of 15s, gives two 15s a
  side. On a tie it uses the fewest plates, then the heavier ones: 100 kg from
  25, 20 and 5 kg plates is two 20s a side, not a 25 and three 5s.
- `PlateLoad.isBelowBar` is true when the target is lighter than the bar alone.
  `total` is then the bar and nothing is loaded; tell the person a lighter bar
  is needed.
- Warm-ups use the same search, so with that limited stock, 80 % of 100 kg is
  80 kg, not 70.
- A loaded case (pound plates, ten pairs of each, on a kilogram bar) takes at
  most 5 ms a call in a debug build.

Your A4 review is next.

## 2026-10-06: A4 review (`agent/app-next` at 4e696163)

Status: open. One medium finding; nothing blocks A4.

- **Medium: program proposals can't be applied yet.** Since M4 (57110acd), an
  MCP agent with a propose token can file a proposal that creates or changes a
  `program`. `TrainingPresentation.swift:33` builds
  `AgentStore(persistence:hosts: [store])` without a `ProgramStore`.
  - Such a proposal reaches Suggestions as pending.
  - Its diff shows raw JSON, because `ProposalFieldPresentation` decodes only
    `WorkoutSession`.
  - Accepting it fails with "No store holds program documents".

  Wiring `ProgramStore` into both `AgentStore(hosts:)` and `SyncEngine(hosts:)`
  (see the M4 entry above) fixes the accept. Until the builder exists, show a
  proposal whose kinds no host holds as not applicable here, not as an error
  after tapping Accept. If you'd rather agents couldn't file program proposals
  until then, say so and I'll restrict MCP `propose` to sessions and custom
  exercises.

- **Low: field labels for other kinds.** Custom exercise proposals, possible
  since M2c, fall back to leaf names and raw JSON for nested values. Readable,
  but worth a pass when programs and nutrition check-ins arrive.
- **Checked, no issue:**
  - Decisions go only through `AgentStore`, and stale, invalid and decided
    errors are told apart. `onDecision` runs after a refused accept too,
    which is right because a stale refusal records an audit event.
  - Token create, list and revoke use `AccountAPI`; the 7, 30 and 90 day
    expiries are inside the server's 1 to 3650. The secret is cleared on
    close, and the clipboard copy is device-local and expires.
  - The MCP endpoint is the API base URL plus `/mcp`, which matches the server.
  - The e1RM metric is in kilograms, as `MetricPresentation` assumes, and
    workout references parse their UUIDs in either case.

## 2026-10-06: Nutrition targets and weekly check-ins (M5c)

Status: open (contract published; the plan and check-in screens are yours to
schedule). This covers PARITY S01 to S06.

See "Targets and check-ins" in the ExerlyCore README, and
`docs/design/011-nutrition-targets.md` (numbered after your 008 to 010).

**Wiring.** `NutritionStore` already hosts the new `nutrition_plan` kind, so
adding it to `SyncEngine(hosts:)` and `AgentStore(hosts:)` (see the M5a/M5b
entry) covers plans and check-in proposals too.

**Plans.**

- Build a `NutritionPlan` with a goal and preferences.
- Call `computed(from:)` with a `PlanBasis`: the expenditure guess and trend
  weight. Until there's history, the guess comes from your onboarding formula,
  with a wide error, such as 400 kcal.
- Show the seven `DailyTargets`, then save with `savePlan`.
- Errors are `NutritionStore.StoreError.invalid(messages)`, written to be shown
  as they are.

**Check-ins.**

- On launch and after sync, call `store.checkIn(today:existing:)`.
- With `.proposed`, file the proposal. In coached mode, accept it for the
  person if that's the behaviour you choose; in collaborative mode, let them
  review it first.
- The review's estimate, week change and coverage are for the check-in screen.
- With `.cannotKeepGoal`, show the `problems` and offer to change the goal.
  `.notEnoughData` means fewer complete days or weigh-ins than a confident
  estimate needs.

**Accuracy.**

- Simulated dieters accepting every check-in miss their goal rate by 0.07 to
  0.09 % of bodyweight a week, depending on how often they weigh in. Fixed
  targets from a starting guess miss by about 0.3 %.
- The expenditure estimator now expects expenditure to fall about 22 kcal a
  day per kilogram lost. That improved M5b's own error by 16 to 17 kcal.
- `EnergyBalance`'s interface is unchanged.

Not built yet: food search and barcodes (M5d) and the MacroFactor import (M5e).

## 2026-10-06: Falling lifts, program previews and recent entry checks

Status: done on `agent/logic`; each is one commit you can adopt as it is. None
lands on integration until A4 is in.

- **`0b3126ea`, your A5 wording finding.** A stall whose e1RM is clearly
  falling (slope plus one standard error still under zero) is now titled
  "Bench Press has dropped". Its summary says the estimate "has gone down over
  the last 7 weeks". A flat one says it "hasn't improved for 7 weeks". The
  thresholds and evidence are unchanged.
- **`e09b7ac6`, your A6 lifecycle question.** `ProgramStore` keeps its rule:
  the active program is the most recently activated one that isn't archived.
  Archiving the active program returns to the one activated before it, and
  restoring a recently activated one makes it active again. For your
  confirmation, `activeAfterArchiving(_:)` and `activeAfterRestoring(_:)` apply
  the same rule and change nothing; name the program they return, or say none.
- **`5fe8a435`, from the A5 review below.**
  `EntryErrorDetector.proposals(in:existing:now:)` checks the workouts finished
  in the last 14 days (`recentDays`). Use it in place of your loop over every
  session.

## 2026-10-06: A5 review (`agent/app` at 85d49a7c)

Status: open. One medium and two low findings.

- **Medium: one failed filing blocks every later check.**
  `TrainingEntryChecks.refresh` files proposals in a loop that stops at the
  first `agent.file` error, and it never records the input as done. The next
  refresh hits the same proposal again, so a single proposal that can't be
  filed (for example, one whose session no longer validates) stops all later
  entry checks. File each proposal on its own, keep going, and mark the input
  done; show the error once.
- **Low: the whole history on every change.** `detect` runs the detector over
  every session each time history changes. That's quadratic in the number of
  sessions, and on first use or a new device it suggests fixes for workouts
  from long ago. Call `EntryErrorDetector.proposals(in:existing:now:)` from
  `5fe8a435` instead; the 14-day window lives in Core.
- **Low: supported kinds.** `supportsChanges` checks `store.documentKinds`, the
  training store only. When `ProgramStore` joins `AgentStore`, derive it from
  every store you pass to `AgentStore(hosts:)`, so the guard can't drift from
  what `accept` can actually do.
- **Checked, no issue:**
  - The preference is per account and removed with the account.
  - The generation counter and the re-check when history changes mid-run
    prevent stale results from being filed.
  - `stop()` ends work on sign-out.
  - Evidence links resolve workouts and exercises by kind and parse UUIDs in
    either case.
  - Observations use the account's time zone for "through".

## 2026-10-06: Food search and barcodes for the new nutrition screens (M5d)

Status: open (contract published). Covers PARITY N02 for `NutritionStore`.

- `accountAPI.searchFoods(_:limit:)` returns `DatabaseFoods`: `foods`, which
  are ExerlyCore `Food`s with `source` set to `.openFoodFacts`, and
  `attribution`. Save one with `NutritionStore.saveFood` or log it directly.
  Search when the person submits, not on every keystroke: the database's
  shared budget is small, and an empty result can mean it's busy.
- `accountAPI.food(barcode:)` returns `DatabaseFoods` with one food, or nil
  when the database doesn't know the barcode. A busy or unavailable database
  throws `APIError`; offer manual entry.
- **Attribution.** Open Food Facts is under the Open Database License, so
  show the `attribution` text wherever its foods appear.
- Nutrients come in ExerlyCore's own names and units, as many as the product
  has, and a missing nutrient is unknown, not zero. Values per 100 ml are taken
  as per 100 g: fine for most drinks, not for oils.
- The legacy `/api/food/search` and barcode routes are unchanged for the
  legacy diary.
- USDA FoodData Central waits on Ali's answer about a key
  (`docs/QUESTIONS_FOR_ALI.md`). Search will include it with the same
  interface.

## 2026-10-06: Agents read nutrition and propose meals (M6a, M6b)

Status: open (for whichever milestone builds the nutrition screens).

- **Read tools.** MCP has `get_nutrition_day` and `get_nutrition_summary`.
  Their trend weight and expenditure equal the phone's `EnergyBalance`
  estimate; a live test checks it day by day.
- **Meal proposals.** An agent can propose `food_entry` and `saved_food`
  documents, such as a meal the person photographed. The server checks them as
  ExerlyCore decodes them. To let people accept them, add `NutritionStore` to
  `AgentStore(hosts:)`; your A5 guard shows them as not applicable until then.
  A live test files a meal through MCP, accepts it in `AgentStore`, and finds
  the entry on a second device.
- **Presentation.** `ProposalFieldPresentation` decodes only workouts, so a
  meal proposal's diff would show raw JSON. For a new `food_entry`, the useful
  summary is the food, grams, meal and the energy and macros from
  `FoodEntry.nutrients`.
- **Live tests.** `scripts/live-sync.sh` now runs the API with
  `EXERLY_RATE_LIMITS=off`, honoured only when `NODE_ENV=test`, because the
  suite signs in many synthetic accounts in seconds. If you run the API locally
  for UI tests with many sign-ins, the same pair works there.

## 2026-10-06: Nutrient overview, goals, timing and goal ETA (M5f)

Status: open (contract published). Covers PARITY N06, N28, N29, N31, the
completeness half of N32, and the ETA and checkpoints of S06. See "Insights"
in the README and `docs/design/013-nutrient-insights.md`.

- **Overview (N28).** For yesterday or 7, 30, 90 or 365 days, call
  `overview(from:through:)`. Each row has the average, `observedDays`, the
  goal marker, `shareOfGoal` and `completeness`. A day counts when it has
  entries and isn't partial, or it's fasting. Show `days` and `completeness`,
  so a low average from foods without data isn't read as a deficiency.
- **Goals (N29).** Edit `nutrientGoals` on a new plan version (`savePlan`);
  `validationErrors` explains ordering mistakes. `plan.goal(for:on:)` returns
  the goal in force. Energy and macros come from the daily targets.
- **Timing (N06, N31).** `log(..., at:)` takes the time it was eaten.
  `timing(from:through:timeZone:)` gives 24 hours of energy and entry counts,
  plus `untimedEntries` for entries logged on another day.
- **ETA (S06).** `plan.goal.eta(from: trend, on: today)` and
  `checkpoints(from:on:weeks:)`.
- Pinned nutrients are a display preference, so they're yours to store.

## 2026-10-06: Weigh-ins from Apple Health (Core half of S07/S11)

Status: open (for your Apple Health milestone).

- Read body mass and body-fat percentage with an anchored query. Pass the
  new samples, the deleted sample UUIDs and the account time zone to
  `nutrition.importHealthWeights(_:deleted:timeZone:)`. Each sample becomes a
  `HealthWeight`: the sample UUID, start date, kilograms, body fat in percent
  (Health's fraction times 100) and `HKMetadataKeyTimeZone` when present. Keep
  the anchor yourself.
- The merge is idempotent, and IDs come from Health, so iPhone and iPad
  importing the same samples converge.
- Weigh-ins with `source == .appleHealth` must not be written back to Health,
  and `deleteWeight` refuses them with a message to delete them in Health.
  Weigh-ins typed in Exerly have no source and stay yours to write to Health.

## 2026-10-06: MacroFactor-compatible Shortcuts JSON (Core half of I08)

Status: open (for your App Intents milestone).

So people's existing MacroFactor shortcuts keep working:

- **Log by JSON.** An intent takes the JSON text, a date and a meal and calls
  `nutrition.logShortcutFood(_:on:meal:at:)`. It accepts MacroFactor's format:
  `name`, `source`, `nutrients` by MacroFactor's names, and `serving` as
  `one`, `per100Grams`, `per100ML`, `{amount, unit}` or
  `{amount, label, weight}`. Errors are `ShortcutsJSON.Problem`, whose
  `messages` can be shown as they are.
- **Today summary.** An intent returns `todaySummaryJSON(on:)`: `consumed` and
  `remaining` (minimum, target, maximum, negative once passed) per nutrient,
  as MacroFactor emits it.
- **Find Recent Food.** `recentFoods(limit:)` already exists; return names
  and IDs.
- The spec is public and the implementation is Exerly's own. Its samples
  aren't copied, because the repo has no licence.

## 2026-10-06: The weekly review (Core half of B07)

Status: open (for a review screen).

`WeeklyReview.make(training: store.history, proposals: agent.proposals,
checkIn: try nutrition.checkIn(today:existing:), through: today)` returns at
most three `ReviewItem`s, ranked. Each has a title, a summary, evidence and a
falsifier. A `.proposal` item carries `proposalID`, so open your existing
review screen for it; stalls and the deload signal carry `exerciseIDs` for the
evidence links. The ranking is in `WeeklyReview.swift`: a goal that can't be
kept, then the deload signal, pending check-ins, falling lifts, pending entry
checks, stalls, agents' proposals, and thin logging. IDs are stable within a
week, so store dismissals by ID.

## 2026-10-06: Custom metrics, tags, correlations and n=1 experiments (M7, B08 and B09)

Status: open (contract published). See "Analytics" in the README and
`docs/design/014-analytics.md`.

- **Wiring.** Add `MetricsStore(persistence:)` to `SyncEngine(hosts:)`.
- **Logging.** Custom metrics such as sleep quality or mood, one value per
  day: `metrics.setValue(_:for:on:)`. Day tags: `nutrition.setTags(_:on:)`.
- **Correlations.** `SeriesSources(...).correlations(x, y, from:through:)`
  returns one result per lag, each with ρ, an interval, an adjusted p-value
  and a `verdict`. Show the verdict and the caveat "n=1, observational:
  association, not cause". Below 14 paired days the verdict is
  `.notEnoughData`.
- **Experiments.** Save an `Experiment` with both phases, then
  `analyze(_:)` it. Show the difference with its interval, the verdict and
  every caveat.
- **When someone plans an experiment,** say how long it needs. On realistic
  day-to-day persistence, an effect of one standard deviation is found about
  two times in three with six weeks per phase, and about one in four with
  three weeks.

## 2026-10-06: Volume-labelled foods keep their basis (M5d review fix)

Status: done (logic): answers your 17:54 M5d finding.

- **Server.** A product labelled per 100 ml, or with servings in ml, is no
  longer read as per 100 g. The server converts it with a typical density for
  its Open Food Facts category, such as 0.92 g/ml for oils, 1.36 for syrups
  and honey, and 1.03 for milk. Without a match, it uses water's density and
  says so. The Food carries `volume: VolumeBasis(density:assumed:note:)`.
- **Core.** `Food.volume`, `per100ml`, which gives the label back, and
  `grams(milliliters:)` for an amount poured. `Food.problems` rejects a
  density outside 0.3–3 g/ml, and so does the server's `saved_food` check.
- **Show it.** When `volume?.assumed` is true, show the note beside the
  nutrition, for example "Typical for oils". A serving such as
  "1 tbsp (15 ml)" is already in grams (13.8 g for oil), so `preview` and
  `log` need nothing new.
- **Regression.** The golden now has a synthetic olive oil with density 0.92:
  828 kcal per 100 ml becomes 900 kcal per 100 g. `FoodsGoldenTests` and the
  server's golden test both check it.

## 2026-10-06: A7 previews, and the legacy diary is retired, not bridged

Status: done (logic): answers your 18:12 A7 note.

- **Preview before logging.** `NutritionStore.preview(food, grams:)`, or
  `preview(food, serving:quantity:)`, returns a `LoggedAmount` with
  `grams`, `nutrients`, `serving` and `quantity`. It does exactly what `log`
  records, without saving, and `log` now calls it. Invalid input throws
  `StoreError.invalid(problems)`, with text to show: a zero, negative or
  non-finite quantity, a serving without a weight, no amount, or more than
  100 kg. Nutrients the food doesn't report stay missing, never zero. It is
  `nonisolated static`, so call it on every keystroke.
- **A custom label.** `Food.per100g(fromLabel:servingGrams:)` turns a
  label's amounts for one serving into per 100 g, and throws the same way.
  For a label per 100 ml, set `food.volume` and use `grams(milliliters:)` for
  the serving weight (see the volume note above).
- **The legacy diary and its offline queue: no migration.** The brief says
  nobody uses Exerly yet and legacy code should be deleted. Only test entries
  are in the legacy tables, and Ali's real history comes from the MacroFactor
  import (M5e) and Apple Health. So:
  - The new diary starts empty and writes only `NutritionStore`.
  - Stop writing legacy food, diary-day and weight rows from the new screens.
    Leave the legacy `SyncEngine` running as it is, so anything already
    queued still reaches the server. Don't copy rows across in screens.
  - Nothing is lost. Legacy rows stay on the server and in the account
    export until a later cleanup removes those routes.
  - If Ali wants his test entries carried over, the right shape is a
    server-side, idempotent import, because only the server has the full
    history. I would build it then; it isn't worth building speculatively.

## 2026-10-06: A6 programs review (agent/app-programs at fe2e52db)

Status: done (logic): answers your 18:18 A6 request. Approved; one Core bug
is fixed on my side, and there are two small copy notes.

- **Composition, export and supported kinds: correct.** `ProgramStore`
  shares the SQLite persistence and the `TrainingStore`. It is in
  `AgentStore(hosts:)`, `SyncEngine(hosts:)` and `AccountExport.merging`,
  and `supportsChanges` includes its kinds. Programs therefore sync, export,
  and accept or undo through proposals.
- **Draft stale-save guard: correct.** Comparing `store.program(id)` with
  the value opened works: a program's dates are millisecond-rounded and its
  numbers round-trip through canonical JSON, so a clean save is never
  refused. `ProgramTargetFields` keeps unchanged RIR and rest exactly.
- **Lifecycle preview and confirm guard: correct.** It rechecks the program,
  the current active program and Core's `activeAfter…` before acting.
- **Planned workout: correct.** Starting compares a fresh `nextWorkout` with
  the reviewed plan. The deload label, the outside-range warning, the e1RM in
  kg and the source set link all match Core.
- **Proposal field decoding: correct.** `JSONValue.diff` stops at an array
  whose length changed (for example `days` when a day is added), so the
  day/slot index labels only appear when indices line up.
- **Core bug, fixed in 2f1f3844.** The editor lets someone delete or empty
  the day they last trained. `ProgramSchedule.next` couldn't find it and
  restarted the program at cycle 1, day 1, even restarting a finished one.
  It now continues the cycle at the first training day not done yet, and
  `progress` ignores removed days and cycles. Program validation messages
  now name exercises ("Deadlift has targets for cycle 5, but the program has
  4 cycles") rather than IDs, since your editor shows them. No app change
  is needed.
- **Copy (low).** For a source set without RIR, Core assumes the target's
  RIR. Saying so is more useful than "adjust while logging", for example
  "RIR wasn't recorded for this set, so your target of 2 RIR was assumed."
- **Later (not A6).** Once `NutritionStore` is composed, prefill the planned
  workout's bodyweight from the latest weigh-in instead of asking.

## 2026-10-06: Snapshots keep the volume basis; the first plan; faster logging

Status: done (logic): answers your 18:36 note. On `agent/logic`; I'll land
after A6, as you asked at 18:41.

- **Volume in snapshots (your medium).** `FoodSnapshot.volume` now carries
  the basis, so entries, recents, recipe ingredients and the export keep it.
  `Food.snapshot` copies it. ExerlyCore and the server both check its density
  on entries and on ingredients. A regression logs the synthetic oil straight
  from search, reopens the store, uses the oil in a recipe and exports it.
- **The first plan, at onboarding.** Build a
  `BodyProfile(sex:age:height:weight:activity:)` from the wizard's answers.
  `BodyProfile.Activity` uses the wizard's raw values (`very_active` …).
  Then save:
  `NutritionPlan(startDate: today, goal: …, diet: …, protein: …).computed(from: .formula(profile))`.
  - The formula is Mifflin–St Jeor times the activity factor, with a 15 %
    standard deviation. As the first plan's basis it is also the estimator's
    prior, so check-ins move off it as data arrives.
  - `formula` throws `.invalid` with text to show for an age outside 13–100,
    a height outside 100–250 cm or a weight outside 25–400 kg.
    `computed(from:)` throws for a rate or budget it can't meet.
  - Suggested defaults: lose 0.5 % or gain 0.25 % of bodyweight a week, or
    maintain. The screens choose the goal and do no arithmetic.
  - See "The first plan, at onboarding" in design 011.
- **Faster logging (N04, N07, N09, N12, B01).** All calls are on
  `NutritionStore`, and each batch saves all or nothing:
  - `log([PlateItem], on:meal:)` logs a plate. Each problem names its food.
  - `copy(ids, to:meal:)` and `move(ids, to:meal:)` copy or move chosen
    entries, for multi-select.
  - `logIngredients(of: recipe, serving:quantity:…)` explodes a recipe
    portion into its scaled ingredients.
  - `suggestions(at: now, timeZone:)` returns foods usually logged within 90
    minutes of now over 28 days, with the last amount and meal. Foods already
    logged today and archived foods are left out. `log(suggestion, on: today)`
    is the one-tap repeat. With no suggestions, fall back to `recentFoods`.
  - Copying a whole day now validates too: a blank meal name used to save.
- **Merging into main: not done, and it shouldn't be yet.** `main`
  auto-deploys production, and production still runs the MongoDB API: its
  `/api/health` reports version 1.0.0 with a Mongo `readyState`.
  Integration's API needs `DATABASE_URL`, and Ali hasn't confirmed setting it
  (QUESTIONS_FOR_ALI.md). Merging now would take the live API down. I've
  asked Ali. Until then, TestFlight builds keep using staging, which is
  current.

## 2026-10-06: Gym profiles, and weights the gym really has (M8, T05 and T06)

Status: open (contract published). See "Gyms" in the README and design 016.

- **Wiring.** Add `GymStore(persistence:)` to `SyncEngine(hosts:)`,
  `AgentStore(hosts:)` and the export, as with `ProgramStore`.
- **Editing.** `GymProfile(name:equipment:bars:plates:loads:excluded:)`.
  `loads` lists the weights equipment comes in, such as
  `[.dumbbell: [20, 22.5, …]]` or a cable stack. Save it with `save`, and
  choose a gym with `activate`. `problems` gives text to show.
- **Use it.**
  - Pass `gyms.increments(for:)` to `ProgramStore.nextWorkout(bodyweight:increments:)`.
    Progression then picks only weights the gym has: the test gym's rack
    turns a stepped 32 kg into a real 32.5 kg dumbbell.
  - Use `gym.allows(exercise)` to filter exercise pickers and swaps.
  - Pass the active gym's `bars.first` and `plates` to `WarmUpScheme.sets`
    and `Plates.load`.
- **Without a gym,** everything behaves as before.

## 2026-10-06: Swap an exercise, and keep a workout's changes in the program (T15, P06)

Status: open (contract published). See the README's Store and Programs
sections, and design 006.

- **Swap.** `training.replaceExercise(performedID, with: exerciseID)` swaps
  an exercise in place, before any of its sets is done. It keeps the
  position, superset, program slot, notes, rest, and the number and kinds of
  sets, prefilled from the new exercise's last performance. Once a set is
  done it throws `StoreError.edit(.alreadyStarted(id))`; offer remove and add
  instead. Filter the choices with `gym.allows`.
- **After finishing a planned workout,** call
  `programs.proposal(applying: finished.session, existing: agent.proposals)`.
  If it isn't nil, `agent.file` it and offer the review. It reads, for
  example, "Keep today's changes in Full body? A: Back Squat: 4 sets instead
  of 3; Dumbbell Bench Press instead of Barbell Bench Press; added Barbell
  Curl." Accept and undo work as for any proposal, and the field diff shows
  through your program field labels.
- **Rules.** Skipped exercises stay, the order is kept, and sets in a deload
  cycle without its own targets are left alone.

## 2026-10-06: Generate a program as a proposal (M9, P02)

Status: open (contract published). See "Generating a program" in the README
and design 017.

- **Ask** for days a week (2–6), a goal (hypertrophy, strength or general),
  experience, optional muscles to emphasise, and session length (default 60
  minutes).
- **Then** `agent.file` the proposal from
  `ProgramGeneration.proposal(for:library:gym:)`, passing `training.library`
  and `gyms.active`. Show it in your existing program review. Accepting adds the program without
  following it, and the person can open it in the builder. Show the summary:
  it names any muscle under 80 % of its weekly target, and suggests more days
  or longer sessions when there are several.
- **For a preview before filing,** `ProgramGeneration.generate(...)` returns
  the program with `weeklySets`, `targets` and `shortfalls` by muscle.
- **Validation.** It throws `.invalid` with text to show for days outside
  2–6 or minutes outside 30–150.

## 2026-10-06: Import Hevy and Strong history (I13), and backfill (T20)

Status: open (contract published). See the README section "Importing from
Hevy and Strong" and design 018.

- **Read** the file the person picks (a document picker; both apps export a
  CSV), then call
  `WorkoutImport.parse(text, timeZone: .current, unit: preferredUnit, library: training.library)`.
- **Preview** the number of workouts and their dates, `unmatched` names with
  set counts, `skipped` reasons and `assumptions`. Let the person map each
  unmatched name with your exercise picker (or skip it), then parse again
  with `mapping`. Map before importing: an imported workout isn't changed by
  a later import.
- **Import** with `training.importSessions(result.sessions)`. It returns how
  many were new, and importing the same file twice adds nothing. Sync
  uploads them as usual.
- **Backfill.** `importSessions([session])` also adds a past workout built
  in a "log a past workout" screen, as long as it is finished.
- **Errors.** `.unrecognized(headers)`: "This isn't a Hevy or Strong export."

## 2026-10-06: Barcode symbology for EAN-8 and UPC-E

Status: done (logic): answers your 20:23 A7 finding.

- `account.food(barcode:symbology:)` takes an optional
  `AccountAPI.BarcodeSymbology`: `.upcA`, `.upcE`, `.ean8`, `.ean13`,
  `.gtin14` or `.itf14`. It is sent as `?symbology=`, and the server expands
  UPC-E. The default is nil, as before.
- Map the camera's type once, for example `AVMetadataObject.ObjectType.upce`
  to `.upcE` and `.ean8` to `.ean8`, and always pass it. Without it, an
  eight-digit code throws the server's 400, "Choose EAN-8 or UPC-E for an
  eight-digit code." That is the right text for your manual-entry picker.
- Covered by `FoodDatabaseAPITests` (both formats, and the refusal) and by
  `api.foods.test.js`, which checks that the server expands UPC-E
  `01234565` to `0012345000065`.

## 2026-10-06: Webhooks for agents (B11), shown with access tokens

Status: open (contract published). See design 019.

- Agents and dashboards can now register a webhook with their token. It
  tells them when the change feed moves on, and carries no data.
- In your access-token settings, list `account.webhooks()` under the tokens.
  Show the URL, which token created it (`createdByToken`, matched to the
  token list), the last delivery, and `lastError` with the failure count. A
  disabled webhook should say why. Offer Delete
  (`deleteWebhook(id:)`) and, for a disabled one, Resume
  (`enableWebhook(id:)`). Revoking a token already stops its webhooks.

## 2026-10-06: Design review against Ali's new bar (brief, "Design quality")

Status: open (critique). I reviewed the newest captures:

- A7 diary: `artifacts/nutrition/day-actions-hitarea-attachments`.
- A7 food detail: `library-name-fixed-attachments`.
- A6 Training: `Exerly-Fitness-app-programs/artifacts/programs/builder-live.png`
  and `small-light-current.png`.
- The references: `artifacts/design/references`.

Most are test-journey captures, not the milestone set the brief asks for
(primary screens, light and dark, default and accessibility sizes), so
please produce that set. Against MacroFactor, Apple Fitness and Things 3,
these screens fall short in the same ways:

1. **No summary at the top.**
   - The diary opens with a nutrient disclaimer and a "Logging status" card.
     MacroFactor opens with the day's calories and macros against target.
     Lead with a summary card: calories as a ring or bar against
     `nutrition.targets(on:)`, and protein, fat and carbs as three small
     bars, from `summary(on:)`.
   - Training opens with a stock list of five navigation rows. Lead with the
     next workout from `programs.nextWorkout(...)`: day, cycle, exercises and
     one Start button. Programs, Observations and History move below it.
2. **Repeated empty states.**
   - "Nothing logged" plus "Add food to Breakfast/Lunch/…" in every meal is
     exactly what the brief calls failing.
   - Show a meal header with its total and a + button. Keep empty meals to
     one line.
   - Fill the empty space with `nutrition.suggestions(at: .now, timeZone:)`,
     one tap each, as MacroFactor's "3 PM Picks" do.
3. **Raw numbers.**
   - "123.25 g" and "70.252 kcal" show storage precision. Show whole kcal,
     grams to the nearest gram, macros as whole grams, in a shared rounded
     number style.
   - An entry should be one row: name, then amount below it in secondary
     text, kcal on the right, and "33P · 7F · 0C" shorthand.
4. **Machine dates and grammar.**
   - "Note for 2026-10-06" and "2026-10-06 has 1 food entries" should read
     "Today", or "Mon, 6 Oct", and "1 food".
   - Use one date formatter and plural rules in the design system.
5. **Sheets that are mostly empty.**
   - Day note and the partial-log Confirm fill a whole screen for one field
     or one button. Use a small detent.
   - Day status works better as a segmented control or menu under the
     summary, with undo, than as a confirmation sheet with a paragraph.
6. **Everything looks like a link.**
   - Purple text rows ("Add food to Dinner", "Log this food", "Archive
     food") give primary and destructive actions the same weight.
   - Food detail should lead with nutrition per serving, then one
     prominent Log button with serving presets and a stepper, which
     `NutritionStore.preview` backs.
   - Favourite belongs as a star in the navigation bar. Edit and archive go
     in a menu.
7. **The offline banner** costs a third of the screen at accessibility
   sizes (`small-light-current.png`), and a full-width bar at default. Make
   it a compact status pill that wraps at large sizes, and keep it out of the
   way of the first card.
8. **No shared components yet.** Each screen is a stock List or Form with
   different icon use (some rows have icons, some don't). The brief wants one
   design system:
   - cards, a progress ring, macro bars, meal chips, a quantity stepper and
     empty states;
   - type, spacing and number styles;
   - Exerly's purple and pink on dark, which you kept.

Logic will add anything a summary needs that Core doesn't expose yet; ask in
`to-logic.md`.

## 2026-10-06: Integration and main converged; run npm ci

Status: open (heads-up).

- Ali asked for integration to be merged into `main` at every milestone end
  and at least daily. Done: `main` and integration are both `277aaaef`.
- **The web toolchain changed under integration.** `main` had Ali's
  Tailwind 4, Vite 8, plugin-react 6 and framer-motion 13 upgrades, which the
  merge kept. Integration's web code runs on them: lint, typecheck, build and
  all 67 web e2e tests pass. Run `npm ci` in each of your worktrees after
  rebasing, and use Tailwind 4 syntax for new web classes.
- **CI fix.** `scripts/test-cross-client.sh` used `rg`, which GitHub's macOS
  runners lack. The iOS job failed at the native and browser round trip after
  every UI suite passed (run 37541921912). It now uses `grep -Fq` (`277aaaef`).
- **Production.** The web app on GitHub Pages is now integration's, but the
  production API is still the old MongoDB one until Ali sets `DATABASE_URL`.
  Web sign-in fails there meanwhile; Ali knows.

## 2026-10-06: A lighter workout on poorly recovered days (B05)

Status: open (contract published). See "Recovery" in the README and design 020.

- **Read** sleep, HRV and resting heart rate from Apple Health for the last
  31 days, as `RecoveryDay`s by local date. Each needs its own read
  permission, with a clear purpose string.
- **Assess** with `RecoveryStatus.assess(days, on: today)` when showing the
  next workout.
- **When `.strained`,** show a calm card above the plan: "You may be under-
  recovered: <summary>." Offer "Lighter session" with `plan.lightened()`,
  showing two thirds of the sets at one more RIR, and keep the normal plan one
  tap away. Never apply it silently.
- **With `.notEnoughData`,** show nothing, or a one-line note in settings
  that Exerly needs two weeks of Health data first.

## 2026-10-06: Reading a nutrition label (N15)

Status: open (contract published). See design 021.

- Run Vision text recognition (`VNRecognizeTextRequest`, accurate, with
  language correction off) on the label photo. Pass the recognised strings,
  top to bottom, to `NutritionLabel.read(_:)`. Everything stays on the
  phone.
- **Nil** means the text isn't a label. Say so and offer manual entry.
- **Otherwise,** open your custom-food review prefilled:
  - with `per100g`, save it directly;
  - for a serving label, show `servingText` and use `servingGrams`;
  - when the weight is missing, as with a serving in millilitres or a label
    per 100 ml, ask for it, or set `food.volume`.
- **Flag for the person** each nutrient in `approximated` ("less than" on the
  label) and each line in `unread`.

## 2026-10-07: Existing accounts keep their targets as plans

Status: done (logic): answers your 23:40 "existing target continuity" request.

- **Use** `try await account.adoptLegacyTargets()` once the first sync has
  finished, if `nutrition.plans` is still empty. Then sync again; the plans
  arrive as ordinary `nutrition_plan` documents. It returns how many were
  made, and is safe to call again: it never replaces or recomputes a plan.
- **Server.** `POST /v1/nutrition/plans/from-legacy` turns each accepted target
  version into a manual plan from its effective date, with the same calories,
  protein, fat and carbs, plus fibre as a goal.
  - Onboarding writes one target version, so most accounts get one plan.
  - Without versions, it uses the current legacy targets from the account's
    creation date.
  - The goal, rate, goal weight, diet and protein level come from the legacy
    program, for a later switch to coached mode.
  - It does nothing once the account has ever had a plan, even a deleted one.
  - An audit event records "Exerly" as the writer.
- **Bootstrap field: don't read it for targets.** The authoritative source
  for any date is `NutritionStore.targets(on:)` once the plans exist. The
  bootstrap's `targets` is only the legacy `programs` row, today's numbers
  with no history. The server's own `target_versions`, which the legacy
  summary used, is what the bridge converts.
- **Checked** by `api.legacy-plans.test.js` (the real onboarding route, once
  only, plan or no targets, tokens refused) and by `LegacyPlanTests`, which
  decodes the server's golden plan and finds it valid in Core.
- **For the populated capture,** a fixture account through `/api/user/onboarding`
  plus this call gives real synthetic targets.

## 2026-10-07: Review of the intermediate design captures

Status: done (logic): answers your 22:00 request. I reviewed
`artifacts/design/editors-primary-dark` (diary, training, library) and
`artifacts/design/session-fixed` (the session).

This is a real step up. The diary and Training now lead with one summary card
and a single primary action. The session has a progress card and a docked rest
timer, and the library has a clean row style. What still falls short of the
references:

1. **The diary summary has no progress element.** "70 kcal" with dashes reads
   as a stat, not progress. MacroFactor and Apple Fitness show a ring or bar
   against target. With targets from `adoptLegacyTargets()`, show calories
   as a ring or bar with "x left", and the three macros as bars. Make "No
   targets set for this day" a button that sets them.
2. **Entry rows still show storage precision:** "123.25 g". Round grams to
   whole grams for display; the entry keeps the exact value.
3. **Session wording.**
   - The card title is "Workout"; use the plan or day name ("Pull").
   - "1 of 1 sets" needs a singular.
   - The set row shows load and reps but not the target RIR, which the
     plan carries.
4. **Library header.** "Food library" in the bar and "Your foods" as a large
   title say the same thing twice. "Saved labels. Ready whenever you are." is
   marketing copy in a tool.
   - Keep one title.
   - Fill the empty half of the screen with Recent (`recentFoods`) and the
     time-of-day picks (`suggestions(at:timeZone:)`).
5. **Training's last session** shows only "Deadlift". A line with sets,
   volume or a PR (`summary(of:)`, records) would earn its space.
6. **Day status** is a full card competing with the meals. It would sit
   better as a compact control under the summary, with Note and Copy day in
   the meal header menu.

None of these needs new Core. Points 1 and 4 use calls that already exist.

## 2026-10-07: U.S. defaults, "kcal left", Program screen continuity, conflict views

Status: done (logic): answers your 00:19, 01:18 and 01:44 notes.

- **U.S. by default (Ali, 01:18).** A new account, onboarding and the agent
  tools now default to `imperial` when no unit was chosen. An explicit metric
  choice and every stored kg, cm and ml value stay as they are. Calories stay
  kcal, macros grams.
- **`USUnits`** (Core) gives exact conversions:
  - `milliliters(fluidOunces:)` and `fluidOunces(milliliters:)`;
  - `wholeMilliliters(fluidOunces:)` for water. It rounds to the nearest ml,
    halves away from zero, so 8 fl oz is 237 ml, and every whole amount from 1
    to 200 fl oz shows back exactly at 0.1 fl oz;
  - `centimeters(feet:inches:)`, and `feetAndInches(centimeters:inchStep:)`,
    which carries 12 inches to a foot.
- **"Kcal left."** `nutrition.progress(on: date)` returns a `DayProgress`.
  Energy and each macro have `consumed`, `target`, `remaining`, `over`,
  `fraction` for the bar, and `unreported` (entries that don't give that
  nutrient, so say the total may be low). Show "x left", or "x over" when
  `over > 0`.
- **Program screen continuity (your P1).** When the legacy Program or Goals
  screens accept new targets, the server now adds a manual plan version with
  the new numbers, from that date. It does so only while the plan in force
  is one the bridge made. Once the person sets a plan in the app, the Program
  screen no longer writes plans. Covered in `api.legacy-plans.test.js`. So
  you can call `adoptLegacyTargets()` and retire the read-only fallback.
  - On your fallback meanwhile: the legacy summary's targets come from
    `target_versions` by date, so past days are right.
  - Days before the first version come back `not_recorded`; show no target
    then rather than today's.
  - Keep the Core plan winning only for dates on or after its `startDate`.
- **Conflict views.** On integration, five screens still open the old
  `SyncIssuesView` (Home, Measurements, LogActivity, LogSleep). You may delete
  `SyncIssuesView` and `SyncConflictView` from
  `Exerly/Core/Services/SyncEngine.swift` (the two structs at the end of the
  file, nothing else) in the commit that switches those call sites to
  `SavedChangesReviewView`.
- **Gallery.** I'll do the final critique once your refreshed captures settle.

## 2026-10-07: CI on main: one UI typing flake

Status: done (app): verified/retried typing landed b7b082b7 on integration at 03:18 EDT; complete native suite passes.

`main` CI run 37569162426 (`3425db1d`):

- unit tests passed (133, 1 skipped), and so did 36 of 37 UI tests;
- `testProgramBuilderPersistsOfflineAndFinishedWorkoutsAdvanceThePlan` failed at
  `ProductionUITests.swift:2325`. The program name field read "Two-day streng",
  not "Two-day strength": the CI simulator dropped the last keystrokes. That one
  test also took 1548 s.

Typing on GitHub's slower simulators drops characters. Please type and then
assert-and-retype, or paste the value. The test's length suggests waits that
time out before passing; worth a look. The native and browser round trip never
ran, because this step failed first. Its Vite and `rg` fixes are in.

## 2026-10-07: CSV exports and importing an export (I14)

Status: open (contract published). See design 022.

- **In account settings, next to the JSON export,** offer "Export as
  spreadsheets". Call `account.exportCSV(file)` for each `CSVExport` case and
  share the files, or offer them one by one. Nutrients that a food doesn't
  report are empty cells, not zeros.
- **"Import an Exerly export"** reads a JSON file from the document picker
  and calls `account.importExport(data)`. Show `imported`, `kept` (already
  here) and any `skipped` reasons, then sync. Importing twice is safe.
- The live tests cover a round trip between two accounts through the
  client.

## 2026-10-07: Sync P1 fixed; food units, recipes and entry corrections

Status: in progress (app): reconnect regression committed and passes 1.584 s; combined Sync screen is in the final native suite. Food contracts queued for the next nutrition milestone.

**Sync (P1).** `SyncEngine.synchronize` now clears `error` after a successful
account-owned pull. It also clears `isOffline` and sets the new
`lastSyncedAt: Date?`, unless a queued change failed to send in that run; that
change keeps the app offline until it sends. A pull that fails with a network
error or a 502/503/504 sets `isOffline`. Your stashed
`testLegacySyncClearsOfflineFailureAfterSuccessfulPullWithNoPendingWrites`
passes against it (1.76 s). I didn't commit it: please land it from your stash.
Use `lastSyncedAt` for "Last synced" on the Sync screen.

**Food in ounces and millilitres.**

- `USUnits.grams(ounces:)` and `ounces(grams:)` are exact (`gramsPerOunce`,
  the same factor as ShortcutsJSON). Convert, then call
  `NutritionStore.preview` with grams; validation stays there.
- `VolumeBasis.grams(milliliters:)`, `VolumeBasis.milliliters(grams:)` and
  `Food.milliliters(grams:)` (nil without a volume basis). To reopen an entry
  in millilitres: `entry.food.volume?.milliliters(grams: entry.grams)`.

**Recipes (N11).**

- `Food.recipe(name:ingredients:yieldGrams:servingCount:preparation:...)`.
  `servingCount` and `preparation` are optional fields of the recipe.
- `recipeGrams`: the cooked weight, or the ingredients' total without one.
  `recipeServing`: "1 serving", an equal share of `recipeGrams`. It follows
  edits, so don't copy it into `servings`; offer it first when logging.
- `withIngredients(_:yieldGrams:)` for adding, removing, reordering or changing
  ingredients: it recalculates `per100g` and keeps everything else. Use it
  rather than setting `ingredients` yourself, because `saveFood` doesn't
  recalculate.

**Correcting one entry's nutrients (N08).** A specific field, not
`source = custom`, which would lose the database attribution:
`entry.editingNutrients(amounts)` takes the nutrients for the logged amount and
returns the entry with `food.edited == true`. Its food ID, source and the
library food are unchanged. A later change of amount scales the corrected
values. Save it with `saveEntry`, and show a small "Edited" mark on it.

The API checks `edited`, `servingCount` and `preparation` on agent writes.

## 2026-10-07: Final design critique

Status: in progress (app): all applicable findings implemented at 63b42c54, device build/scoped lint pass. Default/AX journeys and refreshed captures run from fixed 0a15b7fe. I14 follows the design release.

I reviewed 20 captures in large dark: Train, workout and set editor, planned
workout, program editor, suggestions, Account, Sync and agents. Several came
from runs before your 03:40 fixes. For example, the duplicate chevron still
shows in the 12:43 suggestions-inbox capture. Skip anything you've fixed since.
In order of importance:

1. **Volume reads "4188.783 lb·reps"** on Train's last session (04:19
   capture) and in workout history. `TrainingFormat.number` keeps three
   decimals and doesn't group thousands. Show whole numbers, "4,189 lb", and
   label it "Volume" as MacroFactor Workouts does.
2. **Planned sets repeat.** Each identical set takes three lines ("Set 1 ·
   Working / 60 kg × 6 reps / Target 2 RIR"), under a summary that already
   says "3 sets · 5–8 reps · 2 RIR" (program-estimate-summary,
   program-next-preview). Use a compact table, one row per set: Set, weight,
   reps, RIR. Cut the "All sets start incomplete…" footnote and shorten the
   bodyweight explainer. Check that the "Bodyweight (kg, optional)" label
   follows the U.S. default.
3. **The em-dash placeholder looks like a loading bar.** Reps in the set editor
   and calories on the empty diary show a long "—". Use a muted "0", or the
   field's name, as the placeholder.
4. **Program editor rows.** Icon and Color each take two rows, with the label
   above the value. Use one row with the value trailing, as "Expires after"
   already does. The purple "Edit" row in "Days in each cycle" reads as
   content: put the edit button in the section header or toolbar. Text from
   the scrolled title ("…cycle") shows behind the sheet's toolbar.
5. **Validation message.** "Could not save / a program needs a training day"
   appears at the bottom, after Save, in lower case. Core's problem strings are
   lower-case fragments meant to be joined. Capitalise one shown alone, and put
   it in the Days section, or disable Save with that hint.
6. **Suggestion diff.** Before and after are two plain lines ("Before: 1500 kg
   / After: 150 kg"). Make the change the hero, "1,500 → 150 kg" with the old
   value secondary, and put it above "Read original/proposed program". Shorten
   "Day 1 · Pull · Deadlift · Base targets · Reps in reserve" to a "Pull ·
   Deadlift" title and a "Reps in reserve" label. Evidence labels "Anecdote"
   and "n=1" are jargon: say "Your note" and "1 workout".
7. **Account exports.** Two export actions with a paragraph each, and the
   filled purple button, make export look like the screen's main task. Use one
   "Export data" row. When offline, export from the device automatically and
   say what's left out. Put "Export as spreadsheets" and "Import an export"
   (I14) in the same group. The Sync screen's card says "BACKUP": pick one
   name.
8. **Connected agents.** "Connected agents" appears three times: the
   navigation title, the card's label and a section header. Drop the card's
   label. In the empty state, "No connected agents" repeats the hero; remove
   it. The endpoint shows the fixture's 127.0.0.1; make sure a release build
   shows the configured API's address.
9. **Connect an agent.** "Create access token" is a plain row at the bottom.
   Make it the toolbar's confirming action, or a filled button. The agent's
   name reads as a title, not as a field you can edit.
10. **Captures to redo.** training-home shows the Diary, and
    account-live-export-options is identical to account settings: no options
    sheet appears.

What works: Train's "Next up" card with one action, the set keypad with a large
value and ± steppers, the rest bar, the Sync status card with its time, the
delete confirmation, and the original purple, pink and pulse logo.

## 2026-10-07: Server data flows for the privacy review; generate_program

Status: done (app drafts): native versus legacy caching, logs, Gemini and webhooks incorporated into docs/release. Ali decides publication/declarations.

I checked your privacy review against the API source at this commit. Changes
to the draft:

- **Food search isn't cached.** The native app's `/v1/foods/search` and
  `/v1/foods/barcode` go straight to Open Food Facts and keep nothing. The
  provider budget counts requests per minute, with no search text, and drops
  counts after a day. Only the legacy web route `/api/food/barcode` caches
  products in `barcode_cache`, keyed by barcode alone. That cache has no
  account or person in it, lasts 7 days, and serves stale entries up to
  30 days old when the provider fails. FatSecret is used only by that legacy
  route, and only when its keys are configured. Replace "temporary shared
  search cache" with this.
- **Logs.** The API logs only errors: the method, the path without its query
  string (so no search text), and the error. Rate limiting keeps IP addresses
  in memory for its window and never writes them down. The legacy Gemini coach
  (`/api/ai`) is different. When `GEMINI_API_KEY` is set, it sends the
  person's messages and context to Google. Its `ai_errors` table stores email,
  user ID, IP address and user agent with each failure. Deletion removes those
  rows; the export leaves them out. The native shell doesn't reach that route,
  but the web app may, so the notice must disclose it or it must be switched
  off. Ali decides (QUESTIONS_FOR_ALI.md). DigitalOcean's own request logging
  and retention need confirming in its console; I can't see them from the
  repo.
- **Webhooks.** These are user-directed, like agents. A POST carries only a
  sequence number and a signature, never data. The receiver reads changes with
  its own token. The webhook's URL and secret are stored with the account.
  Deletion removes them; the export leaves out the secret.
- **Agents.** Your table is right. The audit log keeps which token filed or
  wrote each change, and deletion removes it with the account.
- **Production today** is still the old Mongo API (v1.0.0). Everything above
  describes the new API on staging. Hosting, database and backup answers wait
  on the cutover (QUESTIONS_FOR_ALI.md).

**`generate_program` (MCP).** An agent can now ask for the program your builder
would make. It gets the person's active gym, the program document, weekly sets
against targets, the short muscles, and a ready-to-file proposal with
the same summary, evidence and falsifier as `ProgramGeneration.proposal`. It's
held to Swift by `docs/api/golden/program-generation-v1.json` (289 cases).
No app change is needed; a program it proposes shows up in Suggestions like
any other.

## 2026-10-07: `main` advanced to `cc1de145`; one UI test failed on the last run

Status: open (app test).

`main` CI run 37580092392 (`ad767e2a`) passed every unit test (144, 1
skipped) and 36 of 37 UI tests. The failure was
`testReminderDeviceDeliverySchedulesCancelsAndSurvivesRelaunch` at
`ProductionUITests.swift:2184` (on that commit). The springboard never showed
"Sleep reminder" within 150 s; the test took 1,770 s. A local notification
banner on GitHub's slow simulator may arrive late or be coalesced into
Notification Center. Consider checking the delivered notification through
`UNUserNotificationCenter` in the app instead of the springboard banner, or
marking the banner check optional on CI as you did for other device-only
checks. The native and browser round trip didn't run, because this step
failed first.

`main` is now fast-forwarded to integration `cc1de145`, which includes your
typing fix and both of today's logic pieces. CI run 37596317204 is running on
it. I cancelled the duplicate integration run for the same commit, so the
single macOS runner goes to `main`'s run.

## 2026-10-07: Health readers that tell no samples from zero

Status: done (app): 0a15b7fe adopts both nullable readers and tests nil versus measured zero. Full hosted suite passes; obsolete reader removal is noted in to-logic.

`HealthKitService.stepsToday()` and `activeCaloriesToday()` return `Int?`.
They return nil when Health shows no samples today and 0 for a measured zero.
Health doesn't reveal refused reads, so nil means "none visible", not
"denied". Your `HealthReadModel.load` can use them and drop the `> 0` guess.
The old `fetchStepsToday()` and `fetchActiveCaloriesToday()` still return
zero for nothing and now delegate to the new ones; tell me when nothing calls
them and I'll remove them. `requestAuthorization()` in that file still asks
for sleep and workout writes. Your model no longer calls it, so I'll remove it
too once you confirm nothing else does.

## 2026-10-07: Sync status no longer carries over between accounts

Status: open (app: add the regression below if you want it in your suite).

Your P2: in the legacy `SyncEngine`, `configure` for another account and
`purge` of the configured account now reset `error`, `isOffline` and
`lastSyncedAt`. The new account's first sync sets them again. I verified it
with this hosted test, which I didn't commit because ExerlyTests is yours:

```swift
func testLegacySyncStatusIsNotInheritedByAnotherAccountOrKeptAfterPurge() async throws {
    keychain.saveSession(token: "e30.eyJzdWIiOiJhIn0.fixture", refreshToken: "fixture-refresh")
    let container = try ModelContainer(for: Schema(versionedSchema: ExerlySchemaV3.self),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let engine = SyncEngine(api: api, monitorNetwork: false, automaticallySync: false, observeClock: false)
    let synced = { (_: URLRequest) in (200, Data(#"{"changes":[],"cursor":0,"has_more":false}"#.utf8)) }
    engine.configure(container: container, accountID: "a")
    StubURLProtocol.handler = synced
    await engine.synchronize(force: true)
    XCTAssertNotNil(engine.lastSyncedAt)
    StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
    await engine.synchronize(force: true)
    XCTAssertTrue(engine.isOffline)
    XCTAssertNotNil(engine.error)
    XCTAssertNotNil(engine.lastSyncedAt, "the last success is still the last success")

    engine.configure(container: container, accountID: "b")
    XCTAssertNil(engine.lastSyncedAt)
    XCTAssertFalse(engine.isOffline)
    XCTAssertNil(engine.error)

    engine.configure(container: container, accountID: "a")
    StubURLProtocol.handler = synced
    await engine.synchronize(force: true)
    XCTAssertNotNil(engine.lastSyncedAt)
    try engine.purge(accountID: "a")
    XCTAssertNil(engine.lastSyncedAt)
    XCTAssertFalse(engine.isOffline)
    XCTAssertNil(engine.error)
}
```

Staging's deployed API files match `f7b92d41`, which includes `0580fe3b`'s
food validation.

Health: integration's `ProfileView` (lines 244 and 257) still calls
`fetchStepsToday`, `fetchActiveCaloriesToday` and `requestAuthorization`, so
I'll remove them, and the unused `saveWorkout`, after your branch lands.

## 2026-10-07: Generic foods in search; a correction to the privacy notes

Status: open (app: nothing required; check the search screen with real queries).

**Generic foods.** `/v1/foods/search` now returns plain foods from a bundled
USDA table (FNDDS, 5,431 foods, public domain) first, up to half the results,
then Open Food Facts products. "banana" gives "Banana, raw" with "1 banana" =
126 g; "salmon" gives "Fish, salmon, raw"; "ground beef" gives "Beef, ground,
raw". They're ordinary Foods: `source` `usda`, IDs `usda:<fdcId>`, nutrients
per 100 g. Nutrients FNDDS doesn't measure (amino acids, added sugars,
manganese and a few more) are absent, not zero. The attribution string now
credits USDA when generic foods are shown. Generic results come back even
when Open Food Facts is down. No app change is needed, but the search screen
should show `source` so a person can tell "Banana, raw" from a branded
product. Design 023 has the details.

**Correction.** I told you food search kept nothing. That was wrong: the API
keeps the last 200 Open Food Facts search texts and their results in memory,
reused for 5 minutes. They're linked to no account or person, never written
to the database, and gone on restart or when newer searches push them out.
Generic results are looked up locally, so those searches don't reach any
provider. Please correct docs/release.

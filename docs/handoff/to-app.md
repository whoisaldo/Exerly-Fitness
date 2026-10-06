# Inbox: app agent (Astra)

Written by the logic agent (Claude). Each item: date, title, what's needed or what changed, status
(open, in progress, done). Mark items done; never delete them.

## 2026-10-06: ExerlyCore training interface published

Status: open (for you to link and build on).

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

Status: open (switch when you link ExerlyCore).

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

Status: open (no action needed yet).

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

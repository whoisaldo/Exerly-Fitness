# Engineering decisions

## 2026-10-06: PostgreSQL foundation

Replace MongoDB with PostgreSQL and the `pg` driver. Keep route response shapes
during this milestone so the existing native offline queue can be tested against
the new database. Use relational columns for identifiers, ownership, dates,
numbers and revisions. Use JSONB only for existing structured snapshots.

Commit numbered SQL up/down migrations. Do not generate production schemas from
JavaScript at startup. Check migration checksums and serialize migration runners
with a PostgreSQL advisory lock. Ordinary API startup applies pending migrations
before accepting requests. Rollback is a separate operator command.

Use one checked-out connection for each transaction. Serializable transactions
retry conflicts from the beginning with a bounded retry count. Mutation receipts,
entity changes and sync cursors commit together. Add concurrency, rollback,
migration and restored-backup tests on real PostgreSQL.

Keep account filters explicit and test adversarial cross-account requests. RLS is
not adopted in M1 because the current schema mixes account IDs and email owners,
and authentication/admin maintenance require separate access policies. New tables
use account IDs. Database foreign keys and an ownership audit accompany later
conversion of the email-owned tables. Do not claim RLS protection.

The web dashboard is outside the product scope. Preserve its source and historical
evidence, but remove its deployment and required CI work after recording the first
baseline. Native tests and PostgreSQL integration tests become the release gate.

Production cutover requires Ali's Neon project and DigitalOcean `DATABASE_URL`.
Do not merge a deployment configuration that cannot boot before that prerequisite
is satisfied. Continue native and local database work on branches meanwhile.

References: [node-postgres transactions](https://node-postgres.com/features/transactions)
and [PostgreSQL isolation](https://www.postgresql.org/docs/16/transaction-iso.html).

## 2026-10-06: ExerlyCore holds training logic

The training domain lives in `apps/ios/ExerlyCore`, a dependency-free Swift 6
package tested with `swift test`, so logic needs no project-file edits and no
simulator.

- The exercise library is a bundled JSON file, so the API and MCP server can read
  the same data later.
- e1RM uses Brzycki up to 10 reps to failure and Epley above, which meet exactly
  at 10.
- Sets per muscle are fractional: 1 for a target muscle, 0.5 for a synergist.
- One side of a unilateral exercise counts as half a set.

Details and measured error are in `docs/design/002-exerlycore-training.md`.

`docs/AGENT_BRIEF.md` is excluded from Prettier. The brief is Ali's, and the
pre-push format check failed on its list spacing. Agents may not reformat it, so
it is ignored rather than edited.

## 2026-10-06: PostgreSQL behind the existing storage adapter

M1a keeps the route layer and the `apps/api/data` interface, and adds a PostgreSQL
driver. That kept every existing test as a regression check: all 153 pass
unchanged except the one that named the driver.

**Schema.**

- `db/migrations/0001_initial` creates one table per registry collection, with
  typed columns.
- Legacy camelCase columns are quoted, so their case survives.
- Every row has a UUID `id` and a `seq` identity. Callers that sort by id get
  insertion order, as they did with SQLite row IDs.

**Transactions.**

- They run `SERIALIZABLE`.
- Serialization failures, deadlocks and unique-index races retry from the
  start, up to five attempts.
- Every authenticated mutation already runs inside `executeMutation`, and no
  mutation handler calls an external service, so retries never repeat a side
  effect. AI routes are excluded and use their own reservation flow.

**Health.** `/api/health` reports pool state without querying the database, so
platform health checks don't keep a scale-to-zero database awake.

**Retired drivers.**

- MongoDB and its driver are removed.
- The SQLite driver stays only for the app agent's isolated simulator fixture
  (`scripts/ios-fixture-api.cjs`). `sqlite3` moved to devDependencies. It goes
  once that fixture runs on PostgreSQL.

**Deployment.**

- The API ships as a non-root `node:22-bookworm-slim` image that migrates before
  it listens.
- `docker-compose.yml` runs PostgreSQL 16 and the API for self-hosting.
- `.do/app.yaml` now builds that Dockerfile and expects `DATABASE_URL`.
- Production must not be redeployed from `main` until Ali sets `DATABASE_URL`.

**Devbox tooling.** Colima's existing default profile is used for Docker. The
`docker-compose` CLI plugin was installed with Homebrew. Colima is stopped again
after container checks.

## 2026-10-06: Sign in with Apple and account lifecycle

- **Verification.** Apple identity tokens are verified on the server against
  Apple's published keys: RS256 only, Apple as issuer, our bundle ID as audience,
  unexpired, with nonce = SHA-256(raw nonce). Each nonce is stored for a day, so a
  captured token can't be replayed.
- **Linking.** Apple sign-in never attaches to an existing password account by
  email unless that email was verified. Exerly doesn't verify emails yet, so such
  people get `link_required` and connect Apple from a signed-in session. This
  blocks takeover through a pre-registered, unverified address.
- **Hidden emails.** When Apple hides the email entirely, the account gets
  `apple-<hash>@users.exerly.invalid`. The legacy tables are keyed by email.
- **One ownership map.** `lib/ownership.js` drives account deletion and export,
  and a test fails if any table lacks a rule. Deletion runs in one transaction.
- **Revocation.** Apple token revocation happens before deletion. It uses a fresh
  authorization code exchanged at deletion time, so no Apple refresh tokens are
  stored. It needs a Sign in with Apple key from Ali; see QUESTIONS_FOR_ALI.md.
- **Sessions.** New sign-in paths always issue protocol 2 sessions: 15-minute
  access tokens and rotating refresh credentials.

## 2026-10-06: Document sync for ExerlyCore

- **Unit of sync.** ExerlyCore entities sync as whole documents, with server
  revisions, stale-base conflicts, idempotent writes and tombstones
  (`/v1/documents`), plus a document view of the shared change feed
  (`/v1/changes`).
- **Derived dirtiness.** The client marks nothing dirty. A document needs
  pushing when its canonical JSON (sorted keys, millisecond ISO dates) differs
  from the last acknowledged version. A crash between a save and a dirty flag
  therefore cannot lose a change, and no cross-table transaction is needed.
- **Push keys.** Each push key is tied to the content and the base revision. A
  lost response is retried with the same key and replays; a merged version gets
  a new key.
- **Merging.** Conflicts merge three ways, so sets logged on two devices both
  survive:
  - whichever side changed a field wins, and local wins when both did;
  - lists merge by ID, with additions from both sides kept;
  - a deletion applies only to an item the other side left unchanged.
- **Dates.** The store creates every date at whole milliseconds, so wire
  round trips are exact.
- **Server validation** checks the kind, the ID, that the payload is an object
  and that its `id` matches, plus each kind's essential fields. It does not
  reinterpret payloads. A JSON Schema shared with the Swift tests is due before
  the MCP server reads documents.
- **Forward compatibility.** An older client that pushes a document drops fields
  it doesn't know. Acceptable while there are no old clients; revisit before
  public release.

## 2026-10-06: Staging on devbox1

The staging API runs on devbox1 until production moves to PostgreSQL, under one
LaunchAgent (`com.aldo.exerly-staging`), following the devbox recovery README.

- **Code.** A deployed copy runs from `~/Services/exerly-staging`; LaunchAgents
  can't read `~/Desktop`.
- **Database.** A private PostgreSQL cluster on a Unix socket with no TCP port.
- **Network.** The API binds to `0.0.0.0` on logic scratch port 39110 and is
  reached at `http://100.80.149.7:39110`.
- **Recovery.** It is an advisory check in `~/Services/devbox-recovery/check.py`,
  so it never fails Ali's required startup checks.
- **Scripts.** Install and uninstall scripts live in `apps/api/deploy/staging/`.

## 2026-10-06: Personal access tokens

- **Format.** `exr_` plus 32 random bytes in base64url. Only a SHA-256 hash is
  stored, and the token is shown once.
- **Scopes.** `read` (every token), `propose` and `write`.
- **Reach.** Tokens reach only `/v1/*` and `/mcp`. Token management, sessions,
  identities, passwords, legacy `/api/*` routes and account deletion refuse them.
- **Proposals.** A token can file only new pending proposals. The server stamps
  the token's identity as the author, so an agent can't pose as the person or as
  Exerly, and only a signed-in session can decide.
- **Audit.** Every token write and filed proposal appends a server-written
  `audit_event` document in the same transaction, so the log reaches every
  device. Token creation and revocation are audited too.
- **Limits.** At most 20 active tokens per account. Last use is recorded at most
  once a minute.

## 2026-10-06: Preserve Exerly's existing brand

Ali rejected the unrelated mint monogram in the first internal build. The app
keeps the established purple E/pulse mark from apps/web/src/components/Assets/
ExerlyLogo.jpg. The app icon uses that symbol alone so it remains legible at home
screen size. Restore purple/pink brand accents and neutral purple-tinted surfaces;
retain adaptive light/dark colors, Dynamic Type and native controls. The green
palette introduced in A2 is superseded. No new brand direction is being adopted.

## 2026-10-06: Web CI job removed

The `web` job is gone from `ci.yml`, as the brief allows and both agents agreed
(to-logic.md, "A2 regression green"). The web sources stay, and so does the
cross-client step in `ios-tests`, which the app agent owns. Required CI now
covers the API, ExerlyCore, SwiftLint, the iOS build and tests, and workflow
lint.

## 2026-10-06: One session owner in the app

The app's legacy `APIClient` stays the only owner of the session: it signs in,
refreshes and stores credentials. ExerlyCore talks to the server through
`SessionTransport`, which `APIClient` implements, and `AccountAPI` binds every
document and account request to one account ID. Two refresh implementations
sharing rotating tokens would race, and a second session would leave the
legacy screens signed out. `ExerlyAPI` remains a standalone owner for tests,
scripts and future targets.

- A sign-in or sign-out starts a new session generation; nothing begun under an
  older one saves credentials or returns a response.
- `SyncEngine.shutdown()` stops sync and waits for it before an account is
  signed out, switched or deleted.

## 2026-10-06: The SQLite API driver is removed

PostgreSQL is the only database, in tests, the simulator fixture, staging and
production. The SQLite driver (`DB_MODE=local`) was kept only for the iOS
fixture. The fixture moved to a throwaway PostgreSQL cluster, and the app agent
approved the removal. `sqlite3` and `cross-env` left the API's dependencies with
it.

## 2026-10-06: Deleted accounts are recognisable

A request carrying a session token this server signed, even an expired one, for
an account that no longer exists gets 401 with code `account_deleted`. Only the
account's own tokens can learn it, so nothing is revealed to anyone else. A
client whose deletion response was lost can then tell the deletion happened and
remove the account's data from the device.

## 2026-10-06: UUID document IDs are uppercase

A document ID that is a UUID has one canonical form, uppercase, which is what
`UUID.uuidString` gives and what ExerlyCore always wrote. The API stores and
returns that form for document IDs and for the IDs proposals and audit events
refer to, and migration 0005 converts existing rows. ExerlyCore's `SyncEngine`
reads remote IDs and its own saved sync bases in the same form. Before this, a
lowercase ID written by another client became a second server document when a
device synced it. Other IDs, such as custom exercise IDs, stay as written.

## 2026-10-06: IDs inside payloads are canonical too

Migration 0006 gives the IDs inside stored and change-feed payloads the same
uppercase form: a payload's own ID, a proposal's change IDs and the documents
in them, its evidence references, and an audit event's targets and proposal.
`canonicalPayload` in `apps/api/lib/documents.js` applies the rule to every
write, and the migration mirrors it in SQL; a test checks that they agree.
ExerlyCore's `ProposedChange` and `DataRef` keep a UUID ID in uppercase however
it arrived, so a proposal stored before the fix can still be accepted and
undone.

## 2026-10-06: Expenditure follows weight in the estimator

`EnergyBalance` now moves expenditure 22 kcal a day for each kilogram of trend
weight gained or lost (Hall et al., 2011), on top of its random-walk drift.
As a pure random walk, the estimator lagged a diet's falling expenditure: in
simulated dieters it read 171 kcal high at a 1 % weekly loss, so check-in
targets undershot the goal. With the coupling, M5b's mean expenditure error
fell from 90 to 74 kcal with daily weigh-ins, and from 114 to 97 kcal with
weekly ones. The coefficient is a parameter, `expenditurePerKilogram`.

## 2026-10-06: Nutrition plans are versioned, and check-ins are proposals

A `nutrition_plan` version never changes once it starts, so any past day's
targets are the ones that held then. A weekly check-in is a built-in proposal
that adds a version, with the expenditure band, the week's trend and logging
coverage as evidence. A check-in whose new targets would break the 1,200 kcal
floor or the protein and fat minimums proposes nothing and says why, instead
of silently slowing the goal.

## 2026-10-09: The Xcode project is generated, with synchronized folders

`apps/ios/project.yml` is now the source of truth for `Exerly.xcodeproj`;
regenerate with `xcodegen generate` in `apps/ios`. The app and both test
targets use synchronized folders, so adding, moving or deleting a Swift file
needs no project change. Several agents can now build screens in parallel
without serialising on `project.pbxproj`. The generated project stays committed
so CI and the release script need no extra tool. Build settings were diffed
before and after: only the deployment target changed.

## 2026-10-09: iOS 26 is the minimum

Exerly now requires iOS 26. Nobody uses it yet, and the redesign builds on iOS
26 directly: the Liquid Glass tab bar, a search-role tab for logging from
anywhere, and a tab bar accessory for the live workout. Supporting older
systems would mean a second, plainer version of every primary screen.

## 2026-10-09: Confetti removed

`ConfettiView` was only reachable through an onboarding flag that nothing set.
It is deleted, consistent with the no-confetti principle.

## 2026-10-09: Today replaces the Diary, and the Library tab goes

The app opens on Today: the day's calories and macros against targets, the
foods usually eaten at this time with a plus that logs each in one tap, today's
workout with Start, and the meals, each with a one-tap repeat of the last time
it was logged. Measured on the simulator: a usual food, a repeated meal and
starting the planned workout each take one tap from launch.

The tabs are now Today, Train, Progress and Profile, plus an iOS 26 search tab
that opens food search from anywhere. The Library tab is removed: recents and
favourites already lead the food search, and the saved-foods manager moved to
Profile → Foods & recipes. The status menu ("In progress") became a single
"Mark this day complete" control, because complete days are what the
expenditure estimate uses. The week strip is the last seven days, so yesterday
is always one tap away.
## 2026-10-09: Today's workout starts from the Train tab without questions

Train → Start begins the active program's next workout in two taps from the
home screen. Removed along the way:

- The planned-workout review sheet's bodyweight field, and the "New workout"
  sheet that asked for a name and bodyweight. Bodyweight now comes from the
  latest weigh-in (or stays empty) and can be changed in the workout's
  details. An empty workout starts at once, named for the time of day, and is
  renamed from the workout menu. The review sheet stays as Preview.
- The set editor sheet for routine edits. Weight, reps and RIR are edited in
  place in each exercise's set grid with the training keypad, whose steppers
  follow the gym's plates. A change carries to later incomplete sets that
  still held the old value. The sheet remains under a set's "More options"
  for drops, myo continuations and sides.
- The red "Discard workout" row, now in the workout's overflow menu.
- The four large rows on the Train home (Programs, Gyms, Suggestions,
  Observations) and the Exercise library and history card, merged into one
  compact "Plan and tools" list. Observations is renamed Insights.
- Rest "+30 s", replaced by −15 and +15 on a floating rest bar.

Finishing a workout now shows a summary with time, working sets, volume and
any personal records.

## 2026-10-09: Releases sign in the user's session

Agent shells on devbox1 can run in a Background launchd session, where macOS
consults only the System keychain domain. There Xcode can't see the signing
identity that `release.sh` imports into its temporary keychain, and archives
fail with "No signing certificate". `apps/ios/scripts/release-in-session.sh`
runs the unchanged `release.sh` as a transient job in the logged-in user's GUI
session. That job can't read `~/Desktop`, so the committed `apps/ios` is
exported to `~/Library/Caches/exerly-release/<build>` first, which also means
every build comes from a commit. Nothing about certificates, profiles or the
keychain handling changed.

## 2026-10-09: CI runs unit tests and tap budgets; the full UI suite runs locally

The iOS job ran every UI test on one GitHub runner, took over three hours, and
never finished green. CI now runs the unit tests and the Today tap-budget tests
within an hour. The full UI suite runs locally before each landing, sharded
across simulators with one fixture each. The browser round-trip step went with
it, since the web dashboard is out of scope.

## 2026-10-09: Milestones removed; Progress gains Nutrition and Training

Progress is now Body, Nutrition, Training and Photos. The Milestones tab and
its unused achievement service are removed: badges for activity are the
motivational filler the brief rules out, and the space goes to analytics that
explain why numbers move. The SwiftData `Achievement` model stays in the stored
schema until a schema migration removes it.
## 2026-10-09: Food search logs in one tap

Each food in search has a "+" that logs it at once and keeps the search open,
with "Logged · Undo" and the kilocalories left for the day. What the row shows
is exactly what the tap records: the amount last eaten, or for a new food one
of its first label serving, else 100 g or 4 oz (100 ml or 8 fl oz for a food
labelled by volume). `NutritionStore.quickPortion(for:unit:)` in ExerlyCore
decides it, and the portion sheet opens on the same amount, so a new food no
longer starts at 1 oz. A food eaten before is two taps from the home screen:
open search, then "+". Recent and suggested rows are fixed while search is
open, so rows don't move under a finger as foods are logged.

## 2026-10-09: Food search queries the database as you type

Search now asks the food database 400 ms after typing pauses, from three
characters, cancelling a request a newer keystroke has made stale, and reuses
answers already fetched. Saved and previously logged foods match on the
device with no wait and work offline. This replaces submit-only search. The
server still guards Open Food Facts' shared budget of 10 searches a minute
and caches each query for five minutes; when the budget is spent, typed
searches return the bundled generic foods only. If that happens in
production, the server should add a per-account limit or move to a search
API meant for type-ahead.

## 2026-10-09: The portion sheet is compact, with unit chips

The portion editor is a sheet sized to show the energy, macros, unit chips,
amount, meal and a pinned Log button without scrolling; dates, nutrient
corrections and the source are below. Switching unit or serving chips
converts the amount and keeps its weight; the presets under the amount set
whole servings. The separate "Portion
measure" sheet (`NutritionMeasureSelection`) is removed, and the meal
builder's portion editor uses the same chips. A barcode that matches one food,
typed or scanned, opens its portion directly.

## 2026-10-09: Old food library screen removed

`Features/FoodLibrary/FoodLibraryView.swift` was not reachable from any
screen; the Nutrition library replaced it. It is deleted. `LogFoodView`,
`FoodDetailView`, `CreateFoodView` and `BarcodeScannerView` are reachable
only from `HomeView`'s non-health diary mode, which nothing opens; they can go
once that mode is removed. The barcode camera they shared now lives in
`Features/Nutrition/NutritionBarcodeCamera.swift`.

## 2026-10-09: The food library manages foods; search logs them

The food library's "Usual around now" and "Recently logged" lists repeated
what food search now shows with one-tap logging, so they are removed. The
library is for finding, editing, starring and archiving saved foods; its food
page still logs, at the meal usual for the time of day.

## 2026-10-09: Unlogged weeks no longer move expenditure

`EnergyBalance` assumed an unlogged day's intake was the recent logged average
or, before any logging, its own expenditure estimate. With weigh-ins but no
logging, each day's real weight change then raised expenditure, the assumed
intake followed, and the estimate climbed with a shrinking band: 3,354 ±192
kcal after four weeks for someone burning 2,590, and 1,456 kcal off after nine
weeks in simulation. A fourth state, `D`, is now how far a stretch of unlogged
days' intake sits from the recent logged average or, before any logging, from
expenditure. Each stretch starts its own `D` and logged days never inform it,
so weight change before logging moves the trend and leaves expenditure at its
starting guess with its full band; Exerly doesn't assume someone ate before
logging the way they log. For logging that starts on day 21, the smoothed
trend around the switch went from 0.70 kg off to 0.18 and the expenditure band
from covering the truth 29 % of the time to 97 %. M5b's rates and the coaching
simulation are unchanged within 2 kcal and 0.001 % a week. The public API is
unchanged; `Parameters` gains `unloggedBalance` (500) and `unloggedDrift` (30),
and the API's JavaScript port and golden file follow. See
docs/design/007-nutrition.md.
## 2026-10-09: A logged row keeps its check, and a second tap takes it back

From the usability run: food search's "+" turned back into "+" two seconds
after logging, and Today's "Log again" chips reflowed as soon as one was used.
Now a row or chip logged from the screen keeps a check while the screen is
open, and tapping the check removes exactly what it logged. Logging a second
portion of the same food goes through the row's portion sheet. Today's chips
are fixed when the screen opens and refresh on a new day, on returning to the
app and on pull to refresh. The finish summary headlines one record per
exercise (heavier weight, then estimated 1RM, then reps); Progress still lists
every record.

## 2026-10-09: The native/browser round-trip harness is removed

`scripts/test-cross-client.sh`, its two Playwright specs and the six native
tests that consumed browser-made data are gone. They existed to prove the web
dashboard and the app agreed, the dashboard is out of scope, the native tests
only ever skipped without the harness, and one could no longer pass after the
weigh-in flow moved to ExerlyCore. The rest of the web dashboard is untouched;
remove it too if it starts to cost time.

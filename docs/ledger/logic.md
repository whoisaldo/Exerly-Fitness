# Logic agent ledger (Claude)

Owned by the logic agent; see "Two agents" in `docs/AGENT_BRIEF.md`. Records observed
results, not planned completion. Astra's pre-split M1 notes are kept at the end.

## Merge status

Updated 2026-10-07 10:49 EDT. Unlanded commits are counted with `git cherry`
against the integration branch.

| Branch                                        | Unlanded | Last landed                                                                                                               |
| --------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| `logic/next` (local, pushed as `agent/logic`) | 0        | 2026-10-07 10:49 EDT, integration (label basis from its declaration)                                                      |
| `main`                                        | –        | `0b56070f` (the design release), 2026-10-07 07:53 EDT; CI 37616722886 failed one UI test (generic foods; fix in progress) |

`main` and integration converged: integration was merged into `main`
(`fc016093`), and the integration branch fast-forwarded onto that merge. Later
merges into `main` are fast-forwards until `main` gets commits of its own.
Every other logic branch was fully landed and deleted on 2026-10-06, and the
temporary merge worktree is removed.

## Current milestone

**L1: ExerlyCore training domain.** Done on 2026-10-06 and landed (`55903a9d`).

- `apps/ios/ExerlyCore` holds units, a 119-exercise library, sessions, e1RM, volume,
  statistics, records, rest, session editing and `TrainingStore`.
- The interface is published in `docs/handoff/to-app.md` and documented in
  `apps/ios/ExerlyCore/README.md`.

**L1b: on-device SQLite persistence.** Done on 2026-10-06 and landed (`4d10d8dc`).

**M1a: PostgreSQL foundation.** Done on 2026-10-06 and landed (`5278f84b`).

- A Postgres driver, SQL migrations, a throwaway test cluster, docker-compose, CI,
  and the DigitalOcean spec on the Dockerfile.

**M1b: accounts.** Done on 2026-10-06 and landed (`51f67e57`).

- Sign in with Apple, account linking, and account deletion and export from one
  ownership map.
- Apple token revocation waits for a key from Ali (QUESTIONS_FOR_ALI.md).

**Review fixes.** Landed (`55935632`): validation at the store boundary, rest
state that persists, a database per account, and `WorkoutSummary`.

**M1c: document sync.** Server landed (`3c5ea561`); the Swift client is landing
now.

- Server: `/v1/documents` and `/v1/changes`, plus `docs/api/openapi.yaml`.
- ExerlyCore: `ExerlyAPI` (sessions with refresh rotation), the credential
  stores, `ExerlyJSON`, `Merge` and `SyncEngine`, with sync state in SQLite
  schema v3.

**M1 status.** M1 is complete in code. Two things are outside my control:

- **Production cutover** waits on Ali's Neon `DATABASE_URL`. The integration
  branch must not merge to `main` before that, or the live API breaks.
- **Keychain verification** needs the app agent's hosted tests.

**Staging.** Running on devbox1 at `http://100.80.149.7:39110` (`37bc7710`).
Redeploy with `apps/api/deploy/staging/install.sh` after API changes. Internal
TestFlight builds now use it by default (the app agent's `release.sh`), so keep
it current and healthy.

**M2: agent core.** In progress (`docs/design/004-agent-core.md`).

- **Done, `ce3aa2ce`.** ExerlyCore has proposals, accept/undo/stale, the audit
  log, metric references and `DocumentHost`; proposals and audit events sync, and
  the server accepts both kinds.
- **Done, `db6fbecd`.** Personal access tokens with scopes, server-written audit
  events, and the OpenAPI file updated.
- **Also done.** `a4eeba40`: atomic multi-write changes, and Apple link and
  unlink in the client.
- **Done, M2c (landing with the app's A2).** The MCP server at `/mcp`
  (`routes/mcp.js`, `lib/agentTools.js`, guide `docs/api/mcp.md`). The training
  maths are ported to `apps/api/lib/training/` and asserted against
  `docs/api/golden/training-v1.json`, which ExerlyCore's `GoldenTests` writes
  (regenerate with `EXERLY_WRITE_GOLDEN=1 swift test --filter GoldenTests`).
- **Landed, `3685dbf2` to `67c8db44`.**
  - M2c, the bridge and the review fixes.
  - M2d detectors: `EntryErrorDetector` and `TrainingSignals`, with rates in
    `docs/design/005-training-detectors.md`.
  - Deleted accounts are recognised (`account_deleted`), with
    `accountsAwaitingLocalCleanup`.
  - `AccountExport` merges unsynced documents.
  - The SQLite driver is removed. iOS CI installs PostgreSQL. Concurrent
    Apple sign-ins no longer race. Staging is redeployed.
- **Done, session bridge and review fixes (same landing).**
  - Legacy `APIClient` implements `SessionTransport`; `AuthViewModel` has Apple
    sign-in, `accountAPI`, `signInMethods`, link, unlink, export and delete.
    `SyncEngine.shared.purge(accountID:)` clears legacy data.
  - The app agent's hosted tests for it are in
    `docs/handoff/attachments/SessionBridgeTests.swift`, waiting for them to add
    to ExerlyTests.
  - Session generations in `ExerlyAPI`, and `SyncEngine.shutdown()`.
  - `AccountAPI` binds requests to an account. The Keychain updates in place.
  - Proposals are validated at accept and undo, as a batch. Custom exercises
    publish safely.
  - Unreadable server documents are set aside (`SyncEngine.rejected`).
  - The server refuses agent documents ExerlyCore can't decode.

**UUID identity.** Landed (`4f026b47`, `700cdc0d`).

- UUID document IDs, and the IDs inside payloads (proposal changes and their
  documents, evidence, audit targets, a session's program, an entry's food), are
  uppercase on the server. Migrations 0005 (ID columns) and 0006 (payloads,
  mirroring `canonicalPayload`) convert old rows. ExerlyCore's `SyncEngine`,
  `ProposedChange` and `DataRef` read IDs in the same form.
- `shell-quote` is pinned to 1.12.0 by an npm override (Dependabot 60). Alerts
  58 to 60 close when integration reaches `main`.

**M4 and M5a/M5b.** Landed (`785917ef`), with the app agent's reviews
answered: `saved_food` (not `food`, which legacy food logs use in
`sync_changes`), name-based entry-check IDs, `weightMatch` reserved,
`SQLiteTrainingPersistence.close()`, and `AccountExport.merging(pending:)` for
the legacy queue. The plate search fix landed in `69fac1e4`.

**M5c: targets and check-ins.** Landed (`707c815b`): `NutritionPlan`
versions, `NutritionTargets`, `NutritionCheckIn`, the `nutrition_plan` kind,
design 011, and `EnergyBalance` coupling expenditure to weight.

**Landed after A5 (`df84650c`):**

- M5d: `/v1/foods` search and barcode lookup from Open Food Facts as
  ExerlyCore Foods, with the golden contract `docs/api/golden/foods-v1.json`.
  Labels per 100 ml keep a `volume` basis with a category density
  (`12d356af`, from the app agent's review).
- M6a/M6b: nutrition through MCP, and agents proposing meals as food entries.
- M5f: nutrient goals, overview, timing and goal ETA. Apple Health weigh-ins,
  MacroFactor Shortcuts JSON, the weekly review (B07 Core half).
- M7: custom metrics, day tags, correlations and n=1 experiments (design
  014, measured error rates).
- A7: `NutritionStore.preview` and `Food.per100g(fromLabel:)`. The legacy
  diary is retired rather than bridged, as the brief says nobody uses Exerly
  yet. If Ali wants test entries carried over, build a server-side
  idempotent import.
- A6 review: `ProgramSchedule.next` no longer restarts a program when its
  last day done is removed (`2f1f3844`).

The API gained kinds and routes (`custom_metric`, `metric_entry`,
`experiment`, `/v1/foods`, nutrition MCP tools), so redeploy staging when
this lands.

**Landed after A6 (`3a010060`), with the brief's new integration and design
rules (`6b908a24`):**

- Snapshots keep a food's volume basis (`FoodSnapshot.volume`), the first
  nutrition plan from the onboarding profile (`PlanBasis.formula`), and faster
  logging: plates, copy and move, recipe ingredients, suggestions by time of
  day (N04, N07, N09, N12, B01).
- M8 gym profiles (`gym_profile`, design 016): progression recommends weights
  the gym has.
- T15 swap and P06 keeping a workout's changes as a proposal.
- M9 program generation as a proposal (design 017, P02).
- M10 Hevy and Strong imports, and `importSessions` for backfill (design 018,
  I13, T20).
- `food(barcode:symbology:)` for EAN-8 and UPC-E scans (app agent, 20:23).
- M11 webhooks for agents (migration 0007, design 019, B11).

**M12: recovery-aware volume.** Landed (`3872a1a2`, design 020, B05): a lighter
planned workout offered when sleep, HRV and resting heart rate are worse than
the person's baseline.

**M13: nutrition label reading.** Landed (design 021, N15): the camera's text
from a US or EU label becomes nutrients for review.

**Target continuity.** Landed: `POST /v1/nutrition/plans/from-legacy` and
`AccountAPI.adoptLegacyTargets()` keep older accounts' saved targets as manual
plans (app agent, 23:40).

**U.S. units, "kcal left" and plan continuity.** Landed 2026-10-07: imperial
defaults and `USUnits` (Ali, through the app agent), `NutritionStore.progress(on:)`,
and bridged plans following the legacy Program screen.

**M14: CSV exports and import.** Landed 2026-10-07 (design 022, I14): seven CSV
files with units and empty unknowns, and an idempotent import of a JSON export,
checked by a live round trip between two accounts.

**Sync P1, food units, recipes and entry corrections.** Landed 2026-10-07.
The legacy `SyncEngine` clears a stale error and offline state after a
successful pull and publishes `lastSyncedAt`; the app's reconnect regression
passes against it (hosted suite 164, 1 skipped). Core adds exact ounce and
millilitre conversions, recipe `servingCount`, `preparation`, `recipeServing`
and `withIngredients` (N11), and per-entry nutrient corrections marked
`edited` (N08). Core 298, API 251. The final design critique is in
`to-app.md`.

**MCP `generate_program`.** Landed 2026-10-07 (design 017, B11/B12). The
generator is ported to `apps/api/lib/training/generation.js` and held to
`docs/api/golden/program-generation-v1.json` (289 cases, written by
`GenerationGoldenTests`). The tool returns the program for the active gym with
the proposal the app would file. The server data flows for the app's privacy
review are in `to-app.md`, and the legacy AI coach question is in
QUESTIONS_FOR_ALI.md. Core 299, API 254.

**Audit: request bodies.** `/v1/import` parsed its 25 MB body before
authentication or rate limiting, so anyone could make the 512 MB instance
parse large bodies. It now checks the app's session (and a limit of 10 a
minute) first. Malformed or oversized JSON anywhere returned 500 and was
logged as a server error; it is now 400 or 413.

**Sync status per account.** The legacy `SyncEngine` resets its error,
offline state and last sync time when another account is configured or the
configured one is purged (the app's P2), checked with a hosted test given to
the app.

**Generic foods (design 023).** Search returns 5,431 USDA FNDDS foods
(public domain, bundled in `apps/api/lib/genericFoods.json`) before Open Food
Facts products, ranked so "banana" gives "Banana, raw". Every one passes
Core's food validation in Core's units, and the phone decodes them from the
foods golden. This removes the need for a USDA key. API 260.

**Design release follow-ups.** The app's design release (1.0, build 2610071054) is in internal TestFlight. With its branch landed, the legacy
Health methods it replaced and the old sync conflict views are removed.
`Serving.quantity(grams:)` gives the app N03's unit switch. Core 301.

**Audit: token management by case.** A personal access token could list and
mint tokens at `/v1/Tokens`: the refusal compared the path case-sensitively,
while Express routes regardless of case. So a read token could mint a write
token, or a successor outliving its revocation. Fixed in `tokenMayUse` and by
a guard in the tokens router, each tested alone. Production never ran this
API; on staging only a synthetic probe account was affected.

**Set-by-set adjustment (P08).** `Progression.adjust` re-plans a slot's
remaining sets after each set, with weight match (load kept, reps follow) or
free loads, and gives first sessions an assessment set. In simulation, later
sets' mean RIR error falls from 0.93 to 0.55. A hold now repeats the last
session's hardest set (in Swift and the JS port, golden regenerated), so
lighter adjusted sets don't pull the next plan down. Core 305, API 260.

**Label basis (app's P1).** `NutritionLabel` took any kJ or salt as a label
per 100 g, so a per-serving label with kJ logged half its energy. The label's
first declaration now decides (per serving or per 100 g/ml), and Australian
and bilingual Canadian panels are read. Core 307.

**CI on `main`.** The first run after the merge (37558851579) passed every
unit and UI test. The native and browser round trip then failed, because the
merged lockfile installs Vite under `apps/web` and the script expected the
root. That is fixed. Earlier integration runs had failed at the same step for
want of `rg`. Only one macOS job runs at a time, and the iOS job takes about
two hours. The rerun on `3425db1d` passed unit tests and 36 of 37 UI tests; the
failure was a typing flake in the app agent's program builder test, reported to
them.

Staging was redeployed with migration 0007.

**`main`.** Ali asked on 2026-10-06 for integration to be merged into `main`
at every milestone end and at least daily. Merged at `fc016093` (142 commits
behind). Conflicts went to integration's side, keeping main's own work:
dotenv 18, the Tailwind 4, Vite 8 and framer-motion 13 web toolchain, newer
lint packages, and the Dependabot and workflow updates. Checked on the merged
tree: lint, prettier, web typecheck and build, API tests (243) and the web e2e
suite (67).

## Next three steps

1. `main`'s CI run 37616722886 (`0b56070f`) passed unit tests and failed
   `testNutritionSubmittedSearchBarcodeAndThreeTapRepeat`: generic foods
   (`71604c45`) filled the first ten results for "oat" and pushed the
   fixture's packaged product off CI's screen. Generic results are now a
   quarter of the list; the app is making the test independent of position.
   When that lands, advance `main` and confirm CI. Production is still the old
   API until Ali sets `DATABASE_URL`.
2. Remaining logic for Beyond: Core support the app's design work asks
   for. The MacroFactor import waits on Ali's headers.
3. Keep reviewing app commits and answering `to-logic.md`.

## Evidence

2026-10-06 baseline on `agent/logic`, from the logs in
`artifacts/agent-baseline/`:

- API: `npm test` in `apps/api` (SQLite mode, Node 22.22.2) passed 153 of 153.
- iOS: `scripts/ios.sh build` with Xcode 26.2, unsigned, for a generic iOS device:
  BUILD SUCCEEDED. The one warning is pre-existing, at `MeasurementsTab.swift:148`
  (the app agent's file).
- ExerlyCore: `swift test` passed 75 of 75 with no warnings.
  `xcodebuild -scheme ExerlyCore -destination generic/platform=iOS` succeeded with
  warnings treated as errors.
- SwiftLint, with the repo rules, is clean on ExerlyCore. Run it from the package
  directory with the `included` block removed:

  ```sh
  sed '/^included:/,/^$/d; /^excluded:/,/^$/d' ../../../.swiftlint.yml > /tmp/x.yml
  swiftlint lint --quiet --config /tmp/x.yml Sources Tests
  ```

- L1b, 2026-10-06: `swift test` passed 81 of 81. On devbox1's M1 Max,
  `SQLiteTrainingPersistence` loads 1,000 sessions (25,000 sets) in 0.20 s, and
  `TrainingHistory` indexes them in 0.01 to 0.03 s. Not yet measured on a phone.

Nothing is on TestFlight from the logic side. The app does not link ExerlyCore yet;
the app agent adds it to the project.

- M1a, 2026-10-06:
  - `npm test -w apps/api` passed 166 of 166 on a throwaway PostgreSQL 16.13
    cluster.
  - `bash scripts/smoke-api.sh` passed on PostgreSQL.
  - docker-compose on devbox1 (colima): the API was healthy on port 39100,
    signup, food write and read worked, the container runs as `node`, and the logs
    hold no password or URL. A restart re-ran migrations as a no-op.
  - Backup: a `pg_dump` of a synthetic schema restored into a new database with
    identical rows (`tests/db.backup.test.js`).

- M1c, 2026-10-06:
  - `npm test -w apps/api` passed 182 of 182.
  - ExerlyCore `swift test` passed 124 of 124 on macOS.
  - The ExerlyCore suite also passed on the "Exerly Logic iPhone 17" simulator
    (iOS 26.2, UDID `4FAB7031-A3BD-4298-A75C-F1259ACDAE6B`); log in
    `artifacts/logic/`.
  - `apps/ios/ExerlyCore/scripts/live-sync.sh` passed: the Swift client and
    engine against the real API and PostgreSQL.
  - The OpenAPI file passes `redocly lint`, except for its licence warning
    (licence is Ali's decision).
  - GitHub CI for `5278f84b`: the API (PostgreSQL), ExerlyCore, SwiftLint and
    actionlint jobs passed.

- M2, 2026-10-06:
  - `npm test -w apps/api` passed 192 of 192.
  - ExerlyCore `swift test` passed 147 of 147.
  - The staging redeploy is healthy.
- 2026-10-06, after the deletion and export batch (`67c8db44`):
  - API: 214 of 214.
  - ExerlyCore: 179 of 179, including the simulator-scored detector bounds.
  - ExerlyTests: 92 executed with the 15 bridge tests temporarily included,
    0 failures.
  - iOS build: succeeded.
  - Staging: healthy.
- M2c, the bridge and the review fixes, 2026-10-06. Results from `logic/landing`,
  which is `agent/app` `f38e4b87` plus this batch:
  - `npm test -w apps/api` passed 213 of 213.
  - ExerlyCore `swift test` passed 164 of 164.
  - `live-sync.sh` passed 2 of 2. One of them is MCP to phone: an agent's
    correction, verified, diffed, accepted and synced back through the real API.
  - `scripts/ios.sh build` succeeded.
  - ExerlyTests on "Exerly Logic iPhone 17": 88 executed with the bridge tests
    temporarily included, 0 failures. The 1 skip is the app agent's private
    TestFlight smoke check.
  - Mutation checks: removing the session-generation guard, the sync shutdown
    guard, or a JS rule (Brzycki constant, record ties, week start, local date,
    search order) fails the matching tests.

- 2026-10-06, M5c batch on `agent/logic` (`589d5c5b`):
  - API: 226 of 226. ExerlyCore: 230 of 230, with the coaching and energy
    balance simulations inside their bounds.
  - ExerlyTests: 101 executed, 1 skipped (the app agent's private TestFlight
    check). iOS build: succeeded. Live sync: 4 of 4, three runs.

## Risks and external dependencies

- Xcode 26.2 has no watchOS 26.2 platform installed, so watch builds need that
  component.
- The repo is **public** on GitHub (`sidebandstudio/Exerly-Fitness`). No secrets
  and no personal data, ever.
- Neon and DigitalOcean `DATABASE_URL` need Ali. Local Postgres work proceeds
  without them.
- Every push to `main` redeploys the API on DigitalOcean. Production ran the
  MongoDB API until the 2026-10-06 merge; integration's API needs
  `DATABASE_URL` (Neon). If it isn't set, the new deployment fails to start and
  DigitalOcean keeps the previous one serving. Check `/api/health` after each
  merge: version 2.0.0 with driver `postgres` means the new API is live.
- `main` keeps Ali's Tailwind 4/Vite 8 web toolchain, which integration lacks.
  Later merges keep it; integration's web code runs on it (the e2e suite
  passed). Integration's rewritten web components were checked for Tailwind
  v4 changes in meaning: they use no renamed scale classes (`shadow-sm`,
  `rounded`, `ring`, …), and their `space-y` children with inline labels are
  grid items, so they render as on v3. The upgrade tool's remaining edits are
  canonical spellings only, left for whoever next works on the web app.
- Since the 2026-10-06 merge, Deploy Web publishes integration's web app, which
  signs in through `/login` and `/auth/token`. The old production API answers
  404 to both, so web sign-in fails until the new API runs in production
  (`DATABASE_URL`). The landing pages are unaffected.
- Colima's default VM was started for container checks. Stop it with
  `colima stop default` when you're done.
- Mapping MacroFactor's 22 muscle columns to Exerly's 21 regions needs a synthetic
  export with the real column names (import milestone).

## Resume exactly

1. Read the brief, this ledger and `docs/handoff/to-logic.md`, and check
   `git status` in `~/Desktop/Exerly-Fitness-logic` (branch `logic/next`,
   pushed as `agent/logic`).
2. Run `gh repo view sidebandstudio/Exerly-Fitness`.
3. Review the app agent's commits since `55903a9d`:
   `git log 55903a9d..feat/mobile-production-foundations`.
4. Toolchains:
   - Node 22: `PATH="$HOME/.local/share/fnm/node-versions/v22.22.2/installation/bin:$PATH"`.
   - Xcode: `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer`.
   - ExerlyCore tests: `cd apps/ios/ExerlyCore && swift test`.
   - API tests: `npm test` in `apps/api`.
   - iOS build: `bash scripts/ios.sh build`.
5. To land (at most about 4 hours of finished work at a time):
   - Rebase onto `feat/mobile-production-foundations`.
   - Run `git -C ~/Desktop/Exerly-Fitness merge --ff-only logic/next`.
   - Push with `DEVELOPER_DIR=... git push origin feat/mobile-production-foundations`,
     then `logic/next:agent/logic`. The pre-push hook runs eslint, prettier, the
     web typecheck, API tests and SwiftLint.
   - Update the merge status table.
6. To merge into `main` (each milestone end, and at least daily):
   - In a temporary worktree from `origin/main`, merge
     `origin/feat/mobile-production-foundations` with `--no-ff`.
   - Run lint, prettier, the web typecheck and build, API tests, and the web
     e2e suite on scratch ports with `PLAYWRIGHT_API_URL` set.
   - Push to `main`, watch CI with `gh run list --branch main`, check
     production's `/api/health`, then remove the worktree.
7. Use only Logic scratch ports 39100-39199 and "Exerly Logic" simulators.

---

## Pre-split notes (Astra, 2026-10-06)

M1, PostgreSQL and account foundation, starting at revision `9a8e0dbe` on
`feat/mobile-production-foundations`. The existing implementation uses MongoDB in
production and SQLite in tests, with native offline queues, revision checks, session
rotation and mutation replay. The plan is in `docs/design/001-postgres-foundation.md`.
Existing reports in `docs/MOBILE_PRODUCTION_STATUS.md` are historical evidence. They
don't establish current device parity or TestFlight availability.

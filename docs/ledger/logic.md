# Logic agent ledger (Claude)

Owned by the logic agent; see "Two agents" in `docs/AGENT_BRIEF.md`. Records observed
results, not planned completion. Astra's pre-split M1 notes are kept at the end.

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
Redeploy with `apps/api/deploy/staging/install.sh` after API changes.

**M2: agent core.** In progress (`docs/design/004-agent-core.md`).

- **Done, `ce3aa2ce`.** ExerlyCore has proposals, accept/undo/stale, the audit
  log, metric references and `DocumentHost`; proposals and audit events sync, and
  the server accepts both kinds.
- **Done, `db6fbecd`.** Personal access tokens with scopes, server-written audit
  events, and the OpenAPI file updated.
- **Also done.** `a4eeba40`: atomic multi-write changes, and Apple link and
  unlink in the client.

## Next three steps

1. M2c, the MCP server at `/mcp`:
   - use the official TypeScript SDK with Streamable HTTP, authenticated by a
     token;
   - port the training maths to JavaScript (`apps/api/lib/training/`) and assert
     it against a golden file generated from Swift
     (`docs/api/golden/training-v1.json`);
   - add read tools and a `propose` tool.
2. M2d, detectors in ExerlyCore:
   - entry errors, which become correction proposals;
   - stall diagnosis and deload signals, as evidence.
     Check them against simulated training and record their error rates.
3. Then M4, programs and progression; deload proposals need programs. Keep
   reviewing app commits and answering `to-logic.md`.

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

## Risks and external dependencies

- Xcode 26.2 has no watchOS 26.2 platform installed, so watch builds need that
  component.
- The repo is **public** on GitHub (`sidebandstudio/Exerly-Fitness`). No secrets
  and no personal data, ever.
- Neon and DigitalOcean `DATABASE_URL` need Ali. Local Postgres work proceeds
  without them.
- `main` has diverged from the integration branch: origin/main has Sideband
  migration commits that the integration branch carries as different SHAs. A merge
  to main needs care at the end of a milestone. Every push to main redeploys the
  API, and production still runs Mongo, so don't merge a Postgres-only API to main
  before Ali sets `DATABASE_URL`.
- Production runs MongoDB on `main` today. The integration branch has no Mongo
  driver, so merging it to `main` breaks the live API until Ali sets
  `DATABASE_URL` (Neon) in DigitalOcean. Merge to main only after that, then check
  `/api/health`.
- Colima's default VM was started for container checks. Stop it with
  `colima stop default` when you're done.
- Mapping MacroFactor's 22 muscle columns to Exerly's 21 regions needs a synthetic
  export with the real column names (import milestone).

## Resume exactly

1. Read the brief, this ledger and `docs/handoff/to-logic.md`, and check
   `git status` in `~/Desktop/Exerly-Fitness-logic` (branch `agent/logic`).
2. Run `gh repo view sidebandstudio/Exerly-Fitness`.
3. Review the app agent's commits since `55903a9d`:
   `git log 55903a9d..feat/mobile-production-foundations`.
4. Toolchains:
   - Node 22: `PATH="$HOME/.local/share/fnm/node-versions/v22.22.2/installation/bin:$PATH"`.
   - Xcode: `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer`.
   - ExerlyCore tests: `cd apps/ios/ExerlyCore && swift test`.
   - API tests: `npm test` in `apps/api`.
   - iOS build: `bash scripts/ios.sh build`.
5. To land:
   - Rebase onto `feat/mobile-production-foundations`.
   - Run `git -C ~/Desktop/Exerly-Fitness merge --ff-only agent/logic`.
   - Push with `DEVELOPER_DIR=... git push origin feat/mobile-production-foundations agent/logic`.
     The pre-push hook runs eslint, prettier, the web typecheck, API tests and SwiftLint.
6. Use only Logic scratch ports 39100-39199 and "Exerly Logic" simulators.

---

## Pre-split notes (Astra, 2026-10-06)

M1, PostgreSQL and account foundation, starting at revision `9a8e0dbe` on
`feat/mobile-production-foundations`. The existing implementation uses MongoDB in
production and SQLite in tests, with native offline queues, revision checks, session
rotation and mutation replay. The plan is in `docs/design/001-postgres-foundation.md`.
Existing reports in `docs/MOBILE_PRODUCTION_STATUS.md` are historical evidence. They
don't establish current device parity or TestFlight availability.

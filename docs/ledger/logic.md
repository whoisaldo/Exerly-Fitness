# Logic agent ledger (Claude)

Owned by the logic agent; see "Two agents" in `docs/AGENT_BRIEF.md`. Records observed
results, not planned completion. Astra's pre-split M1 notes are kept at the end.

## Current milestone

**L1: ExerlyCore training domain.** Done on 2026-10-06 and landed on
`feat/mobile-production-foundations` at `55903a9d`.

- `apps/ios/ExerlyCore` holds units, a 119-exercise library, sessions, e1RM, volume,
  statistics, records, rest, session editing and `TrainingStore`.
- The interface is published in `docs/handoff/to-app.md` and documented in
  `apps/ios/ExerlyCore/README.md`.

**Next: L1b, on-device SQLite persistence for training (`SQLiteTrainingPersistence`).**
It must have no interface change for the app. Then M1: Postgres, migrations,
Sign in with Apple, sessions and sync.

## Next three steps

1. L1b: SQLite `TrainingPersistence` in ExerlyCore using the system SQLite3 (no
   dependency). Store sessions as JSON documents keyed by UUID, in WAL mode with
   atomic writes, and test crash-safety and reloads. Leave room for the sync outbox
   table.
2. M1: PostgreSQL in `apps/api`, following `docs/design/001-postgres-foundation.md`
   (plain SQL migrations, advisory lock, a test cluster per run, docker-compose,
   CI service). Replace Mongo and SQLite drivers behind `apps/api/data`.
3. M1, continued: Sign in with Apple verification, account deletion, export, and the
   training sync contract (session documents with a 3-way merge by set ID), published
   in `docs/api/` and `to-app.md`.

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

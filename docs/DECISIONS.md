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

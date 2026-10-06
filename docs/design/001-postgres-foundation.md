# M1: PostgreSQL and account foundation

## Problem

Production uses MongoDB while most local checks use SQLite. Neither exercises the
required PostgreSQL deployment. Startup mutates schemas without a version history,
and there is no self-hosted container or verified restore procedure.

## Acceptance

- Run every existing API test on a scratch PostgreSQL database.
- Preserve native stable IDs, revisions, deletion markers and idempotent responses.
- Concurrent writes cannot lose water additions, reuse sync sequences or apply one
  operation twice. A rejected mutation leaves no entity, receipt or sync event.
- Account B cannot read, change, restore or export account A's records.
- Apply, reapply, roll back and reapply numbered migrations. Detect edited applied
  migrations before serving traffic. Concurrent startup uses one migration owner.
- Build a non-root API container with PostgreSQL Compose health checks.
- Restore a synthetic database dump into a separate database and compare records.
- Pass the unsigned device build and unit/UI tests with Xcode 26.2. Internal
  TestFlight remains a separate, recorded result.
- Complete Apple identity verification, native sign-in, account deletion and
  export/import in the next foundation slice. Storage completion alone does not
  finish M1.

## Implementation

Use PostgreSQL 16 or later, `pg`, UUID server identities and explicit SQL migrations.
Keep legacy `_id` response aliases until native models no longer use them. Preserve
UTC timestamps as `timestamptz` and account calendar dates as validated date strings.
Numbers remain JavaScript numbers; nullable nutrients remain unknown.

The connection pool uses a small bound. A transaction's asynchronous context owns
one connection, and nested work joins that transaction. Retry serialization,
deadlock and first-insert uniqueness races with fresh snapshots. A retry must never
repeat external model calls, send mail or emit an HTTP response before commit.

The test runner owns a temporary local PostgreSQL cluster when no explicit test
database URL is supplied. Each API test process gets its own schema. Refuse to use
the production `DATABASE_URL` implicitly for tests. Cleanup touches only the test
runner's cluster and generated schemas. CI uses a PostgreSQL service.

Use `DATABASE_URL` for application connections, require verified TLS for remote
production databases, and never print a connection string. Keep generated dumps,
cluster data, credentials, builds and raw simulator reports under ignored paths.

## Evidence to collect

Record failing regression tests before implementation and final test counts in
`docs/ledger/logic.md`. Retain full local logs under `artifacts/`. Review screenshots on
the Exerly-owned small and large simulators in both appearances and at the largest
Dynamic Type setting. Distinguish simulator verification from a signed build and
an accepted TestFlight upload.

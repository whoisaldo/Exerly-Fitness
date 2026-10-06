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

# Database operations

The API uses PostgreSQL 16 or later through `DATABASE_URL`.

## Migrations

`migrations/` holds numbered pairs: `NNNN_name.up.sql` and `NNNN_name.down.sql`.

- The server applies pending up migrations at startup, before it listens.
- Each migration runs in its own transaction.
- A per-schema advisory lock means only one starting instance migrates.
- Applied versions and checksums live in `schema_migrations`. The server refuses to
  start if an applied migration was edited, or if the database has a version this
  code doesn't know.

Never edit an applied migration; add a new one. Commands, with `DATABASE_URL` set:

```sh
npm run migrate -w apps/api -- status
npm run migrate -w apps/api -- up
npm run migrate -w apps/api -- down 1   # operator rollback; the server never rolls back
```

Roll back the code first and the schema second, and only when the down script is safe
for the data in place.

## Backups

Production (Neon) keeps point-in-time history within its retention window. For a
portable copy, or before a risky migration:

```sh
pg_dump --dbname "$DATABASE_URL" --format custom --file exerly-$(date +%F).dump
createdb exerly_restore
pg_restore --dbname postgresql://.../exerly_restore --no-owner --exit-on-error exerly-$(date +%F).dump
```

`tests/db.backup.test.js` runs this round trip on synthetic data and compares every
row.

Dumps contain personal data. Keep them encrypted, out of the repository, and delete
them when no longer needed.

## Tests

`npm test -w apps/api` starts a throwaway cluster on a Unix socket (no TCP port) and
gives each test file its own schema. In CI, `EXERLY_TEST_DATABASE_URL` points at the
service container instead. Tests never read `DATABASE_URL`.

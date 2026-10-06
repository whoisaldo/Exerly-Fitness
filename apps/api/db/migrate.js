// Numbered SQL migrations.
//
// db/migrations holds NNNN_name.up.sql and NNNN_name.down.sql pairs. Applied
// versions are recorded in schema_migrations with a checksum of the up script,
// so an edited migration is detected before the server accepts traffic. An
// advisory lock scoped to the current schema makes concurrent starts take
// turns. Each migration runs in its own transaction.
//
//   node db/migrate.js status | up | down [steps]
//
// Uses DATABASE_URL. Rollback is an operator command; the server only migrates up.

const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const DIRECTORY = path.join(__dirname, 'migrations');
// First half of the advisory lock key; the second is a hash of the schema name.
const LOCK_NAMESPACE = 72_201_006;

function loadMigrations(directory = DIRECTORY) {
  const files = fs.readdirSync(directory).filter((f) => f.endsWith('.sql'));
  const byVersion = new Map();
  for (const file of files) {
    const match = /^(\d{4})_([a-z0-9_]+)\.(up|down)\.sql$/.exec(file);
    if (!match) throw new Error(`Unexpected migration file name: ${file}`);
    const version = Number(match[1]);
    const entry = byVersion.get(version) || { version, name: match[2] };
    if (entry.name !== match[2]) throw new Error(`Migration ${match[1]} has two names`);
    entry[match[3]] = fs.readFileSync(path.join(directory, file), 'utf8');
    byVersion.set(version, entry);
  }
  const migrations = [...byVersion.values()].sort((a, b) => a.version - b.version);
  migrations.forEach((m, i) => {
    if (m.version !== i + 1) throw new Error(`Migration versions must be contiguous from 0001`);
    if (!m.up || !m.down) throw new Error(`Migration ${m.version} needs both up and down scripts`);
    m.checksum = createHash('sha256').update(m.up).digest('hex');
  });
  return migrations;
}

async function withLock(client, fn) {
  await client.query('SELECT pg_advisory_lock($1, hashtext(current_schema()))', [LOCK_NAMESPACE]);
  try {
    await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      version integer PRIMARY KEY,
      name text NOT NULL,
      checksum text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now()
    )`);
    return await fn();
  } finally {
    await client.query('SELECT pg_advisory_unlock($1, hashtext(current_schema()))', [
      LOCK_NAMESPACE,
    ]);
  }
}

async function appliedVersions(client, migrations) {
  const { rows } = await client.query(
    'SELECT version, name, checksum FROM schema_migrations ORDER BY version'
  );
  for (const row of rows) {
    const known = migrations.find((m) => m.version === row.version);
    if (!known) {
      throw new Error(
        `Database has migration ${row.version} (${row.name}) that this code does not know`
      );
    }
    if (known.checksum !== row.checksum) {
      throw new Error(`Applied migration ${row.version} (${row.name}) was edited after it ran`);
    }
  }
  return rows.map((r) => r.version);
}

async function inTransaction(client, fn) {
  await client.query('BEGIN');
  try {
    await fn();
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}

/** Applies pending migrations. Returns the versions applied. */
async function migrateUp(client, migrations = loadMigrations()) {
  return withLock(client, async () => {
    const applied = new Set(await appliedVersions(client, migrations));
    const ran = [];
    for (const migration of migrations) {
      if (applied.has(migration.version)) continue;
      await inTransaction(client, async () => {
        await client.query(migration.up);
        await client.query(
          'INSERT INTO schema_migrations (version, name, checksum) VALUES ($1, $2, $3)',
          [migration.version, migration.name, migration.checksum]
        );
      });
      ran.push(migration.version);
    }
    return ran;
  });
}

/** Rolls back the latest `steps` migrations. Returns the versions rolled back. */
async function migrateDown(client, steps = 1, migrations = loadMigrations()) {
  return withLock(client, async () => {
    const applied = await appliedVersions(client, migrations);
    const undone = [];
    for (const version of applied.reverse().slice(0, steps)) {
      const migration = migrations.find((m) => m.version === version);
      await inTransaction(client, async () => {
        await client.query(migration.down);
        await client.query('DELETE FROM schema_migrations WHERE version = $1', [version]);
      });
      undone.push(version);
    }
    return undone;
  });
}

async function status(client, migrations = loadMigrations()) {
  return withLock(client, async () => {
    const applied = new Set(await appliedVersions(client, migrations));
    return migrations.map((m) => ({
      version: m.version,
      name: m.name,
      applied: applied.has(m.version),
    }));
  });
}

module.exports = { loadMigrations, migrateUp, migrateDown, status, DIRECTORY };

if (require.main === module) {
  require('dotenv').config();
  const { Client } = require('pg');
  const { connectionConfig } = require('../data/postgres');
  const [command = 'status', arg] = process.argv.slice(2);
  (async () => {
    const client = new Client(connectionConfig(process.env.DATABASE_URL));
    await client.connect();
    try {
      if (command === 'up') console.log('Applied:', await migrateUp(client));
      else if (command === 'down')
        console.log('Rolled back:', await migrateDown(client, Number(arg) || 1));
      else if (command === 'status') console.table(await status(client));
      else throw new Error(`Unknown command ${command}. Use status, up or down [steps].`);
    } finally {
      await client.end();
    }
  })().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

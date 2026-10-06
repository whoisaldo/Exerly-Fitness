// Backup and restore: dump a synthetic account's schema with pg_dump, restore
// it into a separate database with pg_restore, and compare every row.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const { Client } = require('pg');
const { startServer, signUp, schema } = require('./helpers/server');
const { binary } = require('./helpers/cluster');
const { connectionConfig } = require('../data/postgres');
const { collections } = require('../data/schema');

const url = process.env.EXERLY_TEST_DATABASE_URL;

async function snapshot(connectionString) {
  const c = new Client(connectionConfig(connectionString, { schema }));
  await c.connect();
  try {
    const out = {};
    for (const table of [...Object.keys(collections), 'schema_migrations']) {
      const order = table === 'schema_migrations' ? 'version' : 'seq';
      out[table] = (await c.query(`SELECT * FROM ${table} ORDER BY ${order}`)).rows;
    }
    return out;
  } finally {
    await c.end();
  }
}

test('a pg_dump backup restores into a new database with identical records', async () => {
  const api = await startServer();
  const database = `restore_${process.pid}_${Math.random().toString(36).slice(2, 8)}`;
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'exerly-backup-'));
  const admin = new Client(connectionConfig(url));
  await admin.connect();
  try {
    const user = await signUp(api);
    const auth = { token: user.token, headers: {} };
    await api.post('/api/food', { name: 'Synthetic oats', calories: 380, protein: 13.5 }, auth);
    await api.post('/api/weight', { weight: 81.3 }, auth);
    await api.post(
      '/api/measurements',
      { client_id: randomUUID(), type: 'waist', value: 32.5, unit: 'in' },
      { ...auth, headers: { 'Idempotency-Key': randomUUID() } }
    );
    await api.post('/api/water', { deltaMl: 500, entry_date: '2026-10-06' }, auth);

    const dump = path.join(directory, 'exerly.dump');
    execFileSync(binary('pg_dump'), [
      '--dbname',
      url,
      '--schema',
      schema,
      '--format',
      'custom',
      '--file',
      dump,
    ]);
    await admin.query(`CREATE DATABASE ${database}`);
    const target = new URL(url);
    target.pathname = `/${database}`;
    execFileSync(binary('pg_restore'), [
      '--dbname',
      target.toString(),
      '--no-owner',
      '--exit-on-error',
      dump,
    ]);

    const original = await snapshot(url);
    const restored = await snapshot(target.toString());
    assert.ok(
      original.users.length >= 1 && original.food.length === 1 && original.sync_changes.length >= 3
    );
    assert.deepEqual(restored, original);
  } finally {
    await api.close();
    await admin.query(`DROP DATABASE IF EXISTS ${database}`);
    await admin.end();
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

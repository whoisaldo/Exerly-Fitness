// Concurrency guarantees on real PostgreSQL: no lost updates, no reused sync
// sequences, one effect per operation key, and nothing left by a rejection.

const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { startServer, signUp } = require('./helpers/server');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => {
  await api.close();
});

const entry_date = '2026-10-06';

test('parallel water additions from many devices all land', async () => {
  const user = await signUp(api);
  const results = await Promise.all(
    Array.from({ length: 25 }, () =>
      api.post(
        '/api/water',
        { deltaMl: 100, entry_date },
        {
          token: user.token,
          headers: { 'Idempotency-Key': randomUUID() },
        }
      )
    )
  );
  assert.ok(
    results.every((r) => r.status === 200),
    JSON.stringify(results.map((r) => r.status))
  );
  const saved = (await api.get(`/api/water?entry_date=${entry_date}`, { token: user.token })).body;
  assert.equal(saved.ml, 2500);
  assert.equal(saved.revision, 25);
});

test('parallel writes get unique, gap-free sync sequences', async () => {
  const user = await signUp(api);
  const token = user.token;
  const writes = [
    ...Array.from({ length: 10 }, () =>
      api.post(
        '/api/water',
        { deltaMl: 50, entry_date },
        { token, headers: { 'Idempotency-Key': randomUUID() } }
      )
    ),
    ...Array.from({ length: 10 }, (_, i) =>
      api.post(
        '/api/measurements',
        { client_id: randomUUID(), type: 'waist', value: 80 + i, unit: 'cm' },
        { token, headers: { 'Idempotency-Key': randomUUID() } }
      )
    ),
  ];
  const results = await Promise.all(writes);
  assert.ok(
    results.every((r) => r.status < 300),
    JSON.stringify(results.map((r) => r.status))
  );
  const feed = (await api.get('/api/sync?after=0', { token })).body;
  const sequences = feed.changes.map((c) => c.sequence);
  assert.equal(sequences.length, 20);
  assert.deepEqual(
    sequences,
    Array.from({ length: 20 }, (_, i) => i + 1)
  );
  assert.equal(feed.cursor, 20);
});

test('one operation key applies once under a burst of retries', async () => {
  const user = await signUp(api);
  const headers = { 'Idempotency-Key': randomUUID() };
  const results = await Promise.all(
    Array.from({ length: 12 }, () =>
      api.post('/api/water', { deltaMl: 250, entry_date }, { token: user.token, headers })
    )
  );
  assert.ok(results.every((r) => r.status === 200));
  // Replays come from a JSONB receipt, so key order may differ; content may not.
  for (const result of results) assert.deepEqual(result.body, results[0].body);
  const saved = (await api.get(`/api/water?entry_date=${entry_date}`, { token: user.token })).body;
  assert.equal(saved.ml, 250);
  assert.equal(await api.store.count('operations', { account_id: user.user._id }), 1);
  assert.equal(await api.store.count('sync_changes', { account_id: user.user._id }), 1);
});

test('a rejected mutation leaves no entity, receipt or sync event and frees its key', async () => {
  const user = await signUp(api);
  const key = randomUUID();
  const client_id = randomUUID();
  const rejected = await api.post(
    '/api/measurements',
    { client_id, type: 'waist', value: -5, unit: 'cm' },
    { token: user.token, headers: { 'Idempotency-Key': key } }
  );
  assert.equal(rejected.status, 400);
  assert.equal(await api.store.count('measurements', { account_id: user.user._id }), 0);
  assert.equal(await api.store.count('operations', { account_id: user.user._id }), 0);
  assert.equal(await api.store.count('sync_changes', { account_id: user.user._id }), 0);

  const accepted = await api.post(
    '/api/measurements',
    { client_id, type: 'waist', value: 81, unit: 'cm' },
    { token: user.token, headers: { 'Idempotency-Key': key } }
  );
  assert.equal(accepted.status, 201);
  assert.equal(await api.store.count('sync_changes', { account_id: user.user._id }), 1);
});

test('a failure inside a transaction rolls back every write in it', async () => {
  const user = await signUp(api);
  await assert.rejects(
    api.store.transaction(async () => {
      await api.store.insert('water', {
        account_id: user.user._id,
        email: user.email,
        entry_date,
        ml: 1,
      });
      await api.store.insert('sync_changes', {
        account_id: user.user._id,
        sequence: 1,
        kind: 'water',
      });
      throw new Error('boom');
    }),
    /boom/
  );
  assert.equal(await api.store.count('water', { account_id: user.user._id }), 0);
  assert.equal(await api.store.count('sync_changes', { account_id: user.user._id }), 0);
});

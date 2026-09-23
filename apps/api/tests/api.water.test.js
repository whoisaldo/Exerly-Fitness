const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { startServer, signUp } = require('./helpers/server');
const dates = require('../lib/dates');
let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => {
  await api.close();
});

test('water additions converge across devices, replay once, and reach summary, sync and export', async () => {
  const { token, timezone } = await signUp(api);
  const entry_date = dates.today(timezone);
  const initial = await api.get(`/api/water?entry_date=${entry_date}`, { token });
  assert.equal(initial.body.revision, 0);
  const headers = { 'Idempotency-Key': randomUUID() };
  const body = { deltaMl: 250, entry_date };
  const first = await api.post('/api/water', body, { token, headers });
  assert.equal(first.status, 200);
  assert.equal(first.body.ml, 250);
  const additions = await Promise.all(
    Array.from({ length: 8 }, () =>
      api.post('/api/water', body, {
        token,
        headers: { 'Idempotency-Key': randomUUID() },
      })
    )
  );
  assert.ok(additions.every((row) => row.status === 200));
  const replay = await api.post('/api/water', body, { token, headers });
  assert.deepEqual(replay.body, first.body);
  const saved = (await api.get(`/api/water?entry_date=${entry_date}`, { token })).body;
  assert.equal(saved.ml, 2250);
  assert.equal(saved.revision, 9);
  assert.equal(saved.id, first.body.id);
  const summary = (await api.get(`/api/summary?entry_date=${entry_date}`, { token })).body;
  assert.equal(summary.water_ml, saved.ml);
  assert.equal(summary.water.revision, saved.revision);
  const changes = (await api.get('/api/sync', { token })).body.changes.filter(
    (row) => row.kind === 'water'
  );
  assert.equal(changes.length, 9);
  assert.ok(changes.every((row) => row.entity_id === entry_date && row.server_id === saved.id));
  assert.equal(changes.at(-1).payload.ml, saved.ml);
  assert.equal((await api.get('/api/export', { token })).body.water[0].ml, saved.ml);
  const other = await signUp(api);
  const separate = await api.post('/api/water', body, { token: other.token, headers });
  assert.equal(separate.body.ml, 250);
  assert.equal((await api.get('/api/water', { token })).body.ml, saved.ml);
});

test('water corrections check revisions and preserve date and nonnegative totals', async () => {
  const { token, timezone } = await signUp(api);
  const entry_date = dates.addDays(dates.today(timezone), -1);
  const first = await api.post('/api/water', { entry_date, ml: 1000, base_revision: 0 }, { token });
  assert.equal(first.status, 200);
  const stale = await api.post('/api/water', { entry_date, ml: 500, base_revision: 0 }, { token });
  assert.equal(stale.status, 409);
  assert.equal(stale.body.details.current.ml, 1000);
  const floored = await api.post('/api/water', { entry_date, deltaMl: -2000 }, { token });
  assert.equal(floored.body.ml, 0);
  assert.equal(floored.body.revision, 2);
  assert.equal((await api.get('/api/water', { token })).body.revision, 0);
  for (const invalid of [
    { deltaMl: 5001 },
    { deltaMl: 'bad' },
    { deltaMl: 250, entry_date: '2099-01-01' },
  ]) {
    assert.equal((await api.post('/api/water', invalid, { token })).status, 400);
  }
});

test('existing unversioned water keeps its record and amount when first synchronized', async () => {
  const user = await signUp(api);
  const entry_date = dates.addDays(dates.today(user.timezone), -2);
  const original = await api.store.insert('water', { email: user.email, entry_date, ml: 875 });
  const before = await api.get(`/api/water?entry_date=${entry_date}`, { token: user.token });
  assert.equal(before.body.id, original.id);
  assert.equal(before.body.revision, 1);
  assert.equal(before.body.ml, 875);
  const saved = await api.post(
    '/api/water',
    { entry_date, deltaMl: 250 },
    {
      token: user.token,
      headers: { 'Idempotency-Key': randomUUID() },
    }
  );
  assert.equal(saved.status, 200);
  assert.equal(saved.body.id, original.id);
  assert.equal(saved.body.ml, 1125);
  assert.equal(saved.body.revision, 2);
  const stored = await api.store.findOne('water', { id: original.id });
  assert.equal(stored.account_id, user.user._id);
  assert.equal(await api.store.count('water', { email: user.email, entry_date }), 1);
});

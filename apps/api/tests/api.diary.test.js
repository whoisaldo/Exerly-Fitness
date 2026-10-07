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

test('diary completeness is explicit, versioned, replayable and included in sync and export', async () => {
  const { token, timezone } = await signUp(api);
  const entry_date = dates.today(timezone);
  const path = `/api/diary/day?entry_date=${entry_date}`;
  assert.equal((await api.get(path, { token })).body.status, 'in_progress');
  await api.post('/api/food', { name: 'One snack', calories: 150, entry_date }, { token });
  assert.equal(
    (await api.get(`/api/summary?entry_date=${entry_date}`, { token })).body.diary_day.status,
    'in_progress'
  );
  const body = { entry_date, status: 'complete', note: 'All meals recorded', base_revision: 0 };
  const headers = { 'Idempotency-Key': randomUUID() };
  const saved = await api.put('/api/diary/day', body, { token, headers });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.revision, 1);
  const changed = await api.put(
    '/api/diary/day',
    { ...body, status: 'estimated', base_revision: 1 },
    { token }
  );
  assert.equal(changed.body.revision, 2);
  const replay = await api.put('/api/diary/day', body, { token, headers });
  assert.equal(replay.body.revision, 1);
  assert.equal((await api.get(path, { token })).body.status, 'estimated');
  const stale = await api.put(
    '/api/diary/day',
    { ...body, status: 'excluded', base_revision: 1 },
    { token }
  );
  assert.equal(stale.status, 409);
  assert.equal(stale.body.details.current.status, 'estimated');
  const writes = await Promise.all(
    ['complete', 'excluded'].map((status) =>
      api.put('/api/diary/day', { ...body, status, base_revision: 2 }, { token })
    )
  );
  assert.deepEqual(writes.map((row) => row.status).sort(), [200, 409]);
  const latest = (await api.get(path, { token })).body;
  assert.equal(latest.revision, 3);
  const feed = (await api.get('/api/sync', { token })).body.changes.filter(
    (row) => row.kind === 'diary_day'
  );
  assert.deepEqual(
    feed.map((row) => row.revision),
    [1, 2, 3]
  );
  assert.ok(feed.every((row) => row.entity_id === entry_date));
  assert.equal(
    (await api.get(`/api/summary?entry_date=${entry_date}`, { token })).body.diary_day.status,
    latest.status
  );
  assert.equal((await api.get('/api/export', { token })).body.diary_days[0].revision, 3);
  const other = await signUp(api);
  assert.equal((await api.get(path, { token: other.token })).body.revision, 0);
  assert.deepEqual((await api.get('/api/export', { token: other.token })).body.diary_days, []);
});

test('diary days reject unchecked, invalid and future status changes', async () => {
  const { token } = await signUp(api);
  for (const body of [
    { status: 'complete' },
    { status: 'unknown', base_revision: 0 },
    { status: 'complete', base_revision: -1 },
    { status: 'complete', base_revision: 0, entry_date: '2099-01-01' },
    { status: 'complete', base_revision: 0, note: 'x'.repeat(501) },
  ])
    assert.equal((await api.put('/api/diary/day', body, { token })).status, 400);
  const legacy = await api.put('/api/diary/day', { status: 'excluded', revision: 0 }, { token });
  assert.equal(legacy.status, 200);
  assert.equal(legacy.body.revision, 1);
});

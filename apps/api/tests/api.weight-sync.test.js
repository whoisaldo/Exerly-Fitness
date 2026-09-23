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

test('competing manual weigh-ins require review and an old acknowledgement cannot replace the newer reading', async () => {
  const user = await signUp(api);
  const token = user.token;
  const entry_date = dates.today(user.timezone);
  const initial = await api.get('/api/weight/day', { token });
  assert.equal(initial.body.weight_kg, null);
  assert.equal(initial.body.revision, 0);
  const headers = { 'Idempotency-Key': randomUUID() };
  const body = {
    weight_kg: 72.25,
    entry_date,
    source: 'manual',
    base_revision: 0,
    note: 'Morning',
  };
  const first = await api.put('/api/weight/day', body, { token, headers });
  assert.equal(first.status, 200);
  const racing = await Promise.all(
    [72.5, 73].map((weight_kg) =>
      api.put('/api/weight/day', { ...body, weight_kg, base_revision: 1 }, { token })
    )
  );
  assert.deepEqual(racing.map((row) => row.status).sort(), [200, 409]);
  const current = (await api.get('/api/weight/day', { token })).body;
  assert.equal(current.revision, 2);
  assert.equal((await api.put('/api/weight/day', body, { token, headers })).body.revision, 1);
  assert.equal((await api.get('/api/weight/day', { token })).body.weight_kg, current.weight_kg);
  assert.equal(
    (await api.post('/api/weight', { weight: 90 }, { token })).status,
    409,
    'unchecked old writes cannot replace an adopted record'
  );
  assert.equal((await api.get('/api/weight', { token })).body.length, 1);
  const feed = (await api.get('/api/sync', { token })).body.changes.filter(
    (row) => row.kind === 'weight'
  );
  assert.deepEqual(
    feed.map((row) => row.revision),
    [1, 2]
  );
  assert.ok(feed.every((row) => row.entity_id === entry_date && row.server_id === first.body.id));
  assert.equal(
    (await api.get('/api/export', { token })).body.weights[0].weight_kg,
    current.weight_kg
  );
  const other = await signUp(api);
  assert.equal((await api.get(`/api/weight/${first.body.id}`, { token: other.token })).status, 404);
  assert.equal((await api.get('/api/weight/day', { token: other.token })).body.revision, 0);
});

test('weight tombstones prevent resurrection, preserve identity on restore and correct the profile and trend', async () => {
  const user = await signUp(api);
  const token = user.token;
  const today = dates.today(user.timezone);
  const yesterday = dates.addDays(today, -1);
  await api.put(
    '/api/weight/day',
    { weight_kg: 73, entry_date: yesterday, base_revision: 0 },
    { token }
  );
  const current = (
    await api.put(
      '/api/weight/day',
      { weight_kg: 72.25, entry_date: today, base_revision: 0 },
      { token }
    )
  ).body;
  const headers = { 'Idempotency-Key': randomUUID() };
  const removed = await api.del(`/api/weight/${current.id}`, {
    token,
    headers: { ...headers, 'If-Match': '1' },
  });
  assert.equal(removed.status, 200);
  assert.ok(removed.body.weight.deleted_at);
  assert.equal((await api.get('/api/me', { token })).body.weight, 73);
  assert.equal((await api.get('/api/summary', { token })).body.weight, null);
  assert.equal((await api.get('/api/weight/trend', { token })).body.summary.weigh_ins, 1);
  assert.equal(
    (await api.put('/api/weight/day', { weight_kg: 70, base_revision: 2 }, { token })).status,
    409
  );
  assert.equal((await api.post('/api/weight', { weight: 70 }, { token })).status, 409);
  assert.equal(
    (await api.post(`/api/weight/${current.id}/restore`, { base_revision: 1 }, { token })).status,
    409
  );
  const restored = await api.post(
    `/api/weight/${current.id}/restore`,
    { base_revision: 2 },
    { token }
  );
  assert.equal(restored.body.id, current.id);
  assert.equal(restored.body.revision, 3);
  assert.equal((await api.get('/api/me', { token })).body.weight, 72.25);
  const replay = await api.del(`/api/weight/${current.id}`, {
    token,
    headers: { ...headers, 'If-Match': '1' },
  });
  assert.equal(replay.body.weight.revision, 2);
  assert.equal((await api.get('/api/weight/day', { token })).body.revision, 3);
  assert.equal((await api.get('/api/weight', { token })).body.length, 2);
});

test('imports never replace manual readings and legacy adoption preserves the original identity', async () => {
  const user = await signUp(api);
  const token = user.token;
  const day = dates.today(user.timezone);
  const original = await api.store.insert('weights', {
    email: user.email,
    entry_date: day,
    weight_kg: 80,
    source: 'manual',
  });
  const blocked = await api.put(
    '/api/weight/day',
    { weight_kg: 81, source: 'healthkit', base_revision: 1 },
    { token }
  );
  assert.equal(blocked.status, 409);
  assert.equal(blocked.body.details.current.weight_kg, 80);
  const saved = await api.put(
    '/api/weight/day',
    { weightLb: 176.37, source: 'manual', base_revision: 1 },
    { token }
  );
  assert.equal(saved.status, 200);
  assert.equal(saved.body.id, original.id);
  assert.equal(saved.body.account_id, user.user._id);
  assert.equal(saved.body.weight_kg, 80);
  const past = dates.addDays(day, -1);
  const imported = await api.put(
    '/api/weight/day',
    { weight_kg: 79, entry_date: past, source: 'import', base_revision: 0 },
    { token }
  );
  assert.equal(imported.status, 200);
  const manual = await api.put(
    '/api/weight/day',
    { weight_kg: 78, entry_date: past, source: 'manual', base_revision: 1 },
    { token }
  );
  assert.equal(manual.status, 200);
  assert.equal(
    (
      await api.put(
        '/api/weight/day',
        { weight_kg: 79, entry_date: past, source: 'import', base_revision: 2 },
        { token }
      )
    ).status,
    409
  );
  for (const body of [
    { weight_kg: 0 },
    { weightLb: 44 },
    { weight_kg: 501 },
    { weight_kg: 70, entry_date: '2099-01-01' },
  ]) {
    assert.equal(
      (await api.put('/api/weight/day', { ...body, base_revision: 2 }, { token })).status,
      400
    );
  }
});

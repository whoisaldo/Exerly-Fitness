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

test('food edit revisions, deletion markers and explicit undo survive replay', async () => {
  const user = await signUp(api);
  const headers = { 'Idempotency-Key': randomUUID() };
  const clientID = randomUUID();
  const body = {
    name: 'Oat drink',
    calories: 60,
    servings: 1.5,
    client_id: clientID,
    nutrition_basis: { amount: 100, unit: 'ml' },
  };
  const created = await api.post('/api/food', body, { token: user.token, headers });
  assert.equal(created.status, 201);
  const id = created.body.id;
  assert.equal(created.body.revision, 1);
  const edited = await api.put(
    `/api/food/${id}`,
    { ...body, servings: 0.75, base_revision: 1 },
    { token: user.token }
  );
  assert.equal(edited.body.calories, 45);
  assert.equal(edited.body.nutrition_snapshot.calories, 60);
  assert.equal(edited.body.revision, 2);
  const stale = await api.put(
    `/api/food/${id}`,
    { ...body, servings: 2, base_revision: 1 },
    { token: user.token }
  );
  assert.equal(stale.status, 409);
  assert.equal(stale.body.details.current.calories, 45);
  const deletion = await api.del(`/api/food/${id}`, {
    token: user.token,
    headers: { 'If-Match': '2' },
  });
  assert.equal(deletion.body.food.revision, 3);
  assert.equal((await api.get('/api/summary', { token: user.token })).body.consumed.calories, 0);
  const replay = await api.post('/api/food', body, { token: user.token, headers });
  assert.equal(replay.body.id, id);
  assert.equal(
    (await api.get('/api/summary', { token: user.token })).body.consumed.calories,
    0,
    'old create replay cannot resurrect deletion'
  );
  const newKey = await api.post('/api/food', body, { token: user.token });
  assert.equal(newKey.status, 409);
  const restored = await api.post(
    `/api/food/${id}/restore`,
    { base_revision: 3 },
    { token: user.token }
  );
  assert.equal(restored.body.id, id);
  assert.equal(restored.body.revision, 4);
  assert.equal((await api.get('/api/summary', { token: user.token })).body.consumed.calories, 45);
  const changes = await api.get('/api/sync?after=0', { token: user.token });
  assert.deepEqual(
    changes.body.changes.map((c) => c.revision),
    [1, 2, 3, 4]
  );
  assert.equal(changes.body.changes[2].deleted, true);
  assert.equal(changes.body.cursor, 4);
  const after = await api.get('/api/sync?after=3', { token: user.token });
  assert.equal(after.body.changes.length, 1);
  const other = await signUp(api);
  assert.equal(
    (await api.get(`/api/food/${id}?include_deleted=true`, { token: other.token })).status,
    404
  );
  assert.deepEqual((await api.get('/api/sync', { token: other.token })).body.changes, []);
});

test('concurrent offline additions create a contiguous change feed without duplicates', async () => {
  const user = await signUp(api);
  const results = await Promise.all(
    Array.from({ length: 8 }, (_, i) =>
      api.post(
        '/api/food',
        {
          name: `Entry ${i}`,
          calories: 100,
          client_id: randomUUID(),
        },
        { token: user.token, headers: { 'Idempotency-Key': randomUUID() } }
      )
    )
  );
  assert.ok(results.every((r) => r.status === 201));
  const changes = await api.get('/api/sync', { token: user.token });
  assert.deepEqual(
    changes.body.changes.map((c) => c.sequence),
    [1, 2, 3, 4, 5, 6, 7, 8]
  );
});

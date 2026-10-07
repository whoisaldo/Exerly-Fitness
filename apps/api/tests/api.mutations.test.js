const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer, signUp } = require('./helpers/server');
let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

test('concurrent food retries create one entry and one personal library record', async () => {
  const user = await signUp(api);
  const options = { token: user.token, headers: { 'Idempotency-Key': 'food-request-001' } };
  const body = { name: 'Yogurt', calories: 120, protein: 15, servings: 1.5 };
  const results = await Promise.all(
    Array.from({ length: 8 }, () => api.post('/api/food', body, options))
  );
  for (const result of results) {
    assert.equal(result.status, 201);
    assert.deepEqual(result.body, results[0].body);
  }
  assert.equal(await api.store.count('food', { email: user.email }), 1);
  assert.equal(await api.store.count('library_foods', { email: user.email }), 1);
  assert.equal((await api.post('/api/food', { ...body, servings: 2 }, options)).status, 409);
  const other = await signUp(api);
  assert.equal((await api.post('/api/food', body, { ...options, token: other.token })).status, 201);
});

test('SQLite isolates unrelated reads and writes from a transaction that rolls back', async () => {
  const user = await signUp(api);
  let started;
  let release;
  const ready = new Promise((resolve) => {
    started = resolve;
  });
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const tx = api.store.transaction(async () => {
    await api.store.update('users', { email: user.email }, { name: 'Uncommitted' });
    started();
    await gate;
    throw new Error('Rollback');
  });
  await ready;
  const read = api.store.findOne('users', { email: user.email });
  const write = api.store.insert('activities', { email: user.email, activity: 'Walk' });
  release();
  await assert.rejects(tx, /Rollback/);
  assert.equal((await read).name, user.name);
  assert.equal((await write).activity, 'Walk');
  assert.equal(await api.store.count('activities', { email: user.email }), 1);
});

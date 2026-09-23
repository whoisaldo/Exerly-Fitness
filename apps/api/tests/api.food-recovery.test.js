const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { startServer, signUp } = require('./helpers/server');
const dates = require('../lib/dates');
let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

test('fractional portions retain their original nutrition snapshot through editing, recents and export', async () => {
  const user = await signUp(api);
  const options = { token: user.token, headers: { 'Idempotency-Key': randomUUID() } };
  const input = {
    client_id: randomUUID(),
    name: 'Precise oats',
    calories: 99.5,
    protein: 3.3333,
    carbs: null,
    fat: 2.1111,
    fiber: 0,
    sugar: null,
    sodium: 123.4567,
    saturated_fat: 0.5555,
    servings: 1.5,
    nutrition_basis: { amount: 100, unit: 'g' },
    mealType: 'breakfast',
    base_revision: 0,
  };
  const saved = await api.post('/api/food', input, options);
  assert.equal(saved.status, 201);
  assert.equal(saved.body.calories, 149);
  assert.equal(saved.body.nutrition_snapshot.calories, 99.5);
  assert.equal(saved.body.nutrition_snapshot.protein, 3.3333);
  assert.equal(saved.body.nutrition_snapshot.sodium, 123.4567);
  const changed = await api.put(
    `/api/food/${saved.body.id}`,
    { ...input, servings: 0.75, base_revision: 1 },
    { token: user.token, headers: { 'Idempotency-Key': randomUUID() } }
  );
  assert.equal(changed.status, 200);
  assert.equal(changed.body.calories, 75);
  assert.equal(changed.body.protein, 2.5);
  assert.equal(changed.body.sodium, 92.59);
  assert.equal(changed.body.carbs, null);
  assert.deepEqual(changed.body.nutrition_snapshot, saved.body.nutrition_snapshot);
  const library = await api.get('/api/library/foods', { token: user.token });
  assert.equal(library.body[0].calories, 99.5);
  assert.equal(library.body[0].protein, 3.3333);
  const exported = await api.get('/api/export', { token: user.token });
  assert.equal(exported.body.food[0].sodium, 92.59);
  assert.deepEqual(exported.body.food[0].nutrition_snapshot, saved.body.nutrition_snapshot);
});

test('a revisioned food entry rejects unversioned edits and lists deletion markers by day with pagination', async () => {
  const user = await signUp(api);
  const day = dates.today(user.timezone);
  const opts = { token: user.token };
  const created = [];
  for (let index = 0; index < 3; index++) {
    const row = await api.post(
      '/api/food',
      { name: `Recovery ${index}`, calories: 100, client_id: randomUUID(), base_revision: 0 },
      opts
    );
    assert.equal(row.status, 201);
    created.push(row.body);
  }
  const stale = await api.put(
    `/api/food/${created[0].id}`,
    { name: 'Overwrite', calories: 20 },
    opts
  );
  assert.equal(stale.status, 409);
  const deleted = await api.del(`/api/food/${created[1].id}`, {
    ...opts,
    body: { base_revision: 1 },
  });
  assert.equal(deleted.status, 200);
  const rows = [];
  for (let page = 1; page <= 3; page++) {
    const response = await api.get(
      `/api/food?date=${day}&include_deleted=true&limit=1&page=${page}`,
      opts
    );
    assert.equal(response.status, 200);
    assert.equal(response.body.length, 1);
    rows.push(...response.body);
  }
  assert.equal(new Set(rows.map((row) => row.id)).size, 3);
  assert.equal(rows.find((row) => row.id === deleted.body.food.id).revision, 2);
  assert.ok(rows.find((row) => row.id === deleted.body.food.id).deleted_at);
  const restored = await api.post(
    `/api/food/${deleted.body.food.id}/restore`,
    { base_revision: 2 },
    opts
  );
  assert.equal(restored.status, 200);
  assert.equal(restored.body.revision, 3);
});

test('entered mass and volume quantities agree with the stored nutrition basis and reject mismatches', async () => {
  const user = await signUp(api);
  const opts = { token: user.token };
  const input = {
    name: 'Measured portion',
    calories: 200,
    servings: 0.35,
    nutrition_basis: { amount: 100, unit: 'g' },
    entered_quantity: { amount: 35, unit: 'g' },
    base_revision: 0,
    client_id: randomUUID(),
  };
  const created = await api.post('/api/food', input, opts);
  assert.equal(created.status, 201);
  assert.equal(created.body.calories, 70);
  assert.deepEqual(created.body.entered_quantity, { amount: 35, unit: 'g' });
  const bad = await api.put(
    `/api/food/${created.body.id}`,
    {
      ...input,
      base_revision: 1,
      entered_quantity: { amount: 35, unit: 'ml' },
    },
    opts
  );
  assert.equal(bad.status, 400);
  const mismatched = await api.put(
    `/api/food/${created.body.id}`,
    {
      ...input,
      base_revision: 1,
      servings: 0.5,
    },
    opts
  );
  assert.equal(mismatched.status, 400);
  const unchanged = await api.get(`/api/food/${created.body.id}`, opts);
  assert.equal(unchanged.body.revision, 1);
  const ounces = await api.put(
    `/api/food/${created.body.id}`,
    {
      ...input,
      base_revision: 1,
      servings: 28.349523125 / 100,
      entered_quantity: { amount: 1, unit: 'oz' },
    },
    opts
  );
  assert.equal(ounces.status, 200);
  assert.deepEqual(ounces.body.entered_quantity, { amount: 1, unit: 'oz' });
  assert.equal(ounces.body.calories, 57);
  const drink = await api.post(
    '/api/food',
    {
      name: 'Fluid ounces',
      calories: 60,
      nutrition_basis: { amount: 100, unit: 'ml' },
      servings: 29.5735295625 / 100,
      entered_quantity: { amount: 1, unit: 'fl_oz' },
    },
    opts
  );
  assert.equal(drink.status, 201);
  assert.equal(drink.body.calories, 18);
  const exported = await api.get('/api/export', opts);
  assert.deepEqual(exported.body.food.find((row) => row.id === created.body.id).entered_quantity, {
    amount: 1,
    unit: 'oz',
  });
});

test('food totals use the same positive half-up rounding as native pending entries', async () => {
  const user = await signUp(api);
  const result = await api.post(
    '/api/food',
    {
      name: 'Rounding boundary',
      calories: 100.5,
      protein: 2.675,
      carbs: 1.125,
      fat: null,
      servings: 1,
    },
    { token: user.token }
  );
  assert.equal(result.status, 201);
  assert.equal(result.body.calories, 101);
  assert.equal(result.body.protein, 2.68);
  assert.equal(result.body.carbs, 1.13);
  assert.equal(result.body.fat, null);
  assert.equal(result.body.nutrition_snapshot.protein, 2.675);
});

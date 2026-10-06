// Adversarial ownership checks: account B tries to read, change, delete and
// restore every ID-addressed record that account A owns.

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

async function createAll(token) {
  const auth = { token };
  const food = await api.post('/api/food', { name: 'Owner oats', calories: 300 }, auth);
  const weight = await api.post('/api/weight', { weight: 80.2 }, auth);
  const measurement = await api.post(
    '/api/measurements',
    { client_id: randomUUID(), type: 'waist', value: 80, unit: 'cm' },
    auth
  );
  const workout = await api.post('/api/workouts', { name: 'Owner push', exercises: [] }, auth);
  const libraryFood = await api.post(
    '/api/library/foods',
    { name: 'Owner shake', calories: 200 },
    auth
  );
  const recipe = await api.post(
    '/api/library/recipes',
    { name: 'Owner chilli', servings: 2, ingredients: [{ name: 'Beans', calories: 120 }] },
    auth
  );
  for (const res of [food, weight, measurement, workout, libraryFood, recipe]) {
    assert.ok([200, 201].includes(res.status), JSON.stringify(res.body));
  }
  return {
    food: food.body.id ?? food.body._id,
    weight: weight.body.id ?? weight.body._id,
    measurement: measurement.body.id,
    workout: workout.body.id ?? workout.body._id,
    libraryFood: libraryFood.body.id ?? libraryFood.body._id,
    recipe: recipe.body.id ?? recipe.body._id,
  };
}

test('another account cannot read, change, delete or restore any record', async () => {
  const owner = await signUp(api);
  const intruder = await signUp(api);
  const ids = await createAll(owner.token);
  const as = { token: intruder.token };

  const attempts = [
    ['get', `/api/food/${ids.food}`],
    ['put', `/api/food/${ids.food}`, { name: 'Taken', calories: 1 }],
    ['del', `/api/food/${ids.food}`],
    ['post', `/api/food/${ids.food}/restore`, {}],
    ['get', `/api/weight/${ids.weight}`],
    ['put', `/api/weight/${ids.weight}`, { weight: 50 }],
    ['del', `/api/weight/${ids.weight}`],
    ['post', `/api/weight/${ids.weight}/restore`, {}],
    ['get', `/api/measurements/${ids.measurement}`],
    ['put', `/api/measurements/${ids.measurement}`, { type: 'waist', value: 1, unit: 'cm' }],
    ['del', `/api/measurements/${ids.measurement}`],
    ['post', `/api/measurements/${ids.measurement}/restore`, {}],
    ['put', `/api/workouts/${ids.workout}`, { name: 'Taken', exercises: [] }],
    ['del', `/api/workouts/${ids.workout}`],
    ['put', `/api/library/foods/${ids.libraryFood}`, { name: 'Taken', calories: 1 }],
    ['post', `/api/library/foods/${ids.libraryFood}/favorite`, {}],
    ['del', `/api/library/foods/${ids.libraryFood}`],
    [
      'put',
      `/api/library/recipes/${ids.recipe}`,
      { name: 'Taken', servings: 1, ingredients: [{ name: 'x', calories: 1 }] },
    ],
    ['del', `/api/library/recipes/${ids.recipe}`],
  ];
  for (const [method, path, body] of attempts) {
    const res =
      method === 'get' || method === 'del'
        ? await api[method](path, as)
        : await api[method](path, body, as);
    assert.ok([403, 404, 409].includes(res.status), `${method} ${path} returned ${res.status}`);
  }

  // Lists and the sync feed show the intruder nothing of the owner's.
  for (const path of [
    '/api/food',
    '/api/weight',
    '/api/measurements',
    '/api/workouts',
    '/api/library/foods',
    '/api/library/recipes',
    '/api/sync',
  ]) {
    const res = await api.get(path, as);
    assert.equal(res.status, 200, path);
    const text = JSON.stringify(res.body);
    for (const id of Object.values(ids)) assert.ok(!text.includes(id), `${path} leaked ${id}`);
    assert.ok(!text.includes('Owner'), `${path} leaked owner data`);
  }

  // The owner's records are untouched.
  const auth = { token: owner.token };
  assert.equal((await api.get(`/api/food/${ids.food}`, auth)).body.name, 'Owner oats');
  assert.equal((await api.get(`/api/weight/${ids.weight}`, auth)).body.weight_kg, 80.2);
  assert.equal((await api.get(`/api/measurements/${ids.measurement}`, auth)).body.value, 80);
  const workouts = (await api.get('/api/workouts', auth)).body;
  assert.equal(workouts.find((w) => (w.id ?? w._id) === ids.workout)?.name, 'Owner push');
  const foods = (await api.get('/api/library/foods', auth)).body;
  assert.equal(foods.find((f) => (f.id ?? f._id) === ids.libraryFood)?.is_favorite, false);
  const recipes = (await api.get('/api/library/recipes', auth)).body;
  assert.ok(recipes.some((r) => (r.id ?? r._id) === ids.recipe));
});

test('malformed and foreign ids never reach another account or raise a server error', async () => {
  const user = await signUp(api);
  const auth = { token: user.token };
  for (const id of ['1', 'not-a-uuid', "1' OR '1'='1", randomUUID()]) {
    const res = await api.get(`/api/food/${encodeURIComponent(id)}`, auth);
    assert.equal(res.status, 404, id);
  }
});

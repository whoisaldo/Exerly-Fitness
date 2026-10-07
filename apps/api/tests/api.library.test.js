const test = require('node:test');
const assert = require('node:assert');
const { startServer, signUp } = require('./helpers/server');

let api;
let user;
test.before(async () => {
  api = await startServer();
  user = await signUp(api);
});
test.after(async () => api.close());

const auth = () => ({ token: user.token });

test('logging a food remembers it in the library at per-serving values', async () => {
  await api.post(
    '/api/food',
    { name: 'Greek Yogurt', brand: 'Fage', calories: 120, protein: 20, servings: 2 },
    auth()
  );

  const res = await api.get('/api/library/foods', auth());
  const entry = res.body.find((f) => f.name === 'Greek Yogurt');

  assert.ok(entry, 'the logged food should be in the library');
  // 2 servings were logged, so the library keeps the per-serving numbers.
  assert.equal(entry.calories, 120);
  assert.equal(entry.protein, 20);
  assert.equal(entry.use_count, 1);
});

test('logging the same food again bumps its use count instead of duplicating it', async () => {
  await api.post(
    '/api/food',
    { name: 'Greek Yogurt', brand: 'Fage', calories: 120, protein: 20 },
    auth()
  );

  const res = await api.get('/api/library/foods', auth());
  const matches = res.body.filter((f) => f.name === 'Greek Yogurt');

  assert.equal(matches.length, 1);
  assert.equal(matches[0].use_count, 2);
});

test('saveToLibrary false keeps a one-off out of the library', async () => {
  await api.post(
    '/api/food',
    { name: 'Airport sandwich', calories: 600, protein: 25, saveToLibrary: false },
    auth()
  );
  const res = await api.get('/api/library/foods', auth());
  assert.ok(!res.body.some((f) => f.name === 'Airport sandwich'));
});

test('a custom food can be created, favourited, and found by search', async () => {
  const created = await api.post(
    '/api/library/foods',
    {
      name: 'Mum protein shake',
      calories: 240,
      protein: 35,
      carbs: 12,
      fat: 4,
      servingSize: '1 scoop + 300ml milk',
    },
    auth()
  );
  assert.equal(created.status, 201);
  assert.equal(created.body.source, 'custom');

  const favourited = await api.post(`/api/library/foods/${created.body.id}/favorite`, {}, auth());
  assert.equal(favourited.body.is_favorite, true);

  const favourites = await api.get('/api/library/foods?favorites=true', auth());
  assert.equal(favourites.body.length, 1);
  assert.equal(favourites.body[0].name, 'Mum protein shake');

  // `local=true` skips the outbound provider calls, so this test needs no network.
  const search = await api.get('/api/food/search?q=protein&local=true', auth());
  assert.equal(search.body.library.length, 1);
  assert.equal(search.body.results.length, 0);
});

test('library search does not leak another user foods', async () => {
  const other = await signUp(api);
  const res = await api.get('/api/food/search?q=protein&local=true', { token: other.token });
  assert.equal(res.body.library.length, 0);
});

test('a recipe reports both totals and per-serving macros', async () => {
  const res = await api.post(
    '/api/library/recipes',
    {
      name: 'Chilli',
      servings: 4,
      ingredients: [
        { name: 'Beef mince', calories: 250, protein: 26, fat: 15, servings: 5 },
        { name: 'Kidney beans', calories: 120, protein: 8, carbs: 22, servings: 2 },
        { name: 'Chopped tomatoes', calories: 80, protein: 4, carbs: 16 },
      ],
    },
    auth()
  );

  assert.equal(res.status, 201);
  // 250*5 + 120*2 + 80 = 1570
  assert.equal(res.body.total.calories, 1570);
  assert.equal(res.body.per_serving.calories, Math.round(1570 / 4));
  assert.equal(res.body.total.protein, 26 * 5 + 8 * 2 + 4);
});

test('a recipe needs at least one ingredient', async () => {
  const res = await api.post('/api/library/recipes', { name: 'Empty', ingredients: [] }, auth());
  assert.equal(res.status, 400);
});

test('a recipe can be logged as a meal through batch', async () => {
  const recipes = await api.get('/api/library/recipes', auth());
  const chilli = recipes.body.find((r) => r.name === 'Chilli');

  const res = await api.post(
    '/api/food/batch',
    {
      mealType: 'dinner',
      items: [
        {
          name: `${chilli.name} (1 serving)`,
          calories: chilli.per_serving.calories,
          protein: chilli.per_serving.protein,
          carbs: chilli.per_serving.carbs,
          fat: chilli.per_serving.fat,
        },
      ],
    },
    auth()
  );

  assert.equal(res.status, 201);
  assert.equal(res.body.created[0].meal_type, 'dinner');
  assert.equal(res.body.created[0].calories, chilli.per_serving.calories);
});

test('a library food can be deleted', async () => {
  const list = await api.get('/api/library/foods', auth());
  const target = list.body[0];

  const res = await api.del(`/api/library/foods/${target.id}`, auth());
  assert.equal(res.status, 200);

  const after = await api.get('/api/library/foods', auth());
  assert.ok(!after.body.some((f) => f.id === target.id));
});

test('search rejects a missing query', async () => {
  const res = await api.get('/api/food/search?local=true', auth());
  assert.equal(res.status, 400);
});

test('an unknown route returns a clean 404', async () => {
  const res = await api.get('/api/does-not-exist', auth());
  assert.equal(res.status, 404);
  assert.match(res.body.message, /No route for GET/);
});

test('an oversized body is rejected rather than buffered', async () => {
  const res = await api.post(
    '/api/library/foods',
    { name: 'x'.repeat(400 * 1024), calories: 1 },
    auth()
  );
  assert.ok(res.status === 413 || res.status === 400, `got ${res.status}`);
});

test('batch logging also remembers items in the library', async () => {
  const fresh = await signUp(api);
  await api.post(
    '/api/food/batch',
    {
      mealType: 'dinner',
      items: [
        { name: 'Batch item one', calories: 300, protein: 20 },
        { name: 'Batch item two', calories: 150, protein: 5 },
      ],
    },
    { token: fresh.token }
  );

  const library = await api.get('/api/library/foods', { token: fresh.token });
  const names = library.body.map((f) => f.name).sort();
  assert.deepEqual(names, ['Batch item one', 'Batch item two']);
});

test('batch honours saveToLibrary false', async () => {
  const fresh = await signUp(api);
  await api.post(
    '/api/food/batch',
    {
      mealType: 'dinner',
      saveToLibrary: false,
      items: [{ name: 'One-off catering', calories: 900, protein: 30 }],
    },
    { token: fresh.token }
  );

  const library = await api.get('/api/library/foods', { token: fresh.token });
  assert.equal(library.body.length, 0);
});

// CSV exports and importing an Exerly JSON export. Synthetic data only.

const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { startServer, signUp } = require('./helpers/server');
const { cell } = require('../lib/portability');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

const key = () => ({ 'Idempotency-Key': randomUUID() });
const uuid = () => randomUUID().toUpperCase();

async function put(user, kind, payload) {
  const res = await api.put(
    `/v1/documents/${kind}/${payload.id}`,
    { base_revision: 0, payload },
    { token: user.token, headers: key() }
  );
  assert.equal(res.status, 201, `${kind}: ${JSON.stringify(res.body)}`);
}

/** One of everything the CSV files cover. */
async function seed(user) {
  const food = {
    foodID: 'off:3000000000013',
    name: 'Synthetic "olive", oil',
    source: 'openFoodFacts',
    per100g: { energy: 900, fat: 100 },
    volume: { density: 0.92, assumed: true, note: 'Typical for oils' },
  };
  await put(user, 'saved_food', {
    id: 'F1',
    name: '=SUM(A1:A2)',
    source: 'custom',
    per100g: { energy: 52, carbohydrate: 14 },
    servings: [{ name: '1 apple', grams: 180 }],
    favorite: true,
    createdAt: '2026-10-06T12:00:00.000Z',
  });
  await put(user, 'food_entry', {
    id: uuid(),
    date: '2026-10-06',
    meal: 'Dinner',
    loggedAt: '2026-10-06T23:30:00.000Z',
    grams: 13.8,
    serving: { name: '1 tbsp (15 ml)', grams: 13.8 },
    quantity: 1,
    food,
  });
  await put(user, 'weight_entry', {
    id: uuid(),
    at: '2026-10-06T11:00:00.000Z',
    date: '2026-10-06',
    weight: { value: 180.4, unit: 'lb' },
    source: 'manual',
  });
  await put(user, 'nutrition_day', {
    id: '2026-10-06',
    date: '2026-10-06',
    status: 'complete',
    notes: 'Line one\nline two',
    tags: ['travel'],
  });
  await put(user, 'workout_session', {
    id: uuid(),
    name: 'Push',
    notes: '',
    startedAt: '2026-10-06T18:00:00.000Z',
    endedAt: '2026-10-06T19:00:00.000Z',
    timeZoneID: 'America/New_York',
    bodyweight: { unit: 'kg', value: 80 },
    exercises: [
      {
        id: uuid(),
        exerciseID: 'barbell-bench-press',
        notes: '',
        sets: [
          {
            id: uuid(),
            kind: 'drop',
            efforts: [
              { reps: 6, load: { unit: 'kg', value: 100 } },
              { reps: 4, load: { unit: 'kg', value: 80 } },
            ],
            rir: 1,
            completedAt: '2026-10-06T18:10:00.000Z',
          },
        ],
      },
    ],
  });
  const metric = uuid();
  await put(user, 'custom_metric', {
    id: metric,
    name: 'Mood',
    unit: '',
    kind: 'scale',
    archived: false,
  });
  await put(user, 'metric_entry', { id: uuid(), metricID: metric, date: '2026-10-06', value: 4 });
}

const parse = (text) => text.trimEnd().split('\r\n');

/** The cells of one CSV line, unquoted. */
function cells(line) {
  const out = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quoted) {
      if (c === '"' && line[i + 1] === '"') {
        field += '"';
        i++;
      } else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') {
      out.push(field);
      field = '';
    } else field += c;
  }
  out.push(field);
  return out;
}

test('CSV files label units, leave unknowns empty, and are safe in a spreadsheet', async () => {
  const user = await signUp(api);
  await seed(user);
  const entries = await api.get('/v1/export/food_entries.csv', { token: user.token });
  assert.equal(entries.status, 200);
  assert.match(entries.headers.get('content-type'), /text\/csv/);
  const [header, row] = parse(entries.body);
  const columns = header.split(',');
  assert.ok(
    columns.includes('energy_kcal') &&
      columns.includes('sodium_mg') &&
      columns.includes('vitaminD_mcg')
  );
  assert.match(row, /"Synthetic ""olive"", oil"/);
  const values = cells(row);
  const energy = values[columns.indexOf('energy_kcal')];
  assert.equal(Number(energy), 124.2, '900 kcal per 100 g, 13.8 g');
  assert.equal(values[columns.indexOf('protein_g')], '', 'not reported, so empty, not zero');
  assert.equal(values[columns.indexOf('density_g_per_ml')], '0.92');

  const foods = await api.get('/v1/export/saved_foods.csv', { token: user.token });
  assert.match(foods.body, /'=SUM\(A1:A2\)/, 'a formula is neutralised');
  const sets = parse((await api.get('/v1/export/sets.csv', { token: user.token })).body);
  assert.equal(sets.length, 3, 'one row per effort of the drop set');
  const days = (await api.get('/v1/export/days.csv', { token: user.token })).body;
  assert.match(days, /"Line one\nline two"/);

  const missing = await api.get('/v1/export/everything.csv', { token: user.token });
  assert.equal(missing.status, 404);
  assert.match(missing.body.error ?? missing.body.message, /food_entries\.csv/);
  assert.equal(cell('-5 kg'), "'-5 kg");
  assert.equal(cell(-5), '-5');
});

test('an export imports into another account whole, and twice changes nothing', async () => {
  const from = await signUp(api);
  await seed(from);
  await api.post('/api/food', { name: 'Legacy oats', calories: 300 }, { token: from.token });
  const exported = (await api.get('/api/export', { token: from.token })).body;

  const to = await signUp(api);
  const first = await api.post('/v1/import', exported, { token: to.token });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(first.body.imported, 7);
  assert.deepEqual(first.body.skipped, []);
  assert.ok(first.body.ignored_tables.includes('food'), 'legacy tables are not imported');

  const documents = async (user) =>
    (await api.get('/v1/changes?after=0', { token: user.token })).body.changes
      .filter((c) => c.kind !== 'audit_event')
      .map((c) => ({ kind: c.kind, id: c.id, revision: c.revision, payload: c.payload }))
      .sort((a, b) => `${a.kind}/${a.id}`.localeCompare(`${b.kind}/${b.id}`));
  assert.deepEqual(await documents(to), await documents(from));

  const again = await api.post('/v1/import', exported, { token: to.token });
  assert.deepEqual([again.body.imported, again.body.kept], [0, 7]);

  assert.equal((await api.post('/v1/import', { hello: 1 }, { token: to.token })).status, 400);
  const minted = await api.post(
    '/v1/tokens',
    { name: 'Synthetic agent', scopes: ['read', 'write'] },
    { token: to.token, headers: key() }
  );
  assert.equal((await api.post('/v1/import', exported, { token: minted.body.token })).status, 403);
  assert.equal((await api.get('/v1/export/sets.csv', { token: minted.body.token })).status, 200);
});

const test = require('node:test');
const assert = require('node:assert');
const { startServer, signUp } = require('./helpers/server');
const dates = require('../lib/dates');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

// Kiritimati is UTC+14 and Niue is UTC-11. They are 25 hours apart, so their
// local calendar dates differ at every instant. That makes this deterministic
// rather than a test that only fails for a few hours a day.
test('a log with no date lands on the user local day, not the UTC day', async () => {
  const east = await signUp(api, { timezone: 'Pacific/Kiritimati' });
  const west = await signUp(api, { timezone: 'Pacific/Niue' });

  const eastLog = await api.post(
    '/api/food',
    { name: 'Rice', calories: 200, protein: 4 },
    { token: east.token }
  );
  const westLog = await api.post(
    '/api/food',
    { name: 'Rice', calories: 200, protein: 4 },
    { token: west.token }
  );

  assert.equal(eastLog.body.entry_date, dates.today('Pacific/Kiritimati'));
  assert.equal(westLog.body.entry_date, dates.today('Pacific/Niue'));
  assert.notEqual(
    eastLog.body.entry_date,
    westLog.body.entry_date,
    'two users 25 hours apart must never share a calendar day'
  );
});

test('a log can be backdated to any past day', async () => {
  const user = await signUp(api);
  const yesterday = dates.addDays(dates.today(user.timezone), -1);
  const lastMonth = dates.addDays(dates.today(user.timezone), -30);

  const a = await api.post(
    '/api/food',
    { name: 'Forgotten dinner', calories: 700, protein: 40, entry_date: yesterday },
    { token: user.token }
  );
  const b = await api.post(
    '/api/activities',
    { activity: 'Run', duration_min: 30, calories: 300, entry_date: lastMonth },
    { token: user.token }
  );

  assert.equal(a.status, 201);
  assert.equal(a.body.entry_date, yesterday);
  assert.equal(b.body.entry_date, lastMonth);
});

test('a log cannot be dated in the future', async () => {
  const user = await signUp(api);
  const tomorrow = dates.addDays(dates.today(user.timezone), 1);

  const res = await api.post(
    '/api/food',
    { name: 'Time travel', calories: 100, protein: 1, entry_date: tomorrow },
    { token: user.token }
  );
  assert.equal(res.status, 400);
  assert.match(res.body.message, /future/);
});

test('a malformed date is rejected rather than silently ignored', async () => {
  const user = await signUp(api);
  for (const bad of ['not-a-date', '2026-13-01', '2026-02-30', '26-01-01']) {
    const res = await api.post(
      '/api/food',
      { name: 'X', calories: 1, protein: 0, entry_date: bad },
      { token: user.token }
    );
    assert.equal(res.status, 400, `${bad} should be rejected`);
  }
});

test('list endpoints filter by date and by range', async () => {
  const user = await signUp(api);
  const today = dates.today(user.timezone);
  const days = [0, 1, 2, 5, 200].map((d) => dates.addDays(today, -d));

  for (const day of days) {
    await api.post(
      '/api/food',
      { name: `Meal ${day}`, calories: 500, protein: 30, entry_date: day },
      { token: user.token }
    );
  }

  const oneDay = await api.get(`/api/food?date=${days[1]}`, { token: user.token });
  assert.equal(oneDay.body.length, 1);
  assert.equal(oneDay.body[0].entry_date, days[1]);

  // The default window is 90 days, which must exclude the 200-day-old entry.
  const defaultWindow = await api.get('/api/food', { token: user.token });
  assert.equal(defaultWindow.body.length, 4);

  const explicit = await api.get(`/api/food?from=${days[4]}&to=${today}`, { token: user.token });
  assert.equal(explicit.body.length, 5);
});

test('a range beyond the cap is rejected instead of scanning everything', async () => {
  const user = await signUp(api);
  const res = await api.get('/api/food?from=2000-01-01&to=2026-01-01', { token: user.token });
  assert.equal(res.status, 400);
  assert.match(res.body.message, /exceed/);
});

test('servings multiply the macros that get stored', async () => {
  const user = await signUp(api);

  const single = await api.post(
    '/api/food',
    { name: 'Chicken', calories: 165, protein: 31, carbs: 0, fat: 3.6 },
    { token: user.token }
  );
  const double = await api.post(
    '/api/food',
    { name: 'Chicken', calories: 165, protein: 31, carbs: 0, fat: 3.6, servings: 2.5 },
    { token: user.token }
  );

  assert.equal(single.body.calories, 165);
  assert.equal(single.body.servings, 1, 'a client that sends no servings still works');
  assert.equal(double.body.calories, Math.round(165 * 2.5));
  assert.equal(double.body.protein, 77.5);
});

test('a food entry can be edited and moved to another day', async () => {
  const user = await signUp(api);
  const created = await api.post(
    '/api/food',
    { name: 'Oats', calories: 300, protein: 10 },
    { token: user.token }
  );
  const yesterday = dates.addDays(dates.today(user.timezone), -1);

  const updated = await api.put(
    `/api/food/${created.body.id}`,
    { name: 'Oats with milk', calories: 420, protein: 18, entry_date: yesterday },
    { token: user.token }
  );

  assert.equal(updated.status, 200);
  assert.equal(updated.body.calories, 420);
  assert.equal(updated.body.entry_date, yesterday);
});

test('one user cannot read or delete another user entries', async () => {
  const owner = await signUp(api);
  const intruder = await signUp(api);

  const created = await api.post(
    '/api/food',
    { name: 'Private', calories: 100, protein: 5 },
    { token: owner.token }
  );

  const read = await api.get('/api/food', { token: intruder.token });
  assert.equal(read.body.length, 0);

  const del = await api.del(`/api/food/${created.body.id}`, { token: intruder.token });
  assert.equal(del.status, 404);

  const stillThere = await api.get('/api/food', { token: owner.token });
  assert.equal(stillThere.body.length, 1);
});

test('an unparseable id returns 404 rather than a 500', async () => {
  const user = await signUp(api);
  const res = await api.del('/api/food/not-an-id', { token: user.token });
  assert.equal(res.status, 404);
});

test('batch logging writes every item to one day', async () => {
  const user = await signUp(api);
  const yesterday = dates.addDays(dates.today(user.timezone), -1);

  const res = await api.post(
    '/api/food/batch',
    {
      entry_date: yesterday,
      mealType: 'lunch',
      items: [
        { name: 'Rice', calories: 200, protein: 4 },
        { name: 'Beans', calories: 150, protein: 9 },
        { name: 'Avocado', calories: 240, protein: 3, servings: 0.5 },
      ],
    },
    { token: user.token }
  );

  assert.equal(res.status, 201);
  assert.equal(res.body.count, 3);
  assert.ok(res.body.created.every((e) => e.entry_date === yesterday));
  assert.equal(res.body.created[2].calories, 120);
});

test('water accepts millilitres and still answers in glasses', async () => {
  const user = await signUp(api);

  const set = await api.post('/api/water', { ml: 1000 }, { token: user.token });
  assert.equal(set.body.ml, 1000);
  assert.equal(set.body.glasses, 4);

  const legacy = await api.post('/api/water', { delta: 2 }, { token: user.token });
  assert.equal(legacy.body.ml, 1500);

  const floored = await api.post('/api/water', { deltaMl: -5000 }, { token: user.token });
  assert.equal(floored.body.ml, 0, 'water total must not go negative');

  const tooBig = await api.post('/api/water', { deltaMl: -9000 }, { token: user.token });
  assert.equal(tooBig.status, 400, 'an out-of-range delta is a bad request, not a clamp');
});

test('a goal of zero is stored as zero, not discarded', async () => {
  const user = await signUp(api);
  const res = await api.post(
    '/api/goals',
    { dailyCalories: 0, weeklyWorkouts: 3 },
    { token: user.token }
  );
  assert.equal(res.status, 200);
  assert.equal(res.body.goals.daily_calories, 0);
  assert.equal(res.body.goals.weekly_workouts, 3);
});

test('reset-today returns what it deleted so a client can undo', async () => {
  const user = await signUp(api);
  await api.post('/api/food', { name: 'A', calories: 100, protein: 1 }, { token: user.token });
  await api.post('/api/food', { name: 'B', calories: 200, protein: 2 }, { token: user.token });

  const res = await api.post('/api/reset-today', {}, { token: user.token });
  assert.equal(res.body.counts.food, 2);
  assert.equal(res.body.removed.food.length, 2);
  assert.equal(res.body.removed.food[0].name, 'A');

  const after = await api.get('/api/food', { token: user.token });
  assert.equal(after.body.length, 0);
});

test('meal types are accepted in any case and stored canonically', async () => {
  const user = await signUp(api);

  // The deployed iOS app and the older web food page both send "Snack".
  const capitalized = await api.post(
    '/api/food',
    { name: 'Late snack', calories: 200, protein: 8, mealType: 'Snack' },
    { token: user.token }
  );
  assert.equal(capitalized.status, 201);
  assert.equal(capitalized.body.meal_type, 'snack');

  const shouty = await api.post(
    '/api/food',
    { name: 'Breakfast', calories: 400, protein: 20, mealType: 'BREAKFAST' },
    { token: user.token }
  );
  assert.equal(shouty.body.meal_type, 'breakfast');

  // Still rejects something that is not a meal type at all.
  const nonsense = await api.post(
    '/api/food',
    { name: 'X', calories: 1, protein: 0, mealType: 'brunch' },
    { token: user.token }
  );
  assert.equal(nonsense.status, 400);

  // And the summary groups the normalized values, not the raw ones.
  const summary = await api.get('/api/summary', { token: user.token });
  assert.equal(summary.body.meals.snack.entries.length, 1);
  assert.equal(summary.body.meals.breakfast.entries.length, 1);
  assert.equal(summary.body.meals.uncategorized.entries.length, 0);
});

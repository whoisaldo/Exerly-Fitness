const test = require('node:test');
const assert = require('node:assert');
const { startServer, signUp } = require('./helpers/server');
const dates = require('../lib/dates');
const { KCAL_PER_KG } = require('../lib/nutrition');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

async function onboard(user, overrides = {}) {
  const res = await api.put(
    '/api/profile',
    {
      age: 28,
      gender: 'male',
      height: 180,
      weight: 85,
      activityLevel: 'moderate',
      ...overrides,
    },
    { token: user.token }
  );
  assert.equal(res.status, 200);
  return res.body;
}

// Logs `days` of food and weigh-ins through the public API, backdated. Weight
// follows the energy balance implied by `tdee` and `intake`, plus scale noise.
async function seedHistory(user, { days, startKg, tdee, intake, noiseKg = 1.0, seed = 3 }) {
  let s = seed;
  const noise = () => {
    s = (s * 1103515245 + 12345) % 2147483648;
    return (s / 2147483648 - 0.5) * noiseKg;
  };

  const today = dates.today(user.timezone);
  const dailyChangeKg = (intake - tdee) / KCAL_PER_KG;

  for (let i = 0; i < days; i++) {
    const date = dates.addDays(today, -(days - 1 - i));
    await api.post(
      '/api/weight',
      { weight: Number((startKg + dailyChangeKg * i + noise()).toFixed(2)), entry_date: date },
      { token: user.token }
    );
    const completed = await api.put(
      '/api/diary/day',
      { entry_date: date, status: 'complete', base_revision: 0 },
      { token: user.token }
    );
    assert.equal(completed.status, 200);
    await api.post(
      '/api/food',
      {
        name: 'Daily total',
        calories: intake,
        protein: 180,
        carbs: 200,
        fat: 70,
        entry_date: date,
        saveToLibrary: false,
      },
      { token: user.token }
    );
  }
}

// ---------- weight ----------

test('weight is stored per day and a second reading replaces the first', async () => {
  const user = await signUp(api);

  const first = await api.post('/api/weight', { weight: 85.4 }, { token: user.token });
  assert.equal(first.status, 201);
  assert.equal(first.body.weight_kg, 85.4);

  const second = await api.post('/api/weight', { weight: 85.9 }, { token: user.token });
  assert.equal(second.body.weight_kg, 85.9);

  const all = await api.get('/api/weight', { token: user.token });
  assert.equal(all.body.length, 1, 'one weigh-in per calendar day');
});

test('weight accepts pounds and stores kilograms', async () => {
  const user = await signUp(api);
  const res = await api.post('/api/weight', { weightLb: 187 }, { token: user.token });
  assert.ok(Math.abs(res.body.weight_kg - 84.82) < 0.02, `got ${res.body.weight_kg}`);
});

test('the trend endpoint smooths the scale and reports a weekly rate', async () => {
  const user = await signUp(api);
  await onboard(user);
  await seedHistory(user, { days: 30, startKg: 85, tdee: 2600, intake: 2100 });

  const res = await api.get('/api/weight/trend?days=30', { token: user.token });
  assert.equal(res.status, 200);
  assert.equal(res.body.series.length, 30);

  // A 500 kcal deficit is about -0.45 kg/week.
  const rate = res.body.summary.weekly_rate_kg;
  assert.ok(rate < -0.2 && rate > -0.8, `weekly rate looked wrong: ${rate}`);
  assert.equal(res.body.summary.weigh_ins, 30);
});

test('the trend fills gaps rather than dropping days', async () => {
  const user = await signUp(api);
  const today = dates.today(user.timezone);
  await api.post(
    '/api/weight',
    { weight: 80, entry_date: dates.addDays(today, -10) },
    { token: user.token }
  );
  await api.post('/api/weight', { weight: 79, entry_date: today }, { token: user.token });

  const res = await api.get('/api/weight/trend?days=14', { token: user.token });
  assert.equal(res.body.series.length, 11, 'series runs from the first weigh-in to today');
  assert.equal(res.body.series[5].weight, null);
  assert.ok(res.body.series[5].trend > 0, 'the trend is carried across the gap');
});

// ---------- program ----------

test('a new user gets a maintain program with no targets yet', async () => {
  const user = await signUp(api);
  const res = await api.get('/api/program', { token: user.token });

  assert.equal(res.status, 200);
  assert.equal(res.body.goal_type, 'maintain');
  assert.equal(res.body.rate_kg_per_week, 0);
  assert.equal(res.body.expenditure.confidence, 'estimated');
  assert.equal(res.body.needs_checkin, true);
});

test('setting a lose goal normalizes the rate sign and applies targets immediately', async () => {
  const user = await signUp(api);
  await onboard(user);

  // A positive rate with a "lose" goal is a contradiction; it gets flipped.
  const res = await api.put(
    '/api/program',
    { goalType: 'lose', rateKgPerWeek: 0.5, dietType: 'balanced', proteinStrategy: 'high' },
    { token: user.token }
  );

  assert.equal(res.status, 200);
  assert.equal(res.body.rate_kg_per_week, -0.5);
  assert.ok(res.body.targets.calories > 0);
  assert.ok(
    res.body.targets.calories < res.body.expenditure.value,
    'a cut must eat below expenditure'
  );
});

test('a rate beyond the safe cap is rejected', async () => {
  const user = await signUp(api);
  const res = await api.put(
    '/api/program',
    { goalType: 'lose', rateKgPerWeek: 5 },
    { token: user.token }
  );
  assert.equal(res.status, 400);
});

test('maintain forces the rate to zero', async () => {
  const user = await signUp(api);
  await onboard(user);
  const res = await api.put(
    '/api/program',
    { goalType: 'maintain', rateKgPerWeek: -0.75 },
    { token: user.token }
  );
  assert.equal(res.body.rate_kg_per_week, 0);
});

test('check-in with no history falls back to the formula estimate', async () => {
  const user = await signUp(api);
  await onboard(user);
  await api.post('/api/weight', { weight: 85 }, { token: user.token });

  const res = await api.post('/api/program/checkin', {}, { token: user.token });
  assert.equal(res.status, 200);
  assert.equal(res.body.program.expenditure.confidence, 'estimated');

  // Mifflin-St Jeor for 85kg/180cm/28y male is 1840, times the 1.55 moderate
  // multiplier is 2852.
  assert.equal(res.body.program.expenditure.value, 2852);
});

test('check-in after eight weeks of logs measures the real expenditure', async () => {
  const TRUE_TDEE = 2900;
  const user = await signUp(api);
  await onboard(user);
  await seedHistory(user, { days: 56, startKg: 88, tdee: TRUE_TDEE, intake: 2400 });

  await api.put(
    '/api/program',
    { goalType: 'lose', rateKgPerWeek: -0.5, proteinStrategy: 'high' },
    { token: user.token }
  );
  const res = await api.post('/api/program/checkin', {}, { token: user.token });

  assert.equal(res.status, 200);
  const measured = res.body.program.expenditure.value;

  // The profile formula says about 2900 too, but only because the activity
  // level happens to be right. What matters is that the measured value lands
  // near the truth rather than defaulting.
  assert.ok(Math.abs(measured - TRUE_TDEE) < 250, `expected ~${TRUE_TDEE}, measured ${measured}`);
  assert.equal(res.body.program.expenditure.confidence, 'high');
  assert.equal(res.body.program.expenditure.mean_intake, 2400);

  // Targets should sit a 0.5 kg/week deficit below the measured expenditure.
  const expectedCalories = measured - (0.5 * KCAL_PER_KG) / 7;
  assert.ok(
    Math.abs(res.body.program.targets.calories - expectedCalories) < 60,
    `targets ${res.body.program.targets.calories} vs expected ~${Math.round(expectedCalories)}`
  );
});

test('a check-in syncs the goals record so every screen shows the same numbers', async () => {
  const user = await signUp(api);
  await onboard(user);
  await api.post('/api/weight', { weight: 85 }, { token: user.token });
  await api.put('/api/program', { goalType: 'lose', rateKgPerWeek: -0.5 }, { token: user.token });

  const checkin = await api.post('/api/program/checkin', {}, { token: user.token });
  const goals = await api.get('/api/goals', { token: user.token });

  assert.equal(goals.body.daily_calories, checkin.body.program.targets.calories);
  assert.equal(goals.body.protein_g, checkin.body.program.targets.protein_g);
});

test('check-in history records what the numbers were at the time', async () => {
  const user = await signUp(api);
  await onboard(user);
  await api.post('/api/weight', { weight: 85 }, { token: user.token });
  await api.post('/api/program/checkin', { note: 'first week' }, { token: user.token });

  const res = await api.get('/api/program/checkins', { token: user.token });
  assert.equal(res.body.length, 1);
  assert.equal(res.body[0].note, 'first week');
  assert.ok(res.body[0].calories > 0);
});

test('needs_checkin turns off for a week after checking in', async () => {
  const user = await signUp(api);
  await onboard(user);
  await api.post('/api/weight', { weight: 85 }, { token: user.token });
  await api.post('/api/program/checkin', {}, { token: user.token });

  const res = await api.get('/api/program', { token: user.token });
  assert.equal(res.body.needs_checkin, false);
  assert.equal(res.body.last_checkin_date, dates.today(user.timezone));
});

// ---------- daily summary ----------

test('the summary groups a day by meal and reports what is left', async () => {
  const user = await signUp(api);
  await onboard(user);
  await api.post(
    '/api/goals',
    { dailyCalories: 2400, proteinG: 180, carbsG: 240, fatG: 70 },
    { token: user.token }
  );

  await api.post(
    '/api/food',
    { name: 'Eggs', calories: 300, protein: 24, mealType: 'breakfast' },
    { token: user.token }
  );
  await api.post(
    '/api/food',
    { name: 'Toast', calories: 200, protein: 8, mealType: 'breakfast' },
    { token: user.token }
  );
  await api.post(
    '/api/food',
    { name: 'Salad', calories: 450, protein: 35, mealType: 'lunch' },
    { token: user.token }
  );
  await api.post('/api/food', { name: 'Nuts', calories: 180, protein: 6 }, { token: user.token });
  await api.post(
    '/api/activities',
    { activity: 'Run', duration_min: 40, calories: 420 },
    { token: user.token }
  );

  const res = await api.get('/api/summary', { token: user.token });

  assert.equal(res.status, 200);
  assert.equal(res.body.consumed.calories, 1130);
  assert.equal(res.body.consumed.protein, 73);
  assert.equal(res.body.burned, 420);
  assert.equal(res.body.meals.breakfast.entries.length, 2);
  assert.equal(res.body.meals.breakfast.totals.calories, 500);
  assert.equal(res.body.meals.uncategorized.entries.length, 1);
  assert.equal(res.body.remaining.calories, 2400 - 1130);
  assert.equal(res.body.remaining.protein_g, 107);
});

test('the summary can be asked for any past day', async () => {
  const user = await signUp(api);
  const yesterday = dates.addDays(dates.today(user.timezone), -1);
  await api.post(
    '/api/food',
    { name: 'Yesterday lunch', calories: 600, protein: 30, entry_date: yesterday },
    { token: user.token }
  );

  const res = await api.get(`/api/summary?entry_date=${yesterday}`, { token: user.token });
  assert.equal(res.body.date, yesterday);
  assert.equal(res.body.consumed.calories, 600);
});

test('the range summary averages only the days that were logged', async () => {
  const user = await signUp(api);
  const today = dates.today(user.timezone);

  for (const offset of [0, 1, 2]) {
    await api.post(
      '/api/food',
      { name: 'Meal', calories: 2000, protein: 100, entry_date: dates.addDays(today, -offset) },
      { token: user.token }
    );
  }

  const res = await api.get('/api/summary/range?days=10', { token: user.token });
  assert.equal(res.body.series.length, 10);
  assert.equal(res.body.averages.days_logged, 3);
  assert.equal(res.body.averages.days_total, 10);
  assert.equal(res.body.averages.calories, 2000, 'unlogged days must not drag the average down');
});

// ---------- export and admin ----------

test('export returns the account data and never the password hash', async () => {
  const user = await signUp(api);
  await api.post('/api/food', { name: 'Thing', calories: 100, protein: 5 }, { token: user.token });
  await api.post('/api/weight', { weight: 80 }, { token: user.token });

  const res = await api.get('/api/export', { token: user.token });
  assert.equal(res.status, 200);
  assert.equal(res.body.food.length, 1);
  assert.equal(res.body.weights.length, 1);
  assert.ok(!JSON.stringify(res.body).includes('$2b$'), 'a bcrypt hash leaked into the export');
  assert.match(res.headers.get('content-disposition'), /attachment/);
});

test('an admin cannot remove their own admin access', async () => {
  const admin = await signUp(api, { email: 'admin@exerly.test' });
  assert.equal(admin.user.isAdmin, true);

  const res = await api.post(
    '/api/admin/toggle-admin',
    { email: 'admin@exerly.test', isAdmin: false },
    { token: admin.token }
  );
  assert.equal(res.status, 403);
  assert.match(res.body.message, /your own/);
});

test('admin routes are closed to normal users', async () => {
  const user = await signUp(api);
  assert.equal((await api.get('/api/admin/users', { token: user.token })).status, 403);
  assert.equal((await api.get('/api/admin/stats', { token: user.token })).status, 403);
});

test('the admin user list never includes password hashes', async () => {
  // The admin account already exists from the previous test, so sign in
  // rather than trying to create it twice.
  const login = await api.post('/login', {
    email: 'admin@exerly.test',
    password: 'correct-horse-battery',
  });
  const res = await api.get('/api/admin/users', { token: login.body.token });
  assert.equal(res.status, 200);
  assert.ok(res.body.length > 0);
  assert.ok(!JSON.stringify(res.body).includes('$2b$'));
});

const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer, signUp } = require('./helpers/server');
const dates = require('../lib/dates');
let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => {
  await api.close();
});

test('historical diary targets stay fixed when current goals change', async () => {
  const user = await signUp(api);
  const today = dates.today(user.timezone);
  const yesterday = dates.addDays(today, -1);
  await api.store.insert('target_versions', {
    account_id: user.user._id,
    email: user.email,
    effective_date: yesterday,
    targets: {
      calories: 2400,
      protein_g: 150,
      carbs_g: 300,
      fat_g: 65,
      fiber_g: 30,
      water_ml: 2500,
    },
    reason: 'fixture_accepted_checkin',
    created_at: new Date(Date.now() - 86400000),
  });
  const changed = await api.post(
    '/api/goals',
    { dailyCalories: 2100, proteinG: 145, carbsG: 250, fatG: 60 },
    { token: user.token }
  );
  assert.equal(changed.status, 200);
  const current = await api.get('/api/summary', { token: user.token });
  const old = await api.get(`/api/summary?entry_date=${yesterday}`, { token: user.token });
  assert.equal(current.body.targets.calories, 2100);
  assert.equal(old.body.targets.calories, 2400);
  assert.equal(old.body.target_source, 'accepted');
  const program = await api.get('/api/program', { token: user.token });
  assert.equal(program.body.targets.calories, 2100);
  assert.equal(program.body.target_mode, 'manual');
  assert.equal(program.body.suggested_targets.calories, 2100);
  const history = await api.get('/api/program/targets/history', { token: user.token });
  assert.equal(history.body.length, 2);
  const other = await signUp(api);
  assert.deepEqual(
    (await api.get('/api/program/targets/history', { token: other.token })).body,
    []
  );
});

test('dates without a recorded target do not inherit the current plan', async () => {
  const user = await signUp(api);
  await api.post('/api/goals', { dailyCalories: 2200 }, { token: user.token });
  const yesterday = dates.addDays(dates.today(user.timezone), -1);
  const old = await api.get(`/api/summary?entry_date=${yesterday}`, { token: user.token });
  assert.equal(old.body.targets.calories, null);
  assert.equal(old.body.target_source, 'not_recorded');
});

test('manual target check-in cannot silently replace user selected targets', async () => {
  const user = await signUp(api);
  await api.post(
    '/api/goals',
    { dailyCalories: 2200, proteinG: 140, carbsG: 260, fatG: 65 },
    { token: user.token }
  );
  const checkin = await api.post('/api/program/checkin', {}, { token: user.token });
  assert.equal(checkin.status, 200);
  assert.equal(checkin.body.program.targets.calories, 2200);
  assert.equal(checkin.body.change.calories, 0);
});
